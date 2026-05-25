import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('모아북'), findsOneWidget);
  });
}
