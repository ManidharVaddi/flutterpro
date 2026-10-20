import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterproject/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('StudyFlow loads its dashboard and demo data', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StudyFlowApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Your study rhythm'), findsOneWidget);
    expect(find.text('Today’s focus'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Review vectors');
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    expect(find.text('Review vectors'), findsOneWidget);
  });

  testWidgets('StudyFlow fits a phone layout', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StudyFlowApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.byTooltip('Open navigation'), findsOneWidget);
  });

  testWidgets('all planner destinations display their pages', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StudyFlowApp());
    await tester.pumpAndSettle();

    const destinations = {
      'My Tasks': 'Your tasks, in one place.',
      'Study Planner': 'Plan your focus time.',
      'Calendar': 'See the bigger picture.',
      'Subjects': 'Make room for what you love.',
      'Study Timer': 'One thing at a time.',
      'Analytics': 'Progress you can feel.',
      'Notifications': 'A gentle nudge, right on time.',
      'Settings': 'Make StudyFlow yours.',
    };

    for (final destination in destinations.entries) {
      await tester.tap(find.text(destination.key).first);
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsOneWidget);
    }
  });
}
