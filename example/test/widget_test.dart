import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest_example/main.dart';

void main() {
  testWidgets('shows the example app title', (tester) async {
    await tester.pumpWidget(const FocusQuestExampleApp());

    expect(find.text('Focus Quest'), findsOneWidget);
  });
}
