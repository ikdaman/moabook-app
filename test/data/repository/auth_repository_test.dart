import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moabook/data/datasource/auth_remote_datasource.dart';
import 'package:moabook/data/datasource/social_auth_datasource.dart';
import 'package:moabook/data/model/login_result.dart';
import 'package:moabook/data/model/social_login_result.dart';
import 'package:moabook/data/repository/auth_repository_impl.dart';
import 'package:moabook/domain/model/login_state.dart';
import 'package:moabook/domain/model/signup_state.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockSocialAuthDataSource  extends Mock implements SocialAuthDataSource {}
class MockFlutterSecureStorage  extends Mock implements FlutterSecureStorage {}

void main() {
  late MockAuthRemoteDataSource remote;
  late MockSocialAuthDataSource social;
  late MockFlutterSecureStorage storage;
  late AuthRepositoryImpl repo;

  setUp(() {
    remote  = MockAuthRemoteDataSource();
    social  = MockSocialAuthDataSource();
    storage = MockFlutterSecureStorage();
    repo    = AuthRepositoryImpl(remote, social, storage);
  });

  const fakeResult = LoginResult(
    provider:      'KAKAO',
    authorization: 'Bearer token123',
    refreshToken:  'refresh456',
    nickname:      '테스트',
  );
  const fakeSocial = SocialLoginResult(
    isSuccess:        true,
    socialAccessToken: 'social_token',
    provider:         'KAKAO',
    providerId:       '12345',
  );

  group('kakaoLogin', () {
    test('성공 시 LoginSuccess 방출', () async {
      when(() => social.kakaoLogin())
          .thenAnswer((_) async => fakeSocial);
      when(() => remote.login(
            socialToken: any(named: 'socialToken'),
            provider:    any(named: 'provider'),
            providerId:  any(named: 'providerId'),
          )).thenAnswer((_) async => (fakeResult, 200));
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});

      final states = await repo.kakaoLogin().toList();

      expect(states.first, isA<LoginLoading>());
      expect(states.last,  isA<LoginSuccess>());
    });

    test('소셜 로그인 실패 시 LoginError 방출', () async {
      when(() => social.kakaoLogin()).thenAnswer((_) async =>
          const SocialLoginResult(
              isSuccess: false, errorMessage: '카카오 오류'));

      final states = await repo.kakaoLogin().toList();

      expect(states.last, isA<LoginError>());
      expect((states.last as LoginError).message, contains('카카오'));
    });
  });

  group('signup', () {
    test('성공 시 SignupSuccess 방출', () async {
      when(() => remote.signup(
            socialToken: any(named: 'socialToken'),
            provider:    any(named: 'provider'),
            providerId:  any(named: 'providerId'),
            nickname:    any(named: 'nickname'),
          )).thenAnswer((_) async => fakeResult);
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});

      final states = await repo
          .signup(
            socialToken: 'tok',
            provider:    'KAKAO',
            providerId:  '12345',
            nickname:    '테스트',
          )
          .toList();

      expect(states.first, isA<SignupLoading>());
      expect(states.last,  isA<SignupSuccess>());
    });
  });

  group('isLoggedIn', () {
    test('토큰 있으면 true', () async {
      when(() => storage.read(key: 'access_token'))
          .thenAnswer((_) async => 'some_token');
      expect(await repo.isLoggedIn(), isTrue);
    });

    test('토큰 없으면 false', () async {
      when(() => storage.read(key: 'access_token'))
          .thenAnswer((_) async => null);
      expect(await repo.isLoggedIn(), isFalse);
    });
  });
}
