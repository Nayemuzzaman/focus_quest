import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest_example/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Haptic feedback goes through the platform channel, which has no engine
    // to answer it in widget tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  testWidgets('shows the example app title and idle controls', (tester) async {
    await tester.pumpWidget(const FocusQuestExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Focus Quest'), findsOneWidget);
    expect(find.text('Status: idle'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Start'), findsOneWidget);
  });

  testWidgets('starting a session moves the status to running', (tester) async {
    await tester.pumpWidget(const FocusQuestExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Start'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Status: running'), findsOneWidget);

    // Stop the controller's ticker before the test ends.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Status: idle'), findsOneWidget);
  });
}
