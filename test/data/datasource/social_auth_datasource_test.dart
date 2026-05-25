import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/data/datasource/social_auth_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('project.side.ikdaman/google_auth');

  group('SocialAuthDataSourceImpl - Google Android (MethodChannel)', () {
    late SocialAuthDataSourceImpl datasource;

    setUp(() {
      datasource = SocialAuthDataSourceImpl();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('login 성공 시 idToken과 providerId 반환', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'login') {
          return {
            'isSuccess': true,
            'idToken': 'fake.idtoken.value',
            'providerId': 'user123',
          };
        }
        return null;
      });

      final result = await datasource.googleLoginAndroidForTest();

      expect(result.isSuccess, isTrue);
      expect(result.socialAccessToken, 'fake.idtoken.value');
      expect(result.providerId, 'user123');
      expect(result.provider, 'GOOGLE');
    });

    test('login 취소 시 isSuccess false 반환', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'CREDENTIAL_EXCEPTION', message: 'cancel');
      });

      final result = await datasource.googleLoginAndroidForTest();

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('취소'));
    });

    test('idToken null이면 isSuccess false 반환', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'login') {
          return {'isSuccess': true, 'idToken': null, 'providerId': ''};
        }
        return null;
      });

      final result = await datasource.googleLoginAndroidForTest();

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('ID 토큰'));
    });

    test('logout 호출 시 예외 없이 완료', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      await expectLater(datasource.googleLogoutAndroidForTest(), completes);
    });
  });
}
