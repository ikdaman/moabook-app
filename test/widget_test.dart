import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moabook/domain/repository/auth_repository.dart';
import 'package:moabook/features/auth/provider/auth_provider.dart';
import 'package:moabook/main.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  testWidgets('App smoke test — renders without crash', (tester) async {
    final mockRepo = MockAuthRepository();
    when(() => mockRepo.isLoggedIn()).thenAnswer((_) async => false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const App(),
      ),
    );

    // SplashScreen의 1초 딜레이 완료
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(App), findsOneWidget);
  });
}
