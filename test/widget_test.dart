import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KantuMarketApp());
    expect(find.byType(KantuMarketApp), findsOneWidget);
  });
}
