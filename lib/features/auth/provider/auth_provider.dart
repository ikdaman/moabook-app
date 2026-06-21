import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/datasource/auth_remote_datasource.dart';
import '../../../data/datasource/social_auth_datasource.dart';
import '../../../data/repository/auth_repository_impl.dart';
import '../../../domain/model/login_state.dart';
import '../../../domain/model/logout_state.dart';
import '../../../domain/model/signup_state.dart';
import '../../../domain/repository/auth_repository.dart';
import '../../book_search/provider/book_search_provider.dart';
import '../../home/screen/pending_book_consumer.dart';
import '../../notification/provider/notification_providers.dart';
import '../../notification/provider/push_settings_provider.dart';
import '../../onboarding/provider/pending_book_provider.dart';

// ── Infrastructure providers ─────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final dioProvider = Provider((ref) {
  final storage = ref.watch(secureStorageProvider);
  return createDioClient(storage);
});

// ── Repository providers ──────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio     = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(
    AuthRemoteDataSourceImpl(dio),
    SocialAuthDataSourceImpl(),
    storage,
  );
});

// ── State providers ───────────────────────────────────────────────────────

final loginStateProvider =
    StateProvider<LoginState>((ref) => const LoginInitial());

final signupStateProvider =
    StateProvider<SignupState>((ref) => const SignupSuccess());

final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.isLoggedIn();
});

// ── Action notifier ───────────────────────────────────────────────────────

class AuthNotifier extends Notifier<void> {
  @override
  void build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _consumeLogin(Stream<LoginState> stream) async {
    await for (final state in stream) {
      // LoginSuccess 가 listener 로 전파되어 /main 으로 navigate 되기 직전에
      // isLoggedInProvider 캐시를 미리 채워둬야 홈/바텀바 첫 build 가
      // 로그인 상태로 그려진다. (invalidate 후 .future 를 await)
      if (state is LoginSuccess) {
        ref.invalidate(isLoggedInProvider);
        await ref.read(isLoggedInProvider.future);
        // 온보딩 보류책을 홈 이동 '전'에 저장 → 홈 도착 시 이미 목록에 보인다.
        await _consumePendingBook();
        // 푸시 동기화는 화면 전환을 막지 않도록 비동기로 분리.
        // FCM/FIS 미가용으로 getToken 이 느리거나 실패해도 로그인은 진행된다.
        unawaited(_syncPushOnLogin());
      }
      ref.read(loginStateProvider.notifier).state = state;
    }
  }

  Future<void> kakaoLogin()  => _consumeLogin(_repo.kakaoLogin());
  Future<void> naverLogin()  => _consumeLogin(_repo.naverLogin());
  Future<void> googleLogin() => _consumeLogin(_repo.googleLogin());
  Future<void> appleLogin()  => _consumeLogin(_repo.appleLogin());

  Future<void> signup({
    required String socialToken,
    required String provider,
    required String providerId,
    required String nickname,
  }) async {
    await for (final state in _repo.signup(
      socialToken: socialToken,
      provider: provider,
      providerId: providerId,
      nickname: nickname,
    )) {
      // 로그인 흐름과 동일하게 SignupSuccess 전파 전에 캐시 갱신.
      if (state is SignupSuccess) {
        ref.invalidate(isLoggedInProvider);
        await ref.read(isLoggedInProvider.future);
        // 온보딩 보류책을 홈 이동 '전'에 저장 → 홈 도착 시 이미 목록에 보인다.
        await _consumePendingBook();
        // 푸시 동기화(device-token 등록 등)는 화면 전환을 막지 않도록 비동기로 분리.
        // FCM/FIS 미가용으로 getToken 이 느리거나 실패해도 로그인 흐름은 진행된다.
        unawaited(_syncPushOnLogin());
      }
      ref.read(signupStateProvider.notifier).state = state;
    }
  }

  /// 온보딩에서 보류한 책을 저장. 로그인/회원가입 성공 직후(홈 이동 전)에
  /// 호출해 홈 첫 진입에서 바로 보이게 한다. 실패해도 로그인 흐름은 막지 않고,
  /// 보류책은 유지되어 Home 첫 진입의 fallback 에서 재시도된다.
  Future<void> _consumePendingBook() async {
    final pending = ref.read(pendingBookProvider);
    if (pending == null) return;
    try {
      final ok = await consumePendingBook(
        pending: pending,
        saver: ref.read(bookSearchProvider.notifier),
      );
      if (ok) ref.read(pendingBookProvider.notifier).state = null;
    } catch (e) {
      debugPrint('보류책 저장 실패(흡수): $e');
    }
  }

  /// 로그인/회원가입 성공 직후 — 인증된 상태로 device-token 재등록 + (설정 ON 시) C 예약.
  Future<void> _syncPushOnLogin() async {
    try {
      await ref.read(fcmServiceProvider).resendToken();
      if (await readLocalPushEnabled()) {
        await ref.read(localNotificationServiceProvider).rescheduleC();
      }
    } catch (e) {
      debugPrint('push 로그인 동기화 실패(흡수): $e');
    }
  }

  /// 로그아웃 직전 — 백엔드 device-token 해제 + FCM 토큰 폐기 + 로컬 알림 전부 취소.
  Future<void> _cleanupPushOnLogout() async {
    try {
      final fcm = ref.read(fcmServiceProvider);
      final token = fcm.currentToken;
      if (token != null) {
        try {
          await ref
              .read(notificationRepositoryProvider)
              .unregisterDeviceToken(token);
        } catch (e) {
          debugPrint('device-token 해제 실패(흡수): $e');
        }
      }
      await fcm.deleteToken();
      await ref.read(localNotificationServiceProvider).cancelAll();
    } catch (e) {
      debugPrint('push 로그아웃 정리 실패(흡수): $e');
    }
  }

  Future<void> logout() async {
    await _cleanupPushOnLogout();
    final provider = await _repo.getProvider();
    final stream = switch (provider?.toUpperCase()) {
      'KAKAO'  => _repo.kakaoLogout(),
      'NAVER'  => _repo.naverLogout(),
      'GOOGLE' => _repo.googleLogout(),
      'APPLE'  => _repo.appleLogout(),
      _        => _repo.kakaoLogout(),
    };
    await for (final state in stream) {
      if (state is LogoutError) break;
    }
    ref.invalidate(isLoggedInProvider);
    ref.read(loginStateProvider.notifier).state = const LoginInitial();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, void>(AuthNotifier.new);
