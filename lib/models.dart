import 'dart:convert';

enum TaskPriority { low, medium, high }

class StudyTask {
  StudyTask({
    required this.id,
    required this.title,
    this.description = '',
    required this.subjectId,
    required this.dueAt,
    this.priority = TaskPriority.medium,
    this.isDone = false,
  });

  final String id;
  final String title;
  final String description;
  final String subjectId;
  final DateTime dueAt;
  final TaskPriority priority;
  final bool isDone;

  StudyTask copyWith({
    String? title,
    String? description,
    String? subjectId,
    DateTime? dueAt,
    TaskPriority? priority,
    bool? isDone,
  }) => StudyTask(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    subjectId: subjectId ?? this.subjectId,
    dueAt: dueAt ?? this.dueAt,
    priority: priority ?? this.priority,
    isDone: isDone ?? this.isDone,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'subjectId': subjectId,
    'dueAt': dueAt.toIso8601String(),
    'priority': priority.name,
    'isDone': isDone,
  };

  factory StudyTask.fromJson(Map<String, dynamic> json) => StudyTask(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    subjectId: json['subjectId'] as String,
    dueAt: DateTime.parse(json['dueAt'] as String),
    priority: TaskPriority.values.firstWhere(
      (value) => value.name == json['priority'],
      orElse: () => TaskPriority.medium,
    ),
    isDone: json['isDone'] as bool? ?? false,
  );
}

class StudySubject {
  const StudySubject({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.targetHours = 4,
  });

  final String id;
  final String name;
  final int color;
  final int icon;
  final double targetHours;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'icon': icon,
    'targetHours': targetHours,
  };

  factory StudySubject.fromJson(Map<String, dynamic> json) => StudySubject(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as int,
    icon: json['icon'] as int,
    targetHours: (json['targetHours'] as num?)?.toDouble() ?? 4,
  );
}

class StudySession {
  const StudySession({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.startsAt,
    required this.minutes,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String subjectId;
  final DateTime startsAt;
  final int minutes;
  final bool isCompleted;

  DateTime get endsAt => startsAt.add(Duration(minutes: minutes));

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'subjectId': subjectId,
    'startsAt': startsAt.toIso8601String(),
    'minutes': minutes,
    'isCompleted': isCompleted,
  };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
    id: json['id'] as String,
    title: json['title'] as String,
    subjectId: json['subjectId'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String),
    minutes: json['minutes'] as int,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}

String encodeList<T>(List<T> items, Map<String, Object?> Function(T) mapper) =>
    jsonEncode(items.map(mapper).toList());
