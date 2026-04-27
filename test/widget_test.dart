import 'package:flutter_test/flutter_test.dart';
import 'package:manahflow/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BuildFlowApp());
    expect(find.byType(BuildFlowApp), findsOneWidget);
  });
}
