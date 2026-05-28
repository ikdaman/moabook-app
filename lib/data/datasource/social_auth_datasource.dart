import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../model/social_login_result.dart';
import '../../core/env/env.dart';

abstract interface class SocialAuthDataSource {
  Future<SocialLoginResult> kakaoLogin();
  Future<SocialLoginResult> naverLogin();
  Future<SocialLoginResult> googleLogin();
  Future<SocialLoginResult> appleLogin();
  Future<void> kakaoLogout();
  Future<void> naverLogout();
  Future<void> googleLogout();
  Future<void> appleLogout();
}

class SocialAuthDataSourceImpl implements SocialAuthDataSource {
  // Android: CredentialManager via MethodChannel (key.properties에서 CLIENT_ID 주입)
  // iOS: google_sign_in SDK 사용
  static const _googleAuthChannel =
      MethodChannel('project.side.ikdaman/google_auth');

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: Env.googleClientId.isNotEmpty ? Env.googleClientId : null,
    scopes: ['email'],
  );

  // ── Kakao ────────────────────────────────────────────────────────────────

  @override
  Future<SocialLoginResult> kakaoLogin() async {
    try {
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (_) {
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      final user = await UserApi.instance.me();
      return SocialLoginResult(
        isSuccess:         true,
        socialAccessToken: token.accessToken,
        provider:          'KAKAO',
        providerId:        user.id.toString(),
      );
    } catch (e) {
      return SocialLoginResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<void> kakaoLogout() async {
    try { await UserApi.instance.unlink(); } catch (_) {}
  }

  // ── Naver ────────────────────────────────────────────────────────────────

  static const _naverChannel = MethodChannel('flutter_naver_login');

  @override
  Future<SocialLoginResult> naverLogin() async {
    try {
      final raw = await _naverChannel.invokeMethod('logIn');
      final res = (raw as Map?)?.cast<Object?, Object?>() ?? const {};
      final status = ((res['status'] as String?) ?? '')
          .toLowerCase()
          .replaceAll('_', '');

      if (status != 'loggedin') {
        return SocialLoginResult(
          isSuccess:    false,
          errorMessage: (res['errorMessage'] as String?)?.isNotEmpty == true
              ? res['errorMessage'] as String
              : '네이버 로그인에 실패했습니다.',
        );
      }

      final account = (res['account'] as Map?)?.cast<Object?, Object?>();
      final providerId = account?['id']?.toString() ?? '';

      final tokenRaw = await _naverChannel.invokeMethod('getCurrentAccessToken');
      final tokenMap = (tokenRaw as Map?)?.cast<Object?, Object?>() ?? const {};
      final tokenField = tokenMap['accessToken'];
      String accessToken = '';
      if (tokenField is String) {
        accessToken = tokenField;
      } else if (tokenField is Map) {
        accessToken = tokenField['accessToken']?.toString() ?? '';
      }

      if (accessToken.isEmpty || providerId.isEmpty) {
        return SocialLoginResult(
          isSuccess:    false,
          errorMessage: '네이버 로그인 응답이 비어있습니다.',
        );
      }

      return SocialLoginResult(
        isSuccess:         true,
        socialAccessToken: accessToken,
        provider:          'NAVER',
        providerId:        providerId,
      );
    } catch (e) {
      return SocialLoginResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<void> naverLogout() async {
    try { await FlutterNaverLogin.logOutAndDeleteToken(); } catch (_) {}
  }

  // ── Google ───────────────────────────────────────────────────────────────

  @override
  Future<SocialLoginResult> googleLogin() async {
    if (Platform.isAndroid) {
      return _googleLoginAndroid();
    }
    return _googleLoginIOS();
  }

  Future<SocialLoginResult> googleLoginAndroidForTest() => _googleLoginAndroid();
  Future<void> googleLogoutAndroidForTest() async {
    try { await _googleAuthChannel.invokeMethod<void>('logout'); } catch (_) {}
  }

  Future<SocialLoginResult> _googleLoginAndroid() async {
    try {
      final result = await _googleAuthChannel.invokeMapMethod<String, dynamic>('login');
      if (result == null) {
        return const SocialLoginResult(isSuccess: false, errorMessage: '구글 로그인 결과가 없습니다.');
      }
      final idToken = result['idToken'] as String?;
      if (idToken == null || idToken.isEmpty) {
        return const SocialLoginResult(isSuccess: false, errorMessage: 'ID 토큰을 가져올 수 없습니다.');
      }
      return SocialLoginResult(
        isSuccess:         true,
        socialAccessToken: idToken,
        provider:          'GOOGLE',
        providerId:        result['providerId'] as String? ?? '',
      );
    } on PlatformException catch (e) {
      if (e.code == 'CREDENTIAL_EXCEPTION' && (e.message?.contains('cancel') == true || e.message?.contains('16') == true)) {
        return const SocialLoginResult(isSuccess: false, errorMessage: '구글 로그인이 취소되었습니다.');
      }
      return SocialLoginResult(isSuccess: false, errorMessage: e.message ?? e.toString());
    } catch (e) {
      return SocialLoginResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  Future<SocialLoginResult> _googleLoginIOS() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return const SocialLoginResult(isSuccess: false, errorMessage: '구글 로그인이 취소되었습니다.');
      }
      final auth    = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        return const SocialLoginResult(isSuccess: false, errorMessage: 'ID 토큰을 가져올 수 없습니다.');
      }
      return SocialLoginResult(
        isSuccess:         true,
        socialAccessToken: idToken,
        provider:          'GOOGLE',
        providerId:        _extractSub(idToken),
      );
    } catch (e) {
      return SocialLoginResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<void> googleLogout() async {
    if (Platform.isAndroid) {
      try { await _googleAuthChannel.invokeMethod<void>('logout'); } catch (_) {}
    } else {
      try { await _googleSignIn.signOut(); } catch (_) {}
    }
  }

  // ── Apple (iOS only) ─────────────────────────────────────────────────────

  @override
  Future<SocialLoginResult> appleLogin() async {
    if (!Platform.isIOS) {
      return const SocialLoginResult(
        isSuccess:    false,
        errorMessage: '애플 로그인은 iOS 에서만 사용 가능합니다.',
      );
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        return const SocialLoginResult(
          isSuccess:    false,
          errorMessage: 'Apple ID 토큰을 가져올 수 없습니다.',
        );
      }
      return SocialLoginResult(
        isSuccess:         true,
        socialAccessToken: idToken,
        provider:          'APPLE',
        providerId:        credential.userIdentifier ?? _extractSub(idToken),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const SocialLoginResult(
          isSuccess:    false,
          errorMessage: '애플 로그인이 취소되었습니다.',
        );
      }
      return SocialLoginResult(isSuccess: false, errorMessage: e.message);
    } catch (e) {
      return SocialLoginResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<void> appleLogout() async {
    // Apple Sign In 은 명시적 logout API 없음 — 로컬 토큰만 폐기.
  }

  String _extractSub(String idToken) {
    final parts = idToken.split('.');
    if (parts.length < 2) return '';
    final payload = parts[1];
    final padded  = payload.padRight((payload.length + 3) & ~3, '=');
    final decoded = utf8.decode(base64Url.decode(padded));
    final json    = Map<String, dynamic>.from(jsonDecode(decoded) as Map);
    return json['sub']?.toString() ?? '';
  }
}
