import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'models.dart';

const _indigo = Color(0xff635bdb);
const _ink = Color(0xff20223a);
const _muted = Color(0xff85889d);
const _pageNames = [
  'Dashboard',
  'My Tasks',
  'Study Planner',
  'Calendar',
  'Subjects',
  'Study Timer',
  'Analytics',
  'Notifications',
  'Settings',
];
const _pageIcons = [
  Icons.space_dashboard_rounded,
  Icons.checklist_rounded,
  Icons.event_note_rounded,
  Icons.calendar_month_rounded,
  Icons.auto_stories_rounded,
  Icons.timer_rounded,
  Icons.insights_rounded,
  Icons.notifications_none_rounded,
  Icons.settings_rounded,
];

void main() => runApp(const StudyFlowApp());

class StudyFlowApp extends StatefulWidget {
  const StudyFlowApp({super.key});

  @override
  State<StudyFlowApp> createState() => _StudyFlowAppState();
}

class _StudyFlowAppState extends State<StudyFlowApp> {
  final PlannerState planner = PlannerState();

  @override
  void initState() {
    super.initState();
    planner.load();
  }

  @override
  void dispose() {
    planner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: planner,
    builder: (context, _) {
      final dark = planner.isDark;
      final scheme = ColorScheme.fromSeed(
        seedColor: _indigo,
        brightness: dark ? Brightness.dark : Brightness.light,
        surface: dark ? const Color(0xff1c1d2b) : Colors.white,
      );
      return MaterialApp(
        title: 'StudyFlow — your study, in rhythm',
        debugShowCheckedModeBanner: false,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: _makeTheme(scheme, false),
        darkTheme: _makeTheme(scheme, true),
        home: planner.isReady
            ? PlannerHome(state: planner)
            : const _LoadingScreen(),
      );
    },
  );

  ThemeData _makeTheme(ColorScheme colors, bool dark) => ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: dark
        ? const Color(0xff151622)
        : const Color(0xfff6f7fb),
    fontFamily: 'Roboto',
    textTheme: ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
    ).textTheme.apply(bodyColor: dark ? const Color(0xfff2f1fb) : _ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff252638) : const Color(0xfff7f8fc),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark ? Colors.white12 : const Color(0xffeceef5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _indigo, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xff1c1d2b) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark ? Colors.white10 : const Color(0xffeff0f5),
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: _indigo)),
  );
}

class PlannerHome extends StatefulWidget {
  const PlannerHome({super.key, required this.state});
  final PlannerState state;

  @override
  State<PlannerHome> createState() => _PlannerHomeState();
}

class _PlannerHomeState extends State<PlannerHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _page = 0;
  String _taskSearch = '';
  TaskPriority? _priorityFilter;
  bool _showCompleted = false;
  DateTime _calendarDate = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  PlannerState get state => widget.state;

  Future<void> _createTask({StudyTask? existing, DateTime? initialDate}) async {
    if (state.subjects.isEmpty) {
      _showMessage('Add a subject before creating a task.');
      setState(() => _page = 4);
      return;
    }
    final task = await showDialog<StudyTask>(
      context: context,
      builder: (_) => TaskEditorDialog(
        subjects: state.subjects,
        existing: existing,
        initialDate: initialDate,
      ),
    );
    if (task != null) state.saveTask(task);
  }

  Future<void> _createSession({DateTime? initialDate}) async {
    if (state.subjects.isEmpty) {
      _showMessage('Add a subject before scheduling a study session.');
      setState(() => _page = 4);
      return;
    }
    final session = await showDialog<StudySession>(
      context: context,
      builder: (_) => SessionEditorDialog(
        planner: state,
        subjects: state.subjects,
        initialDate: initialDate,
      ),
    );
    if (session != null) state.saveSession(session);
  }

  Future<void> _deleteTask(StudyTask task) async {
    final confirmed = await _confirm(
      'Delete task?',
      '“${task.title}” will be removed from your planner.',
    );
    if (confirmed) state.deleteTask(task.id);
  }

  Future<void> _deleteSession(StudySession session) async {
    final confirmed = await _confirm(
      'Remove study session?',
      '“${session.title}” will be removed from your schedule.',
    );
    if (confirmed) state.deleteSession(session.id);
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 920;
      final mobile = constraints.maxWidth < 620;
      final sidebar = compact ? 0.0 : (state.sidebarExpanded ? 252.0 : 82.0);
      final content = Column(
        children: [
          _TopBar(
            title: _pageNames[_page],
            mobile: mobile,
            compact: compact,
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onAddTask: () => _createTask(),
            notificationCount: state.unreadReminderCount,
            onNotifications: () => setState(() => _page = 7),
            dark: state.isDark,
            onTheme: () => state.setDark(!state.isDark),
            onSearch: (query) => setState(() {
              _taskSearch = query;
              _page = 1;
            }),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              child: KeyedSubtree(
                key: ValueKey(_page),
                child: _pageContent(mobile),
              ),
            ),
          ),
        ],
      );
      return Scaffold(
        key: _scaffoldKey,
        drawer: compact
            ? Drawer(
                child: _Sidebar(
                  selected: _page,
                  expanded: true,
                  reminderCount: state.unreadReminderCount,
                  onSelect: (index) => setState(() => _page = index),
                  onToggle: () {},
                ),
              )
            : null,
        body: Row(
          children: [
            if (!compact)
              SizedBox(
                width: sidebar,
                child: _Sidebar(
                  selected: _page,
                  expanded: state.sidebarExpanded,
                  reminderCount: state.unreadReminderCount,
                  onSelect: (index) => setState(() => _page = index),
                  onToggle: () =>
                      state.setSidebarExpanded(!state.sidebarExpanded),
                ),
              ),
            Expanded(child: SafeArea(child: content)),
          ],
        ),
        floatingActionButton: mobile && _page != 0
            ? FloatingActionButton.extended(
                onPressed: () => _page == 2 || _page == 3
                    ? _createSession(initialDate: _selectedDay)
                    : _createTask(initialDate: _selectedDay),
                icon: const Icon(Icons.add_rounded),
                label: Text(_page == 2 ? 'Study session' : 'New task'),
              )
            : null,
      );
    },
  );

  Widget _pageContent(bool mobile) {
    switch (_page) {
      case 0:
        return _DashboardPage(
          state: state,
          mobile: mobile,
          onNewTask: () => _createTask(),
          onTimer: () => setState(() => _page = 5),
          onToggle: state.toggleTask,
          onEdit: (task) => _createTask(existing: task),
          onSeeTasks: () => setState(() => _page = 1),
        );
      case 1:
        return _TasksPage(
          state: state,
          query: _taskSearch,
          onQuery: (value) => setState(() => _taskSearch = value),
          priority: _priorityFilter,
          onPriority: (value) => setState(() => _priorityFilter = value),
          showCompleted: _showCompleted,
          onShowCompleted: (value) => setState(() => _showCompleted = value),
          onNew: () => _createTask(),
          onEdit: (task) => _createTask(existing: task),
          onDelete: _deleteTask,
        );
      case 2:
        return _PlannerPage(
          state: state,
          onNew: () => _createSession(initialDate: _selectedDay),
          onDelete: _deleteSession,
        );
      case 3:
        return _CalendarPage(
          state: state,
          month: _calendarDate,
          selectedDay: _selectedDay,
          onMonth: (value) => setState(() => _calendarDate = value),
          onSelect: (value) => setState(() => _selectedDay = value),
          onNewTask: () => _createTask(initialDate: _selectedDay),
          onNewSession: () => _createSession(initialDate: _selectedDay),
          onToggle: state.toggleTask,
          onEdit: (task) => _createTask(existing: task),
          onDeleteSession: _deleteSession,
        );
      case 4:
        return _SubjectsPage(state: state, confirm: _confirm);
      case 5:
        return _TimerPage(state: state);
      case 6:
        return _AnalyticsPage(state: state);
      case 7:
        return _NotificationsPage(
          state: state,
          onTasks: () => setState(() => _page = 1),
        );
      default:
        return _SettingsPage(state: state);
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.expanded,
    required this.reminderCount,
    required this.onSelect,
    required this.onToggle,
  });

  final int selected;
  final bool expanded;
  final int reminderCount;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xff1c1d2b) : Colors.white,
        border: Border(
          right: BorderSide(
            color: dark ? Colors.white10 : const Color(0xffeceef5),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(expanded ? 22 : 14, 26, 14, 26),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: _indigo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'studyflow',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.6,
                            color: dark ? Colors.white : _ink,
                          ),
                        ),
                        const Text(
                          'STUDY IN RHYTHM',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.1,
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (expanded)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WORKSPACE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: _muted,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 10),
              itemCount: _pageNames.length,
              itemBuilder: (context, index) {
                final active = selected == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Tooltip(
                    message: expanded ? '' : _pageNames[index],
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () {
                        onSelect(index);
                        if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 46,
                        padding: EdgeInsets.symmetric(
                          horizontal: expanded ? 13 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? _indigo.withValues(alpha: .1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          mainAxisAlignment: expanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Icon(
                              _pageIcons[index],
                              size: 20,
                              color: active ? _indigo : _muted,
                            ),
                            if (expanded) ...[
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  _pageNames[index],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: active
                                        ? _indigo
                                        : (dark
                                              ? Colors.white70
                                              : const Color(0xff63667d)),
                                  ),
                                ),
                              ),
                              if (index == 7 && reminderCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _indigo,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$reminderCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xff292a40)
                      : const Color(0xfff4f2ff),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xffe7e3ff),
                      child: Icon(
                        Icons.school_rounded,
                        color: _indigo,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your learning space',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: dark ? Colors.white : _ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Collapse sidebar',
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggle,
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Expand sidebar',
              onPressed: onToggle,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.mobile,
    required this.compact,
    required this.onMenu,
    required this.onAddTask,
    required this.notificationCount,
    required this.onNotifications,
    required this.dark,
    required this.onTheme,
    required this.onSearch,
  });

  final String title;
  final bool mobile;
  final bool compact;
  final VoidCallback onMenu;
  final VoidCallback onAddTask;
  final int notificationCount;
  final VoidCallback onNotifications;
  final bool dark;
  final VoidCallback onTheme;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: EdgeInsets.symmetric(
      horizontal: mobile ? 14 : (compact ? 20 : 30),
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      border: Border(
        bottom: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: .12),
        ),
      ),
    ),
    child: Row(
      children: [
        if (compact)
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Open navigation',
          ),
        Text(
          title,
          style: TextStyle(
            fontSize: mobile ? 19 : 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const Spacer(),
        if (!mobile)
          SizedBox(
            width: compact ? 170 : 220,
            height: 40,
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search tasks…',
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: onTheme,
          tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
          icon: Icon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20,
          ),
        ),
        IconButton(
          onPressed: onNotifications,
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: notificationCount > 0,
            label: Text('$notificationCount'),
            child: const Icon(Icons.notifications_none_rounded, size: 21),
          ),
        ),
        if (!mobile) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAddTask,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New task'),
            style: FilledButton.styleFrom(
              backgroundColor: _indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    ),
  );
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: MediaQuery.sizeOf(context).width < 620
        ? const EdgeInsets.fromLTRB(16, 18, 16, 32)
        : const EdgeInsets.fromLTRB(30, 24, 30, 40),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.state,
    required this.mobile,
    required this.onNewTask,
    required this.onTimer,
    required this.onToggle,
    required this.onEdit,
    required this.onSeeTasks,
  });
  final PlannerState state;
  final bool mobile;
  final VoidCallback onNewTask;
  final VoidCallback onTimer;
  final ValueChanged<String> onToggle;
  final ValueChanged<StudyTask> onEdit;
  final VoidCallback onSeeTasks;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstName = 'Alex';
    final stats = [
      _StatData(
        'Tasks completed',
        '${state.completedCount}',
        'of ${state.tasks.length} total',
        Icons.task_alt_rounded,
        const Color(0xff635bdb),
        const Color(0xfff0efff),
      ),
      _StatData(
        'Study time today',
        _durationLabel(state.studiedMinutesOn(today)),
        'of ${_durationLabel(state.dailyGoalMinutes)} goal',
        Icons.schedule_rounded,
        const Color(0xff13a89e),
        const Color(0xffe6f8f5),
      ),
      _StatData(
        'Due today',
        '${state.dueTodayCount}',
        state.dueTodayCount == 0 ? 'You’re all caught up' : 'Keep the momentum',
        Icons.flag_rounded,
        const Color(0xfff4a34f),
        const Color(0xfffff5e9),
      ),
      _StatData(
        'Focus streak',
        '${_streakDays(state)} days',
        'You’re building a habit',
        Icons.local_fire_department_rounded,
        const Color(0xffed6e88),
        const Color(0xffffeef2),
      ),
    ];
    return _PageScroll(
      children: [
        Text(
          _longDate(today),
          style: const TextStyle(
            fontSize: 13,
            color: _muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Good ${_greeting()}, $firstName ✨',
          style: TextStyle(
            fontSize: mobile ? 25 : 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'A little progress each day adds up to big results.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth < 620 ? 2 : 4;
            final width = (constraints.maxWidth - (count - 1) * 12) / count;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats
                  .map(
                    (stat) => SizedBox(
                      width: width,
                      child: _StatCard(data: stat),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 850;
            final welcome = _FocusBanner(
              onStart: onTimer,
              onNewTask: onNewTask,
            );
            final goal = _GoalCard(
              minutes: state.studiedMinutesOn(today),
              goal: state.dailyGoalMinutes,
              onTimer: onTimer,
            );
            if (narrow) {
              return Column(
                children: [welcome, const SizedBox(height: 14), goal],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 7, child: welcome),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: goal),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 850;
            final tasks = _TodayTasksCard(
              tasks: state.todayTasks.take(4).toList(),
              state: state,
              onToggle: onToggle,
              onEdit: onEdit,
              onSeeAll: onSeeTasks,
            );
            final sessions = _UpcomingCard(state: state, onTimer: onTimer);
            if (stacked) {
              return Column(
                children: [tasks, const SizedBox(height: 14), sessions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: tasks),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: sessions),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _WeeklyOverview(state: state),
      ],
    );
  }
}

class _StatData {
  const _StatData(
    this.label,
    this.value,
    this.note,
    this.icon,
    this.color,
    this.tint,
  );
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final Color tint;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: data.tint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(data.icon, color: data.color, size: 19),
              ),
              const Spacer(),
              Icon(
                Icons.more_horiz_rounded,
                size: 19,
                color: _muted.withValues(alpha: .7),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(data.note, style: const TextStyle(fontSize: 10, color: _muted)),
        ],
      ),
    ),
  );
}

class _FocusBanner extends StatelessWidget {
  const _FocusBanner({required this.onStart, required this.onNewTask});
  final VoidCallback onStart;
  final VoidCallback onNewTask;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff675fe2), Color(0xff8172e9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -14,
          bottom: -26,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 135,
            color: Colors.white.withValues(alpha: .08),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'YOUR NEXT BIG THING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Make today\ncount.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 25,
                height: 1.14,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'One focused session is all it takes to get started.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .83),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  label: const Text('Start focusing'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _indigo,
                    minimumSize: const Size(140, 38),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onNewTask,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add a task'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .55),
                    ),
                    minimumSize: const Size(120, 38),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.minutes,
    required this.goal,
    required this.onTimer,
  });
  final int minutes;
  final int goal;
  final VoidCallback onTimer;

  @override
  Widget build(BuildContext context) {
    final progress = goal == 0 ? 0.0 : (minutes / goal).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    backgroundColor: _indigo.withValues(alpha: .11),
                    color: _indigo,
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'of goal',
                        style: TextStyle(fontSize: 10, color: _muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily study goal',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_durationLabel(minutes)} of ${_durationLabel(goal)} studied',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onTimer,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: _indigo,
                    ),
                    icon: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Start a session',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayTasksCard extends StatelessWidget {
  const _TodayTasksCard({
    required this.tasks,
    required this.state,
    required this.onToggle,
    required this.onEdit,
    required this.onSeeAll,
  });
  final List<StudyTask> tasks;
  final PlannerState state;
  final ValueChanged<String> onToggle;
  final ValueChanged<StudyTask> onEdit;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            title: 'Today’s focus',
            trailing: TextButton(
              onPressed: onSeeAll,
              child: const Text('View all'),
            ),
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            const _EmptyState(
              icon: Icons.celebration_outlined,
              title: 'Nothing due today',
              message: 'Enjoy the breathing room or plan ahead.',
            )
          else
            ...tasks.map(
              (task) => _TaskRow(
                task: task,
                subject: state.subjectById(task.subjectId),
                onToggle: () => onToggle(task.id),
                onTap: () => onEdit(task),
              ),
            ),
        ],
      ),
    ),
  );
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.state, required this.onTimer});
  final PlannerState state;
  final VoidCallback onTimer;

  @override
  Widget build(BuildContext context) {
    final sessions = state.upcomingSessions.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeading(
              title: 'Coming up',
              trailing: IconButton(
                onPressed: onTimer,
                tooltip: 'Open study timer',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_outward_rounded, size: 17),
              ),
            ),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const _EmptyState(
                icon: Icons.event_available_rounded,
                title: 'No sessions planned',
                message: 'Make space for a focused study block.',
              )
            else
              ...sessions.map((session) {
                final subject = state.subjectById(session.subjectId);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 42,
                        decoration: BoxDecoration(
                          color: subject == null
                              ? _indigo
                              : Color(subject.color),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${subject?.name ?? 'Study'} · ${_timeLabel(session.startsAt)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${session.minutes}m',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _WeeklyOverview extends StatelessWidget {
  const _WeeklyOverview({required this.state});
  final PlannerState state;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (index) {
      final date = DateTime(today.year, today.month, today.day - 6 + index);
      return _BarValue(
        label: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1],
        value: state.studiedMinutesOn(date) / 60,
        active: sameDay(date, today),
      );
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeading(
              title: 'Your study rhythm',
              subtitle: 'Study hours over the last 7 days',
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: _BarChart(values: days, color: _indigo),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ],
        ),
      ),
      trailing ?? const SizedBox.shrink(),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, color: _indigo, size: 30),
        const SizedBox(height: 9),
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: _muted),
        ),
      ],
    ),
  );
}

class _TasksPage extends StatelessWidget {
  const _TasksPage({
    required this.state,
    required this.query,
    required this.onQuery,
    required this.priority,
    required this.onPriority,
    required this.showCompleted,
    required this.onShowCompleted,
    required this.onNew,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerState state;
  final String query;
  final ValueChanged<String> onQuery;
  final TaskPriority? priority;
  final ValueChanged<TaskPriority?> onPriority;
  final bool showCompleted;
  final ValueChanged<bool> onShowCompleted;
  final VoidCallback onNew;
  final ValueChanged<StudyTask> onEdit;
  final ValueChanged<StudyTask> onDelete;

  @override
  Widget build(BuildContext context) {
    final filtered = state.sortedTasks.where((task) {
      final subjectName = state.subjectById(task.subjectId)?.name ?? '';
      final matchesQuery =
          query.trim().isEmpty ||
          '${task.title} ${task.description} $subjectName'
              .toLowerCase()
              .contains(query.toLowerCase());
      final matchesPriority = priority == null || task.priority == priority;
      final matchesStatus = showCompleted || !task.isDone;
      return matchesQuery && matchesPriority && matchesStatus;
    }).toList();
    return _PageScroll(
      children: [
        const _PageIntro(
          title: 'Your tasks, in one place.',
          subtitle:
              'Stay on top of assignments and make every deadline feel manageable.',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 680;
                    final search = TextField(
                      onChanged: onQuery,
                      decoration: InputDecoration(
                        hintText: 'Search tasks or subjects…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => onQuery(''),
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    );
                    final add = FilledButton.icon(
                      onPressed: onNew,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add task'),
                    );
                    return narrow
                        ? Column(
                            children: [
                              search,
                              const SizedBox(height: 10),
                              SizedBox(width: double.infinity, child: add),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: search),
                              const SizedBox(width: 12),
                              add,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _FilterChoice(
                      label: 'All priorities',
                      selected: priority == null,
                      onTap: () => onPriority(null),
                    ),
                    ...TaskPriority.values.map(
                      (value) => _FilterChoice(
                        label: _priorityLabel(value),
                        selected: priority == value,
                        onTap: () =>
                            onPriority(priority == value ? null : value),
                        color: _priorityColor(value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Show completed'),
                      selected: showCompleted,
                      onSelected: onShowCompleted,
                      avatar: Icon(
                        showCompleted
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Card(
            child: _EmptyState(
              icon: query.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.check_circle_outline_rounded,
              title: query.isNotEmpty
                  ? 'No matching tasks'
                  : 'No tasks to show',
              message: query.isNotEmpty
                  ? 'Try another search or adjust the filters.'
                  : 'Add your first task to get your study plan moving.',
            ),
          )
        else
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 17, 18, 10),
                  child: _CardHeading(
                    title: '${showCompleted ? 'All' : 'Open'} tasks',
                    subtitle:
                        '${filtered.length} ${filtered.length == 1 ? 'task' : 'tasks'} · sorted by due date',
                  ),
                ),
                ...filtered.map(
                  (task) => _TaskRow(
                    task: task,
                    subject: state.subjectById(task.subjectId),
                    onToggle: () => state.toggleTask(task.id),
                    onTap: () => onEdit(task),
                    onDelete: () => onDelete(task),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 10), trailing!],
    ],
  );
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    labelStyle: TextStyle(
      fontSize: 11,
      color: selected ? _indigo : null,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    ),
    avatar: color == null
        ? null
        : Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
  );
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.subject,
    required this.onToggle,
    required this.onTap,
    this.onDelete,
  });

  final StudyTask task;
  final StudySubject? subject;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = subject == null ? _indigo : Color(subject!.color);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          children: [
            Checkbox(
              value: task.isDone,
              onChanged: (_) => onToggle(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              activeColor: _indigo,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isDone ? _muted : null,
                    ),
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (subject != null && MediaQuery.sizeOf(context).width > 520)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subject!.name,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _priorityColor(task.priority).withValues(alpha: .11),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _priorityLabel(task.priority),
                style: TextStyle(
                  fontSize: 9,
                  color: _priorityColor(task.priority),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 9),
            if (MediaQuery.sizeOf(context).width > 420)
              Text(
                _dueLabel(task.dueAt),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _isOverdue(task) ? const Color(0xffdb5967) : _muted,
                ),
              ),
            if (onDelete != null)
              PopupMenuButton<String>(
                tooltip: 'Task actions',
                iconSize: 18,
                onSelected: (value) {
                  if (value == 'edit') onTap();
                  if (value == 'delete') onDelete!();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit task')),
                  PopupMenuItem(value: 'delete', child: Text('Delete task')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class TaskEditorDialog extends StatefulWidget {
  const TaskEditorDialog({
    super.key,
    required this.subjects,
    this.existing,
    this.initialDate,
  });
  final List<StudySubject> subjects;
  final StudyTask? existing;
  final DateTime? initialDate;

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _subjectId;
  late DateTime _dueAt;
  late TaskPriority _priority;

  @override
  void initState() {
    super.initState();
    final task = widget.existing;
    _title = TextEditingController(text: task?.title ?? '');
    _description = TextEditingController(text: task?.description ?? '');
    _subjectId = task?.subjectId ?? widget.subjects.first.id;
    _dueAt =
        task?.dueAt ??
        widget.initialDate ??
        DateTime.now().add(const Duration(hours: 2));
    _priority = task?.priority ?? TaskPriority.medium;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Create a task' : 'Edit task'),
    content: SizedBox(
      width: 450,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Task name',
                  hintText: 'e.g. Review lecture notes',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a task name.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                maxLength: 200,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _subjectId,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: widget.subjects
                    .map(
                      (subject) => DropdownMenuItem(
                        value: subject.id,
                        child: Text(subject.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _subjectId = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: TaskPriority.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              size: 16,
                              color: _priorityColor(value),
                            ),
                            const SizedBox(width: 8),
                            Text(_priorityLabel(value)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _priority = value!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(_shortDate(_dueAt)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_rounded, size: 16),
                      label: Text(_timeLabel(_dueAt)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            StudyTask(
              id:
                  widget.existing?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              title: _title.text.trim(),
              description: _description.text.trim(),
              subjectId: _subjectId,
              dueAt: _dueAt,
              priority: _priority,
              isDone: widget.existing?.isDone ?? false,
            ),
          );
        },
        child: Text(widget.existing == null ? 'Create task' : 'Save changes'),
      ),
    ],
  );

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (result != null) {
      setState(
        () => _dueAt = DateTime(
          result.year,
          result.month,
          result.day,
          _dueAt.hour,
          _dueAt.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (result != null) {
      setState(
        () => _dueAt = DateTime(
          _dueAt.year,
          _dueAt.month,
          _dueAt.day,
          result.hour,
          result.minute,
        ),
      );
    }
  }
}

class SessionEditorDialog extends StatefulWidget {
  const SessionEditorDialog({
    super.key,
    required this.planner,
    required this.subjects,
    this.initialDate,
  });
  final PlannerState planner;
  final List<StudySubject> subjects;
  final DateTime? initialDate;

  @override
  State<SessionEditorDialog> createState() => _SessionEditorDialogState();
}

class _SessionEditorDialogState extends State<SessionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _minutes = TextEditingController(text: '50');
  late String _subjectId;
  late DateTime _startsAt;
  String? _conflict;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjects.first.id;
    final now = DateTime.now();
    final base = widget.initialDate ?? now;
    _startsAt = DateTime(base.year, base.month, base.day, now.hour + 1, 0);
  }

  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Plan a study session'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                maxLength: 70,
                decoration: const InputDecoration(
                  labelText: 'Session name',
                  hintText: 'e.g. Focused revision',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a session name.'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _subjectId,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: widget.subjects
                    .map(
                      (subject) => DropdownMenuItem(
                        value: subject.id,
                        child: Text(subject.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _subjectId = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Duration in minutes',
                  suffixText: 'min',
                ),
                validator: (value) {
                  final minutes = int.tryParse(value ?? '');
                  return minutes == null || minutes < 5 || minutes > 480
                      ? 'Choose a duration from 5 to 480 minutes.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(_shortDate(_startsAt)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_rounded, size: 16),
                      label: Text(_timeLabel(_startsAt)),
                    ),
                  ),
                ],
              ),
              if (_conflict != null) ...[
                const SizedBox(height: 10),
                Text(
                  _conflict!,
                  style: const TextStyle(
                    color: Color(0xffce5663),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Schedule session')),
    ],
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final minutes = int.parse(_minutes.text);
    if (widget.planner.hasSessionConflict(_startsAt, minutes)) {
      setState(
        () => _conflict =
            'This overlaps another planned session. Choose a different time.',
      );
      return;
    }
    Navigator.pop(
      context,
      StudySession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        subjectId: _subjectId,
        startsAt: _startsAt,
        minutes: minutes,
      ),
    );
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (result != null) {
      setState(() {
        _startsAt = DateTime(
          result.year,
          result.month,
          result.day,
          _startsAt.hour,
          _startsAt.minute,
        );
        _conflict = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (result != null) {
      setState(() {
        _startsAt = DateTime(
          _startsAt.year,
          _startsAt.month,
          _startsAt.day,
          result.hour,
          result.minute,
        );
        _conflict = null;
      });
    }
  }
}

class _PlannerPage extends StatelessWidget {
  const _PlannerPage({
    required this.state,
    required this.onNew,
    required this.onDelete,
  });
  final PlannerState state;
  final VoidCallback onNew;
  final ValueChanged<StudySession> onDelete;

  @override
  Widget build(BuildContext context) {
    final sessions = [...state.sessions]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final now = DateTime.now();
    final upcoming = sessions
        .where((session) => !session.isCompleted && session.endsAt.isAfter(now))
        .toList();
    final completed = sessions.where((session) => session.isCompleted).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return _PageScroll(
      children: [
        _PageIntro(
          title: 'Plan your focus time.',
          subtitle: 'Build a realistic study rhythm, one session at a time.',
          trailing: FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Plan session'),
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 650
                ? constraints.maxWidth
                : (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MiniMetric(
                  width: width,
                  title: 'Upcoming',
                  value: '${upcoming.length}',
                  icon: Icons.event_available_rounded,
                  color: _indigo,
                ),
                _MiniMetric(
                  width: width,
                  title: 'Sessions completed',
                  value: '${completed.length}',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xff17a892),
                ),
                _MiniMetric(
                  width: width,
                  title: 'Study time today',
                  value: _durationLabel(state.studiedMinutesOn(now)),
                  icon: Icons.timer_outlined,
                  color: const Color(0xffef9a43),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _CardHeading(
          title: 'Upcoming sessions',
          subtitle: 'Your sessions are checked for scheduling conflicts.',
        ),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          Card(
            child: _EmptyState(
              icon: Icons.event_note_rounded,
              title: 'Your schedule is open',
              message:
                  'Create a study session and give your goals a time and place.',
            ),
          )
        else
          ...upcoming.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SessionTile(
                session: session,
                subject: state.subjectById(session.subjectId),
                onDelete: () => onDelete(session),
              ),
            ),
          ),
        const SizedBox(height: 15),
        _CardHeading(
          title: 'Completed sessions',
          subtitle: 'Finished focus blocks count toward your study goal.',
        ),
        const SizedBox(height: 10),
        if (completed.isEmpty)
          const Card(
            child: _EmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'No completed sessions yet',
              message: 'Finish a focus timer to see it here.',
            ),
          )
        else
          ...completed
              .take(8)
              .map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SessionTile(
                    session: session,
                    subject: state.subjectById(session.subjectId),
                    onDelete: () => onDelete(session),
                  ),
                ),
              ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.subject,
    required this.onDelete,
  });
  final StudySession session;
  final StudySubject? subject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = subject == null ? _indigo : Color(subject!.color);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.menu_book_rounded, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${subject?.name ?? 'Study'} · ${_longDate(session.startsAt)} · ${_timeLabel(session.startsAt)}',
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${session.minutes} min',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Remove session',
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage({
    required this.state,
    required this.month,
    required this.selectedDay,
    required this.onMonth,
    required this.onSelect,
    required this.onNewTask,
    required this.onNewSession,
    required this.onToggle,
    required this.onEdit,
    required this.onDeleteSession,
  });
  final PlannerState state;
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onNewTask;
  final VoidCallback onNewSession;
  final ValueChanged<String> onToggle;
  final ValueChanged<StudyTask> onEdit;
  final ValueChanged<StudySession> onDeleteSession;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final offset = first.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cellCount = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final dayTasks = state.sortedTasks
        .where((task) => sameDay(task.dueAt, selectedDay))
        .toList();
    final daySessions =
        state.sessions
            .where((session) => sameDay(session.startsAt, selectedDay))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return _PageScroll(
      children: [
        const _PageIntro(
          title: 'See the bigger picture.',
          subtitle: 'Your deadlines and study blocks, all on one calendar.',
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          onMonth(DateTime(month.year, month.month - 1)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${_monthNames[month.month - 1]} ${month.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          onMonth(DateTime(month.year, month.month + 1)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                    TextButton(
                      onPressed: () {
                        final today = DateTime.now();
                        onMonth(today);
                        onSelect(today);
                      },
                      child: const Text('Today'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final label in [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ])
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                color: _muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth = constraints.maxWidth / 7;
                    final cellHeight = (cellWidth * .76).clamp(43.0, 78.0);
                    return Wrap(
                      children: List.generate(cellCount, (index) {
                        final dayNumber = index - offset + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return SizedBox(width: cellWidth, height: cellHeight);
                        }
                        final date = DateTime(
                          month.year,
                          month.month,
                          dayNumber,
                        );
                        final isSelected = sameDay(date, selectedDay);
                        final isToday = sameDay(date, DateTime.now());
                        final tasks = state.tasks
                            .where(
                              (task) =>
                                  sameDay(task.dueAt, date) && !task.isDone,
                            )
                            .length;
                        final sessions = state.sessions
                            .where((session) => sameDay(session.startsAt, date))
                            .length;
                        return SizedBox(
                          width: cellWidth,
                          height: cellHeight,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onSelect(date),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _indigo
                                      : (isToday
                                            ? _indigo.withValues(alpha: .07)
                                            : Colors.transparent),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isToday && !isSelected
                                      ? Border.all(
                                          color: _indigo.withValues(alpha: .25),
                                        )
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$dayNumber',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isToday || isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: isSelected ? Colors.white : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (tasks > 0)
                                          _CalendarDot(
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xffff9e5e),
                                          ),
                                        if (sessions > 0) ...[
                                          if (tasks > 0)
                                            const SizedBox(width: 3),
                                          _CalendarDot(
                                            color: isSelected
                                                ? Colors.white.withValues(
                                                    alpha: .68,
                                                  )
                                                : const Color(0xff17a892),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    _LegendDot(color: Color(0xffff9e5e), text: 'Tasks'),
                    SizedBox(width: 15),
                    _LegendDot(
                      color: Color(0xff17a892),
                      text: 'Study sessions',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 17),
        _CardHeading(
          title: _longDate(selectedDay),
          subtitle:
              '${dayTasks.length} ${dayTasks.length == 1 ? 'task' : 'tasks'} · ${daySessions.length} study sessions',
          trailing: PopupMenuButton<String>(
            tooltip: 'Add to selected date',
            icon: const Icon(Icons.add_circle_outline_rounded, color: _indigo),
            onSelected: (value) =>
                value == 'task' ? onNewTask() : onNewSession(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'task', child: Text('Add a task')),
              PopupMenuItem(
                value: 'session',
                child: Text('Plan a study session'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        if (dayTasks.isEmpty && daySessions.isEmpty)
          const Card(
            child: _EmptyState(
              icon: Icons.event_available_rounded,
              title: 'A clear day',
              message:
                  'Nothing scheduled here yet. Add a task or plan a study session.',
            ),
          )
        else ...[
          ...daySessions.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SessionTile(
                session: session,
                subject: state.subjectById(session.subjectId),
                onDelete: () => onDeleteSession(session),
              ),
            ),
          ),
          ...dayTasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: _TaskRow(
                  task: task,
                  subject: state.subjectById(task.subjectId),
                  onToggle: () => onToggle(task.id),
                  onTap: () => onEdit(task),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CalendarDot extends StatelessWidget {
  const _CalendarDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _CalendarDot(color: color),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 9, color: _muted)),
    ],
  );
}

class _SubjectsPage extends StatelessWidget {
  const _SubjectsPage({required this.state, required this.confirm});
  final PlannerState state;
  final Future<bool> Function(String, String) confirm;

  Future<void> _add(BuildContext context) async {
    final subject = await showDialog<StudySubject>(
      context: context,
      builder: (_) => const _SubjectEditorDialog(),
    );
    if (subject != null) state.saveSubject(subject);
  }

  Future<void> _delete(BuildContext context, StudySubject subject) async {
    final okay = await confirm(
      'Remove ${subject.name}?',
      'This subject can only be removed when it has no linked tasks or study sessions.',
    );
    if (!okay) return;
    if (!state.deleteSubject(subject.id) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This subject is still used by a task or study session.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1);
    return _PageScroll(
      children: [
        _PageIntro(
          title: 'Make room for what you love.',
          subtitle:
              'Organize your focus by subject and see where your study time goes.',
          trailing: FilledButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add subject'),
          ),
        ),
        const SizedBox(height: 20),
        if (state.subjects.isEmpty)
          Card(
            child: _EmptyState(
              icon: Icons.auto_stories_rounded,
              title: 'Start with a subject',
              message: 'Create a subject to organize tasks and study sessions.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth < 620
                  ? 1
                  : constraints.maxWidth < 1050
                  ? 2
                  : 3;
              final width = (constraints.maxWidth - (count - 1) * 14) / count;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: state.subjects.map((subject) {
                  final color = Color(subject.color);
                  final studied = state.sessions
                      .where(
                        (session) =>
                            session.subjectId == subject.id &&
                            session.isCompleted &&
                            !session.startsAt.isBefore(weekStart),
                      )
                      .fold(0, (sum, session) => sum + session.minutes);
                  final linkedTasks = state.tasks
                      .where((task) => task.subjectId == subject.id)
                      .toList();
                  final done = linkedTasks.where((task) => task.isDone).length;
                  final progress = subject.targetHours <= 0
                      ? 0.0
                      : (studied / (subject.targetHours * 60)).clamp(0.0, 1.0);
                  return SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Icon(
                                    _subjectIcon(subject),
                                    color: color,
                                    size: 23,
                                  ),
                                ),
                                const Spacer(),
                                PopupMenuButton<String>(
                                  tooltip: 'Subject actions',
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _delete(context, subject);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Remove subject'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 17),
                            Text(
                              subject.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${linkedTasks.length} tasks · $done completed',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 17),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Weekly study goal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_durationLabel(studied)} / ${subject.targetHours.toStringAsFixed(subject.targetHours % 1 == 0 ? 0 : 1)}h',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                color: color,
                                backgroundColor: color.withValues(alpha: .12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, color: _indigo),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Subject goals help you spread your effort across the week. Update your daily target any time in Settings.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectEditorDialog extends StatefulWidget {
  const _SubjectEditorDialog();

  @override
  State<_SubjectEditorDialog> createState() => _SubjectEditorDialogState();
}

class _SubjectEditorDialogState extends State<_SubjectEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _hours = TextEditingController(text: '3');
  static const _colors = [
    0xff6c63ff,
    0xff21a8a0,
    0xffff9e5e,
    0xffe8799b,
    0xff5086e8,
    0xff9c72d8,
  ];
  static const _icons = [
    Icons.calculate_rounded,
    Icons.science_rounded,
    Icons.biotech_rounded,
    Icons.history_edu_rounded,
    Icons.language_rounded,
    Icons.palette_rounded,
  ];
  int _color = _colors[0];
  int _icon = 0;

  @override
  void dispose() {
    _name.dispose();
    _hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a subject'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Subject name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a subject name.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _hours,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,2}\.?\d{0,1}'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Weekly study goal',
                suffixText: 'hours',
              ),
              validator: (value) {
                final hours = double.tryParse(value ?? '');
                return hours == null || hours < .5 || hours > 40
                    ? 'Set a goal between 0.5 and 40 hours.'
                    : null;
              },
            ),
            const SizedBox(height: 17),
            const Text(
              'Pick a color',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 9,
              children: _colors
                  .map(
                    (color) => InkWell(
                      onTap: () => setState(() => _color = color),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: _color == color
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 3,
                                )
                              : null,
                          boxShadow: _color == color
                              ? [
                                  BoxShadow(
                                    color: Color(color).withValues(alpha: .35),
                                    blurRadius: 0,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: _color == color
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 17),
            const Text(
              'Pick an icon',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              children: List.generate(
                _icons.length,
                (index) => IconButton(
                  onPressed: () => setState(() => _icon = index),
                  style: IconButton.styleFrom(
                    backgroundColor: _icon == index
                        ? Color(_color).withValues(alpha: .13)
                        : null,
                    foregroundColor: _icon == index ? Color(_color) : _muted,
                  ),
                  icon: Icon(_icons[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            StudySubject(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: _name.text.trim(),
              color: _color,
              icon: _icons[_icon].codePoint,
              targetHours: double.parse(_hours.text),
            ),
          );
        },
        child: const Text('Add subject'),
      ),
    ],
  );
}

class _TimerPage extends StatefulWidget {
  const _TimerPage({required this.state});
  final PlannerState state;

  @override
  State<_TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<_TimerPage> {
  Timer? _ticker;
  bool _running = false;
  bool _isBreak = false;
  late int _remaining;
  late String _subjectId;
  String? _completionMessage;

  @override
  void initState() {
    super.initState();
    _remaining = widget.state.focusMinutes * 60;
    _subjectId = widget.state.subjects.isEmpty
        ? ''
        : widget.state.subjects.first.id;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _total => (_isBreak ? 5 : widget.state.focusMinutes) * 60;
  String get _timerText {
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _start() {
    if (!_isBreak && widget.state.subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a subject before starting a focus session.'),
        ),
      );
      return;
    }
    if (!_isBreak && _subjectId.isEmpty) {
      _subjectId = widget.state.subjects.first.id;
    }
    setState(() {
      _running = true;
      _completionMessage = null;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining <= 1) {
        timer.cancel();
        _finishPhase();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _finishPhase() {
    setState(() {
      _running = false;
      if (!_isBreak) {
        final minutes = widget.state.focusMinutes;
        final title = 'Pomodoro focus session';
        widget.state.completeSession(title, _subjectId, minutes);
        _completionMessage =
            '$minutes focused minutes added to your study time.';
        _isBreak = true;
        _remaining = 5 * 60;
      } else {
        _completionMessage = 'Break complete. Ready for another focus round?';
        _isBreak = false;
        _remaining = widget.state.focusMinutes * 60;
      }
    });
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _isBreak = false;
      _remaining = widget.state.focusMinutes * 60;
      _completionMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? 0.0 : 1 - _remaining / _total;
    final activeColor = _isBreak ? const Color(0xff17a892) : _indigo;
    return _PageScroll(
      children: [
        const _PageIntro(
          title: 'One thing at a time.',
          subtitle: 'Focus deeply, then take a real break. You’ve got this.',
        ),
        const SizedBox(height: 20),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TimerMode(
                            label: 'Focus',
                            selected: !_isBreak,
                            color: _indigo,
                            onTap: _isBreak ? null : _reset,
                          ),
                          _TimerMode(
                            label: 'Short break',
                            selected: _isBreak,
                            color: const Color(0xff17a892),
                            onTap: _isBreak
                                ? null
                                : () {
                                    _ticker?.cancel();
                                    setState(() {
                                      _running = false;
                                      _isBreak = true;
                                      _remaining = 5 * 60;
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 11,
                              strokeCap: StrokeCap.round,
                              color: activeColor,
                              backgroundColor: activeColor.withValues(
                                alpha: .1,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isBreak
                                    ? 'TAKE A BREATHER'
                                    : 'STAY IN THE FLOW',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: activeColor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 11),
                              Text(
                                _timerText,
                                style: const TextStyle(
                                  fontSize: 59,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -3,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _isBreak ? 'Short break' : 'Focus session',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 23),
                    if (!_isBreak && widget.state.subjects.isNotEmpty)
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<String>(
                          initialValue: _subjectId.isEmpty
                              ? widget.state.subjects.first.id
                              : _subjectId,
                          decoration: const InputDecoration(
                            labelText: 'Focus subject',
                          ),
                          items: widget.state.subjects
                              .map(
                                (subject) => DropdownMenuItem(
                                  value: subject.id,
                                  child: Text(subject.name),
                                ),
                              )
                              .toList(),
                          onChanged: _running
                              ? null
                              : (value) => setState(() => _subjectId = value!),
                        ),
                      ),
                    if (_completionMessage != null) ...[
                      const SizedBox(height: 13),
                      Text(
                        _completionMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                    const SizedBox(height: 21),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset'),
                        ),
                        const SizedBox(width: 11),
                        FilledButton.icon(
                          onPressed: _running ? _pause : _start,
                          style: FilledButton.styleFrom(
                            backgroundColor: activeColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(145, 48),
                          ),
                          icon: Icon(
                            _running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(_running ? 'Pause' : 'Start focus'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'A completed focus block is saved to your study history.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Today: ${_durationLabel(widget.state.studiedMinutesOn(DateTime.now()))} focused · ${_durationLabel(widget.state.dailyGoalMinutes)} daily goal',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
        ),
      ],
    );
  }
}

class _TimerMode extends StatelessWidget {
  const _TimerMode({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      backgroundColor: selected ? color : Colors.transparent,
      foregroundColor: selected ? Colors.white : _muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 10),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage({required this.state});
  final PlannerState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalMinutes = state.sessions
        .where((session) => session.isCompleted)
        .fold(0, (sum, session) => sum + session.minutes);
    final lastSeven = List.generate(
      7,
      (index) => DateTime(now.year, now.month, now.day - 6 + index),
    );
    final weeklyMinutes = lastSeven.fold(
      0,
      (sum, date) => sum + state.studiedMinutesOn(date),
    );
    final weeklyTasks = state.tasks
        .where(
          (task) =>
              task.isDone && lastSeven.any((date) => sameDay(task.dueAt, date)),
        )
        .length;
    final bars = lastSeven
        .map(
          (date) => _BarValue(
            label: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1],
            value: state.studiedMinutesOn(date) / 60,
            active: sameDay(date, now),
          ),
        )
        .toList();
    final recent = [...state.sessions.where((session) => session.isCompleted)]
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return _PageScroll(
      children: [
        const _PageIntro(
          title: 'Progress you can feel.',
          subtitle: 'A clear view of the time and effort you’re putting in.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth < 600 ? 2 : 4;
            final width = (constraints.maxWidth - (count - 1) * 12) / count;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MiniMetric(
                  width: width,
                  title: 'All-time study',
                  value: _durationLabel(totalMinutes),
                  icon: Icons.hourglass_bottom_rounded,
                  color: _indigo,
                ),
                _MiniMetric(
                  width: width,
                  title: 'This week',
                  value: _durationLabel(weeklyMinutes),
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xff17a892),
                ),
                _MiniMetric(
                  width: width,
                  title: 'Tasks completed',
                  value: '${state.completedCount}',
                  icon: Icons.task_alt_rounded,
                  color: const Color(0xffee9b4d),
                ),
                _MiniMetric(
                  width: width,
                  title: 'This week',
                  value: '$weeklyTasks tasks',
                  icon: Icons.checklist_rounded,
                  color: const Color(0xffdf7595),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 850;
            final chart = Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardHeading(
                      title: 'Study time',
                      subtitle: 'Hours completed over the last 7 days',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 210,
                      child: _BarChart(
                        values: bars,
                        color: _indigo,
                        showGrid: true,
                      ),
                    ),
                  ],
                ),
              ),
            );
            final subject = Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardHeading(
                      title: 'By subject',
                      subtitle: 'Study time this week',
                    ),
                    const SizedBox(height: 19),
                    if (state.subjects.isEmpty)
                      const _EmptyState(
                        icon: Icons.auto_stories_rounded,
                        title: 'No subjects yet',
                        message: 'Add a subject to see your study breakdown.',
                      )
                    else
                      ...state.subjects.map((subject) {
                        final minutes = state.sessions
                            .where(
                              (session) =>
                                  session.subjectId == subject.id &&
                                  session.isCompleted &&
                                  lastSeven.any(
                                    (date) => sameDay(date, session.startsAt),
                                  ),
                            )
                            .fold(0, (sum, session) => sum + session.minutes);
                        final percent = weeklyMinutes == 0
                            ? 0.0
                            : minutes / weeklyMinutes;
                        final color = Color(subject.color);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      subject.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _durationLabel(minutes),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 6,
                                  color: color,
                                  backgroundColor: color.withValues(alpha: .12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
            if (narrow) {
              return Column(
                children: [chart, const SizedBox(height: 14), subject],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: chart),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: subject),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardHeading(
                  title: 'Recent study sessions',
                  subtitle: 'Completed focus blocks',
                ),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  const _EmptyState(
                    icon: Icons.timer_outlined,
                    title: 'Your first session starts here',
                    message: 'Use the study timer to start a focus block.',
                  )
                else
                  ...recent.take(5).map((session) {
                    final subject = state.subjectById(session.subjectId);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Color(
                          subject?.color ?? _indigo.toARGB32(),
                        ).withValues(alpha: .12),
                        child: Icon(
                          Icons.done_rounded,
                          color: Color(subject?.color ?? _indigo.toARGB32()),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        session.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${subject?.name ?? 'Study'} · ${_shortDate(session.startsAt)}',
                        style: const TextStyle(fontSize: 10, color: _muted),
                      ),
                      trailing: Text(
                        '${session.minutes} min',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BarValue {
  const _BarValue({
    required this.label,
    required this.value,
    this.active = false,
  });
  final String label;
  final double value;
  final bool active;
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.color,
    this.showGrid = false,
  });
  final List<_BarValue> values;
  final Color color;
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(
      1,
      (maximum, item) => math.max(maximum, item.value),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelHeight = 23.0;
        final chartHeight = constraints.maxHeight - labelHeight;
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (showGrid)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        4,
                        (_) => Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: .14),
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: values.map((item) {
                      final ratio = (item.value / maxValue).clamp(0.0, 1.0);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (item.value > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Text(
                                    item.value < 1
                                        ? '${(item.value * 60).round()}m'
                                        : '${item.value.toStringAsFixed(item.value < 10 ? 1 : 0)}h',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                width: math.min(
                                  30,
                                  constraints.maxWidth / values.length - 12,
                                ),
                                height: math.max(
                                  item.value > 0 ? 5 : 2,
                                  (chartHeight - 40) * ratio,
                                ),
                                decoration: BoxDecoration(
                                  color: item.active
                                      ? color
                                      : color.withValues(alpha: .33),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: labelHeight,
              child: Row(
                children: values
                    .map(
                      (item) => Expanded(
                        child: Center(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: item.active ? color : _muted,
                              fontWeight: item.active
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage({required this.state, required this.onTasks});
  final PlannerState state;
  final VoidCallback onTasks;

  @override
  Widget build(BuildContext context) {
    final reminders = state.reminders;
    return _PageScroll(
      children: [
        _PageIntro(
          title: 'A gentle nudge, right on time.',
          subtitle: 'Keep an eye on upcoming deadlines and unfinished work.',
          trailing: reminders.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: state.markRemindersRead,
                  icon: const Icon(Icons.done_all_rounded, size: 17),
                  label: const Text('Mark all read'),
                ),
        ),
        const SizedBox(height: 18),
        if (!state.remindersEnabled)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.notifications_off_outlined, color: _muted),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Reminders are paused. Turn them back on in Settings to see task deadline alerts.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => state.setRemindersEnabled(true),
                    child: const Text('Turn on'),
                  ),
                ],
              ),
            ),
          )
        else if (reminders.isEmpty)
          const Card(
            child: _EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'All clear for now',
              message: 'When tasks are due soon, you’ll find a reminder here.',
            ),
          )
        else
          ...reminders.map((task) {
            final unread = !state.readReminderIds.contains(task.id);
            final overdue = task.dueAt.isBefore(DateTime.now());
            final color = overdue
                ? const Color(0xffd85f6b)
                : const Color(0xffe39a45);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 7,
                  ),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      overdue
                          ? Icons.warning_amber_rounded
                          : Icons.alarm_rounded,
                      color: color,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: _indigo,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      overdue
                          ? 'Overdue · due ${_shortDate(task.dueAt)}'
                          : 'Due ${_dueLabel(task.dueAt)} · ${state.subjectById(task.subjectId)?.name ?? 'Study task'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: overdue ? color : _muted,
                      ),
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: onTasks,
                    child: const Text('View task'),
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: _indigo),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'These are in-app reminders based on your task deadlines. No push notification service or account is required.',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.state});
  final PlannerState state;

  @override
  Widget build(BuildContext context) => _PageScroll(
    children: [
      const _PageIntro(
        title: 'Make StudyFlow yours.',
        subtitle: 'Tune your study rhythm and how the app feels.',
      ),
      const SizedBox(height: 19),
      Card(
        child: Column(
          children: [
            _SettingsRow(
              icon: Icons.flag_outlined,
              title: 'Daily study goal',
              subtitle: 'Set a target for focused study time each day.',
              trailing: DropdownButton<int>(
                value: state.dailyGoalMinutes,
                underline: const SizedBox.shrink(),
                items: const [60, 90, 120, 150, 180, 240, 300, 360]
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text(_durationLabel(minutes)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) state.setGoal(value);
                },
              ),
            ),
            const Divider(height: 1, indent: 68),
            _SettingsRow(
              icon: Icons.timer_outlined,
              title: 'Focus session length',
              subtitle: 'Choose how long each Pomodoro focus block lasts.',
              trailing: DropdownButton<int>(
                value: state.focusMinutes,
                underline: const SizedBox.shrink(),
                items: const [15, 20, 25, 30, 45, 50]
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes min'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) state.setFocusMinutes(value);
                },
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: Column(
          children: [
            _SettingsRow(
              icon: state.isDark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              title: 'Dark appearance',
              subtitle: 'Give your eyes a softer study space.',
              trailing: Switch(
                value: state.isDark,
                onChanged: state.setDark,
                activeTrackColor: _indigo,
              ),
            ),
            const Divider(height: 1, indent: 68),
            _SettingsRow(
              icon: Icons.notifications_active_outlined,
              title: 'In-app reminders',
              subtitle: 'Show alerts for tasks due within the next 24 hours.',
              trailing: Switch(
                value: state.remindersEnabled,
                onChanged: state.setRemindersEnabled,
                activeTrackColor: _indigo,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _indigo.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.lock_outline_rounded, color: _indigo),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your data stays on this device',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Tasks, subjects, sessions and preferences are saved locally in this browser. No account or remote service is used.',
                      style: TextStyle(
                        fontSize: 10,
                        color: _muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _indigo),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'StudyFlow',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'Made for curious minds · v1.0',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _indigo.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _indigo, size: 20),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    ),
  );
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _shortDate(DateTime date) =>
    '${_monthNames[date.month - 1].substring(0, 3)} ${date.day}';
String _longDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_monthNames[date.month - 1]} ${date.day}';
String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'evening';
}

String _timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

String _dueLabel(DateTime date) {
  final now = DateTime.now();
  if (sameDay(date, now)) return 'Today · ${_timeLabel(date)}';
  if (sameDay(date, DateTime(now.year, now.month, now.day + 1))) {
    return 'Tomorrow · ${_timeLabel(date)}';
  }
  return '${_shortDate(date)} · ${_timeLabel(date)}';
}

String _durationLabel(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String _priorityLabel(TaskPriority priority) => switch (priority) {
  TaskPriority.low => 'Low',
  TaskPriority.medium => 'Medium',
  TaskPriority.high => 'High',
};

Color _priorityColor(TaskPriority priority) => switch (priority) {
  TaskPriority.low => const Color(0xff17a892),
  TaskPriority.medium => const Color(0xffdf9b44),
  TaskPriority.high => const Color(0xffdc6474),
};

bool _isOverdue(StudyTask task) =>
    !task.isDone && task.dueAt.isBefore(DateTime.now());

int _streakDays(PlannerState state) {
  var count = 0;
  var day = DateTime.now();
  if (state.studiedMinutesOn(day) == 0) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  while (state.studiedMinutesOn(day) > 0) {
    count++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return count;
}

IconData _subjectIcon(StudySubject subject) {
  final name = subject.name.toLowerCase();
  if (name.contains('math')) return Icons.calculate_rounded;
  if (name.contains('physics')) return Icons.science_rounded;
  if (name.contains('biology')) return Icons.biotech_rounded;
  if (name.contains('history')) return Icons.history_edu_rounded;
  for (final icon in _availableSubjectIcons) {
    if (icon.codePoint == subject.icon) return icon;
  }
  return Icons.menu_book_rounded;
}

const _availableSubjectIcons = [
  Icons.calculate_rounded,
  Icons.science_rounded,
  Icons.biotech_rounded,
  Icons.history_edu_rounded,
  Icons.language_rounded,
  Icons.palette_rounded,
];
