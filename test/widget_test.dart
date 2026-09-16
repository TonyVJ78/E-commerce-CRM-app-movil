import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/main.dart';
import 'package:kantu_market/core/services/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>(
        create: (_) => AuthService(),
        child: const KantuMarketApp(),
      ),
    );
    expect(find.byType(KantuMarketApp), findsOneWidget);
  });
}
