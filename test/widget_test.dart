import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moabook/domain/repository/auth_repository.dart';
import 'package:moabook/features/auth/provider/auth_provider.dart';
import 'package:moabook/features/notification/provider/notification_providers.dart';
import 'package:moabook/features/notification/service/fcm_service.dart';
import 'package:moabook/main.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// FcmService 는 생성자에서 `FirebaseMessaging.instance` 를 잡아 Firebase 초기화를
/// 요구한다. 위젯 스모크 테스트는 Firebase 를 띄우지 않으므로 no-op fake 로 대체.
class FakeFcmService extends Fake implements FcmService {
  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets('App smoke test — renders without crash', (tester) async {
    final mockRepo = MockAuthRepository();
    when(() => mockRepo.isLoggedIn()).thenAnswer((_) async => false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockRepo),
          fcmServiceProvider.overrideWithValue(FakeFcmService()),
        ],
        child: const App(),
      ),
    );

    // SplashScreen의 1초 딜레이 완료
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(App), findsOneWidget);
  });
}
