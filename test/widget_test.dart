import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moabook/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    // go_router renders the initial route (Splash scaffold)
    expect(find.byType(App), findsOneWidget);
  });
}
