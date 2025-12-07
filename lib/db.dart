import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class TimeTrackerDb {
  TimeTrackerDb._privateConstructor();
  static final TimeTrackerDb instance = TimeTrackerDb._privateConstructor();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    // New DB name so we can change schema safely
    final path = join(dbPath, 'time_tracker_v2.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE persons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,   -- 'person', 'place', 'activity'
            relation TEXT          -- only for type = 'person'
          )
        ''');

        await db.execute('''
          CREATE TABLE time_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            personId INTEGER NOT NULL,
            startTimeMillis INTEGER NOT NULL,
            endTimeMillis INTEGER,
            FOREIGN KEY(personId) REFERENCES persons(id)
          )
        ''');

        await db.execute('''
          CREATE TABLE daily_remarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            personId INTEGER NOT NULL,
            dateKey TEXT NOT NULL,
            isWorthwhile INTEGER NOT NULL,
            note TEXT,
            UNIQUE(personId, dateKey) ON CONFLICT REPLACE
          )
        ''');
      },
    );
  }

  Database get db {
    if (_db == null) {
      throw Exception('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  // PERSONS
  Future<int> insertPerson(String name, String type, String? relation) async {
    final person = Person(name: name.trim(), type: type, relation: relation);
    return await db.insert('persons', person.toMap());
  }

  Future<List<Person>> getAllPersons() async {
    final result = await db.query('persons', orderBy: 'name');
    return result.map((e) => Person.fromMap(e)).toList();
  }

  Future<List<Person>> searchPersons(String query) async {
    final result = await db.query(
      'persons',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name',
    );
    return result.map((e) => Person.fromMap(e)).toList();
  }

  Future<void> deletePerson(int personId) async {
    await db.delete(
      'time_entries',
      where: 'personId = ?',
      whereArgs: [personId],
    );
    await db.delete(
      'daily_remarks',
      where: 'personId = ?',
      whereArgs: [personId],
    );
    await db.delete(
      'persons',
      where: 'id = ?',
      whereArgs: [personId],
    );
  }

  // TIME ENTRIES
  Future<TimeEntry?> getActiveEntryForPerson(int personId) async {
    final result = await db.query(
      'time_entries',
      where: 'personId = ? AND endTimeMillis IS NULL',
      whereArgs: [personId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return TimeEntry.fromMap(result.first);
  }

  Future<void> startTracking(int personId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = TimeEntry(
      personId: personId,
      startTimeMillis: now,
    );
    await db.insert('time_entries', entry.toMap());
  }

  Future<void> stopTracking(int personId) async {
    final active = await getActiveEntryForPerson(personId);
    if (active == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'time_entries',
      {'endTimeMillis': now},
      where: 'id = ?',
      whereArgs: [active.id],
    );
  }

  Future<List<PersonDuration>> getDurationsInRange(
      DateTime start, DateTime end) async {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT e.personId, e.startTimeMillis, e.endTimeMillis, p.name AS personName
      FROM time_entries e
      JOIN persons p ON p.id = e.personId
      WHERE e.startTimeMillis BETWEEN ? AND ?
        AND e.endTimeMillis IS NOT NULL
    ''', [startMs, endMs]);

    final Map<int, PersonDuration> statsMap = {};

    for (final row in result) {
      final personId = row['personId'] as int;
      final name = row['personName'] as String;
      final startMsRow = row['startTimeMillis'] as int;
      final endMsRow = row['endTimeMillis'] as int;

      final diff = endMsRow - startMsRow;
      final existing = statsMap[personId];

      if (existing == null) {
        statsMap[personId] = PersonDuration(
          personId: personId,
          personName: name,
          totalDurationMillis: diff,
        );
      } else {
        statsMap[personId] = PersonDuration(
          personId: personId,
          personName: name,
          totalDurationMillis: existing.totalDurationMillis + diff,
        );
      }
    }

    final statsList = statsMap.values.toList();
    statsList.sort(
        (a, b) => b.totalDurationMillis.compareTo(a.totalDurationMillis));
    return statsList;
  }

  // DAILY REMARKS
  Future<void> upsertDailyRemark(
      int personId, String dateKey, bool isWorthwhile, String? note) async {
    final remark = DailyRemark(
      personId: personId,
      dateKey: dateKey,
      isWorthwhile: isWorthwhile,
      note: note,
    );
    await db.insert('daily_remarks', remark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DailyRemark?> getDailyRemark(int personId, String dateKey) async {
    final result = await db.query(
      'daily_remarks',
      where: 'personId = ? AND dateKey = ?',
      whereArgs: [personId, dateKey],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return DailyRemark.fromMap(result.first);
  }

  Future<List<Person>> getPersons() async {
    return getAllPersons();
  }
}
