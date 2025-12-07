import 'dart:collection';

import 'package:flutter/material.dart';

import 'db.dart';
import 'models.dart';

enum StatsRange { week, month, year }

class TimeTrackerModel extends ChangeNotifier {
  final _db = TimeTrackerDb.instance;

  List<Person> _persons = [];
  String _searchQuery = '';
  final Set<int> _activePersonIds = {};
  final Map<int, bool> _todayRemarks = {};
  List<PersonDuration> _stats = [];
  StatsRange _currentRange = StatsRange.week;

  bool _initialized = false;

  UnmodifiableListView<Person> get persons =>
      UnmodifiableListView(_persons);

  String get searchQuery => _searchQuery;
  UnmodifiableSetView<int> get activePersonIds =>
      UnmodifiableSetView(_activePersonIds);
  UnmodifiableMapView<int, bool> get todayRemarks =>
      UnmodifiableMapView(_todayRemarks);
  UnmodifiableListView<PersonDuration> get stats =>
      UnmodifiableListView(_stats);
  StatsRange get currentRange => _currentRange;
  bool get initialized => _initialized;

  Future<void> init() async {
    await _db.init();
    await _loadPersons();
    await _refreshActiveStatuses();
    await _refreshTodayRemarks();
    await _refreshStats();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadPersons() async {
    if (_searchQuery.trim().isEmpty) {
      _persons = await _db.getAllPersons();
    } else {
      _persons = await _db.searchPersons(_searchQuery.trim());
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _loadPersons().then((_) {
      _refreshActiveStatuses();
      _refreshTodayRemarks();
    });
  }

  Future<void> addPerson(
      String name, String type, String? relation) async {
    if (name.trim().isEmpty) return;
    await _db.insertPerson(name, type, relation);
    await _loadPersons();
    await _refreshActiveStatuses();
    await _refreshTodayRemarks();
    await _refreshStats();
  }

  Future<void> deletePerson(Person person) async {
    if (person.id == null) return;
    await _db.deletePerson(person.id!);
    await _loadPersons();
    await _refreshActiveStatuses();
    await _refreshTodayRemarks();
    await _refreshStats();
  }

  Future<void> toggleTracking(Person person) async {
    if (person.id == null) return;

    final isActive = _activePersonIds.contains(person.id);
    if (isActive) {
      await _db.stopTracking(person.id!);
    } else {
      await _db.startTracking(person.id!);
    }
    await _refreshActiveStatuses();
    await _refreshStats();
  }

  Future<void> _refreshActiveStatuses() async {
    _activePersonIds.clear();
    for (final p in _persons) {
      if (p.id == null) continue;
      final active = await _db.getActiveEntryForPerson(p.id!);
      if (active != null) {
        _activePersonIds.add(p.id!);
      }
    }
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _refreshTodayRemarks() async {
    _todayRemarks.clear();
    final today = _todayKey();
    for (final p in _persons) {
      if (p.id == null) continue;
      final remark = await _db.getDailyRemark(p.id!, today);
      if (remark != null) {
        _todayRemarks[p.id!] = remark.isWorthwhile;
      }
    }
    notifyListeners();
  }

  Future<void> setTodayRemark(Person person, bool isWorthwhile) async {
    if (person.id == null) return;
    final today = _todayKey();
    await _db.upsertDailyRemark(person.id!, today, isWorthwhile, null);
    await _refreshTodayRemarks();
  }

  Future<void> _refreshStats() async {
    final now = DateTime.now();
    late DateTime start;

    switch (_currentRange) {
      case StatsRange.week:
        start = now.subtract(const Duration(days: 7));
        break;
      case StatsRange.month:
        start = now.subtract(const Duration(days: 30));
        break;
      case StatsRange.year:
        start = now.subtract(const Duration(days: 365));
        break;
    }

    _stats = await _db.getDurationsInRange(start, now);
    notifyListeners();
  }

  void setStatsRange(StatsRange range) {
    _currentRange = range;
    _refreshStats();
  }
}
