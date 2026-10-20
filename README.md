# StudyFlow

A responsive Flutter study planner and to-do tracker for organizing coursework, study sessions, and focused work.

## Run locally

```powershell
flutter pub get
flutter run -d chrome
```

The app stores tasks, subjects, study sessions, reminders, and preferences locally in the browser with `shared_preferences`. Demo data is included on first launch; no account, server, or external API is required.

## Included

- Dashboard with task, daily-goal, and study-streak summaries
- Searchable tasks with priorities, deadlines, completion, and editing
- Subject organization and a conflict-aware study schedule
- Calendar, Pomodoro timer, study analytics, and deadline reminders
- Responsive navigation, dark mode, and configurable study goals

## Verify or build

```powershell
flutter test
flutter analyze
flutter build web
```
