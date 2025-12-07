class Person {
  final int? id;
  final String name;

  /// 'person', 'place', or 'activity'
  final String type;

  /// Only for type == 'person'
  final String? relation; // Mother, Father, Friend, etc.

  Person({
    this.id,
    required this.name,
    required this.type,
    this.relation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'relation': relation,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      relation: map['relation'] as String?,
    );
  }
}

class TimeEntry {
  final int? id;
  final int personId;
  final int startTimeMillis;
  final int? endTimeMillis;

  TimeEntry({
    this.id,
    required this.personId,
    required this.startTimeMillis,
    this.endTimeMillis,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'startTimeMillis': startTimeMillis,
      'endTimeMillis': endTimeMillis,
    };
  }

  factory TimeEntry.fromMap(Map<String, dynamic> map) {
    return TimeEntry(
      id: map['id'] as int?,
      personId: map['personId'] as int,
      startTimeMillis: map['startTimeMillis'] as int,
      endTimeMillis: map['endTimeMillis'] as int?,
    );
  }
}

class DailyRemark {
  final int? id;
  final int personId;
  final String dateKey; // yyyy-MM-dd
  final bool isWorthwhile;
  final String? note;

  DailyRemark({
    this.id,
    required this.personId,
    required this.dateKey,
    required this.isWorthwhile,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'dateKey': dateKey,
      'isWorthwhile': isWorthwhile ? 1 : 0,
      'note': note,
    };
  }

  factory DailyRemark.fromMap(Map<String, dynamic> map) {
    return DailyRemark(
      id: map['id'] as int?,
      personId: map['personId'] as int,
      dateKey: map['dateKey'] as String,
      isWorthwhile: (map['isWorthwhile'] as int) == 1,
      note: map['note'] as String?,
    );
  }
}

class PersonDuration {
  final int personId;
  final String personName;
  final int totalDurationMillis;

  PersonDuration({
    required this.personId,
    required this.personName,
    required this.totalDurationMillis,
  });
}
