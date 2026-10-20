import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class PlannerState extends ChangeNotifier {
  List<StudyTask> tasks = [];
  List<StudySubject> subjects = [];
  List<StudySession> sessions = [];
  bool isDark = false;
  bool remindersEnabled = true;
  bool sidebarExpanded = true;
  int dailyGoalMinutes = 120;
  int focusMinutes = 25;
  final Set<String> readReminderIds = {};
  bool isReady = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final taskData = prefs.getString('planner.tasks');
    final subjectData = prefs.getString('planner.subjects');
    final sessionData = prefs.getString('planner.sessions');
    if (taskData == null || subjectData == null || sessionData == null) {
      _loadDemoData();
    } else {
      tasks = (jsonDecode(taskData) as List)
          .map((item) => StudyTask.fromJson(item as Map<String, dynamic>))
          .toList();
      subjects = (jsonDecode(subjectData) as List)
          .map((item) => StudySubject.fromJson(item as Map<String, dynamic>))
          .toList();
      sessions = (jsonDecode(sessionData) as List)
          .map((item) => StudySession.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    isDark = prefs.getBool('planner.dark') ?? false;
    remindersEnabled = prefs.getBool('planner.reminders') ?? true;
    dailyGoalMinutes = prefs.getInt('planner.goal') ?? 120;
    focusMinutes = prefs.getInt('planner.focus') ?? 25;
    readReminderIds.addAll(prefs.getStringList('planner.readReminders') ?? []);
    isReady = true;
    notifyListeners();
  }

  void _loadDemoData() {
    final now = DateTime.now();
    DateTime at(int dayOffset, int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
    subjects = const [
      StudySubject(
        id: 'math',
        name: 'Mathematics',
        color: 0xff6c63ff,
        icon: 0xe3b7,
        targetHours: 5,
      ),
      StudySubject(
        id: 'physics',
        name: 'Physics',
        color: 0xff21a8a0,
        icon: 0xe3b8,
        targetHours: 4,
      ),
      StudySubject(
        id: 'biology',
        name: 'Biology',
        color: 0xffff9e5e,
        icon: 0xe5d5,
        targetHours: 3,
      ),
      StudySubject(
        id: 'history',
        name: 'History',
        color: 0xffe8799b,
        icon: 0xe80c,
        targetHours: 2,
      ),
    ];
    tasks = [
      StudyTask(
        id: 'task-1',
        title: 'Complete calculus problem set',
        description: 'Chapter 8 · exercises 1–12',
        subjectId: 'math',
        dueAt: at(0, 17),
        priority: TaskPriority.high,
      ),
      StudyTask(
        id: 'task-2',
        title: 'Review electromagnetic waves',
        description: 'Summarize lecture notes',
        subjectId: 'physics',
        dueAt: at(0, 20),
        priority: TaskPriority.medium,
      ),
      StudyTask(
        id: 'task-3',
        title: 'Read cell biology chapter',
        description: 'Chapter 6 · take notes',
        subjectId: 'biology',
        dueAt: at(1, 16),
        priority: TaskPriority.low,
      ),
      StudyTask(
        id: 'task-4',
        title: 'Prepare essay outline',
        description: 'Industrial revolution',
        subjectId: 'history',
        dueAt: at(2, 12),
        priority: TaskPriority.high,
      ),
      StudyTask(
        id: 'task-5',
        title: 'Practice integration techniques',
        description: 'Mixed practice set',
        subjectId: 'math',
        dueAt: at(3, 18),
        priority: TaskPriority.medium,
      ),
      StudyTask(
        id: 'task-6',
        title: 'Physics lab report',
        description: 'Draft results and discussion',
        subjectId: 'physics',
        dueAt: at(-1, 18),
        priority: TaskPriority.high,
        isDone: true,
      ),
    ];
    sessions = [
      StudySession(
        id: 'session-1',
        title: 'Deep work: calculus',
        subjectId: 'math',
        startsAt: at(0, 9),
        minutes: 50,
        isCompleted: true,
      ),
      StudySession(
        id: 'session-2',
        title: 'Physics lecture review',
        subjectId: 'physics',
        startsAt: at(0, 11),
        minutes: 45,
        isCompleted: true,
      ),
      StudySession(
        id: 'session-3',
        title: 'Biology flashcards',
        subjectId: 'biology',
        startsAt: at(0, 14),
        minutes: 30,
      ),
      StudySession(
        id: 'session-4',
        title: 'Evening study block',
        subjectId: 'math',
        startsAt: at(1, 10),
        minutes: 60,
      ),
      StudySession(
        id: 'session-5',
        title: 'History reading',
        subjectId: 'history',
        startsAt: at(2, 15),
        minutes: 45,
      ),
    ];
  }

  List<StudyTask> get sortedTasks {
    final result = [...tasks];
    result.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final byDate = a.dueAt.compareTo(b.dueAt);
      if (byDate != 0) return byDate;
      return b.priority.index.compareTo(a.priority.index);
    });
    return result;
  }

  StudySubject? subjectById(String id) {
    for (final subject in subjects) {
      if (subject.id == id) return subject;
    }
    return null;
  }

  int get completedCount => tasks.where((task) => task.isDone).length;
  int get pendingCount => tasks.where((task) => !task.isDone).length;
  int get dueTodayCount => tasks
      .where((task) => !task.isDone && sameDay(task.dueAt, DateTime.now()))
      .length;
  int get overdueCount => tasks
      .where((task) => !task.isDone && task.dueAt.isBefore(DateTime.now()))
      .length;

  int studiedMinutesOn(DateTime date) => sessions
      .where(
        (session) => session.isCompleted && sameDay(session.startsAt, date),
      )
      .fold(0, (sum, session) => sum + session.minutes);

  List<StudySession> get upcomingSessions {
    final upcoming = sessions.where((session) => !session.isCompleted).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return upcoming;
  }

  List<StudyTask> get todayTasks => sortedTasks
      .where((task) => !task.isDone && sameDay(task.dueAt, DateTime.now()))
      .toList();

  List<StudyTask> get reminders {
    final now = DateTime.now();
    return tasks.where((task) {
      return !task.isDone &&
          task.dueAt.isBefore(now.add(const Duration(hours: 24)));
    }).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  int get unreadReminderCount => remindersEnabled
      ? reminders.where((task) => !readReminderIds.contains(task.id)).length
      : 0;

  bool hasSessionConflict(DateTime start, int minutes, {String? excludingId}) {
    final end = start.add(Duration(minutes: minutes));
    return sessions.any(
      (session) =>
          session.id != excludingId &&
          start.isBefore(session.endsAt) &&
          end.isAfter(session.startsAt),
    );
  }

  void saveTask(StudyTask task) {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) {
      tasks.add(task);
    } else {
      tasks[index] = task;
    }
    _changed();
  }

  void toggleTask(String id) {
    final index = tasks.indexWhere((task) => task.id == id);
    if (index >= 0) {
      tasks[index] = tasks[index].copyWith(isDone: !tasks[index].isDone);
      _changed();
    }
  }

  void deleteTask(String id) {
    tasks.removeWhere((task) => task.id == id);
    readReminderIds.remove(id);
    _changed();
  }

  void saveSubject(StudySubject subject) {
    subjects = [...subjects, subject];
    _changed();
  }

  bool deleteSubject(String id) {
    if (tasks.any((task) => task.subjectId == id) ||
        sessions.any((session) => session.subjectId == id)) {
      return false;
    }
    subjects.removeWhere((subject) => subject.id == id);
    _changed();
    return true;
  }

  void saveSession(StudySession session) {
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index < 0) {
      sessions.add(session);
    } else {
      sessions[index] = session;
    }
    _changed();
  }

  void completeSession(String title, String subjectId, int minutes) {
    sessions.add(
      StudySession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        subjectId: subjectId,
        startsAt: DateTime.now().subtract(Duration(minutes: minutes)),
        minutes: minutes,
        isCompleted: true,
      ),
    );
    _changed();
  }

  void deleteSession(String id) {
    sessions.removeWhere((session) => session.id == id);
    _changed();
  }

  void markRemindersRead() {
    readReminderIds.addAll(reminders.map((task) => task.id));
    _changed();
  }

  void setDark(bool value) {
    isDark = value;
    _changed();
  }

  void setRemindersEnabled(bool value) {
    remindersEnabled = value;
    _changed();
  }

  void setGoal(int minutes) {
    dailyGoalMinutes = minutes;
    _changed();
  }

  void setFocusMinutes(int minutes) {
    focusMinutes = minutes;
    _changed();
  }

  void setSidebarExpanded(bool value) {
    sidebarExpanded = value;
    notifyListeners();
  }

  void _changed() {
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'planner.tasks',
      encodeList(tasks, (item) => item.toJson()),
    );
    await prefs.setString(
      'planner.subjects',
      encodeList(subjects, (item) => item.toJson()),
    );
    await prefs.setString(
      'planner.sessions',
      encodeList(sessions, (item) => item.toJson()),
    );
    await prefs.setBool('planner.dark', isDark);
    await prefs.setBool('planner.reminders', remindersEnabled);
    await prefs.setInt('planner.goal', dailyGoalMinutes);
    await prefs.setInt('planner.focus', focusMinutes);
    await prefs.setStringList(
      'planner.readReminders',
      readReminderIds.toList(),
    );
  }
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
