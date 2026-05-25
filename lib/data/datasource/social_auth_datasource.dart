import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import '../model/social_login_result.dart';
import '../../core/env/env.dart';

abstract interface class SocialAuthDataSource {
  Future<SocialLoginResult> kakaoLogin();
  Future<SocialLoginResult> naverLogin();
  Future<SocialLoginResult> googleLogin();
  Future<void> kakaoLogout();
  Future<void> naverLogout();
  Future<void> googleLogout();
}

class SocialAuthDataSourceImpl implements SocialAuthDataSource {
  // serverClientId = Web Client ID → Android에서 idToken을 받기 위해 필요.
  // clientId는 iOS 전용 파라미터이므로 Android에서는 효과 없음.
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

  @override
  Future<SocialLoginResult> naverLogin() async {
    try {
      final result = await FlutterNaverLogin.logIn();
      if (result.status == NaverLoginStatus.loggedIn &&
          result.accessToken != null &&
          result.account != null) {
        return SocialLoginResult(
          isSuccess:         true,
          socialAccessToken: result.accessToken!.accessToken,
          provider:          'NAVER',
          providerId:        result.account!.id,
        );
      }
      return SocialLoginResult(
        isSuccess:    false,
        errorMessage: (result.errorMessage?.isNotEmpty == true)
            ? result.errorMessage!
            : '네이버 로그인에 실패했습니다.',
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
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return const SocialLoginResult(
            isSuccess: false, errorMessage: '구글 로그인이 취소되었습니다.');
      }
      final auth    = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        return const SocialLoginResult(
            isSuccess: false, errorMessage: 'ID 토큰을 가져올 수 없습니다.');
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
    try { await _googleSignIn.signOut(); } catch (_) {}
  }

  // JWT payload에서 sub 추출 (Android GoogleAuth.getProviderId 동일 로직)
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
