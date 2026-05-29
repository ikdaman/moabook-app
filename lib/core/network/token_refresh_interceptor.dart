import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_event.dart';

/// 401 응답 → /auth/reissue 로 토큰 갱신 → 원 요청 재시도.
///
/// 동시 401 race condition 차단:
///   1) 처음 401 들어온 인터셉터 instance 가 `_ongoing` Completer 를 세팅하고
///      reissue 호출. 그 동안 추가로 401 이 들어오면 Completer 가 끝날 때까지 대기.
///   2) 대기 끝나면 storage 의 새 access_token 으로 원 요청 재시도 (reissue 재호출 X).
///   3) "다른 누가 이미 갱신했나?" 빠른 경로 — 진입 시 request 가 들어올 때의
///      Authorization 헤더 토큰 vs storage 토큰 비교. 다르면 cache 가 이미 신규로
///      바뀐 것이므로 reissue 생략하고 바로 재시도.
///
/// Android 원본 `TokenAuthenticator.kt:28-77` 의 synchronized 블록 + 토큰 비교
/// 패턴을 Dart 의 `Completer` 로 옮긴 것.
class TokenRefreshInterceptor extends Interceptor {
  final Dio _refreshDio;
  final FlutterSecureStorage _storage;

  /// 진행 중인 reissue. null 이면 idle. true 로 완료되면 성공, false 면 실패(토큰 만료).
  Completer<bool>? _ongoing;

  TokenRefreshInterceptor(this._refreshDio, this._storage);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // (3) 빠른 경로 — 다른 요청 처리 중 이미 reissue 가 끝나 access_token 이 바뀌었으면
    //     reissue 생략하고 그 토큰으로 바로 재시도.
    final requestAuthHeader = err.requestOptions.headers['Authorization']?.toString();
    final storedAccess = await _storage.read(key: 'access_token');
    if (storedAccess != null &&
        requestAuthHeader != null &&
        requestAuthHeader != 'Bearer $storedAccess') {
      try {
        final retried = await _retryWithToken(err.requestOptions, storedAccess);
        return handler.resolve(retried);
      } on DioException catch (e) {
        return handler.next(e);
      }
    }

    // (1) 이미 진행 중이면 끝날 때까지 대기.
    final ongoing = _ongoing;
    if (ongoing != null) {
      final ok = await ongoing.future;
      if (!ok) {
        return handler.next(err);
      }
      final freshAccess = await _storage.read(key: 'access_token');
      if (freshAccess == null) return handler.next(err);
      try {
        final retried = await _retryWithToken(err.requestOptions, freshAccess);
        return handler.resolve(retried);
      } on DioException catch (e) {
        return handler.next(e);
      }
    }

    // (2) 이 인터셉터가 reissue 책임을 진다.
    final completer = Completer<bool>();
    _ongoing = completer;

    try {
      final ok = await _doReissue();
      completer.complete(ok);
      if (!ok) {
        return handler.next(err);
      }
      final newAccess = await _storage.read(key: 'access_token');
      if (newAccess == null) return handler.next(err);
      try {
        final retried = await _retryWithToken(err.requestOptions, newAccess);
        return handler.resolve(retried);
      } on DioException catch (e) {
        return handler.next(e);
      }
    } catch (e) {
      completer.complete(false);
      return handler.next(err);
    } finally {
      _ongoing = null;
    }
  }

  /// 실제 reissue 호출. 성공 시 storage 갱신, true 반환.
  /// 401/403/404 → 토큰 클리어 + auth-expired 이벤트 통지 + false.
  /// 5xx / 네트워크 오류 → 토큰 유지 + false (자동로그인 보존).
  Future<bool> _doReissue() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    final accessToken = await _storage.read(key: 'access_token');
    if (refreshToken == null || accessToken == null) {
      await _clearTokens();
      return false;
    }

    try {
      final response = await _refreshDio.post<dynamic>(
        '/auth/reissue',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'refresh-token': refreshToken,
          },
        ),
      );

      final newAccess = response.headers.value('Authorization');
      final newRefresh = response.headers.value('refresh-token');

      if (newAccess != null && newRefresh != null) {
        await _storage.write(key: 'access_token', value: newAccess);
        await _storage.write(key: 'refresh_token', value: newRefresh);
        return true;
      }
      return false;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403 || code == 404) {
        await _clearTokens();
      }
      // 5xx 는 토큰 유지 (서버 일시 장애 → 자동로그인 보존)
      return false;
    }
  }

  /// 동일 요청을 새 access_token 으로 재시도.
  /// `_refreshDio` 는 인터셉터 미장착이므로 무한루프 위험 없음.
  Future<Response<dynamic>> _retryWithToken(
    RequestOptions original,
    String accessToken,
  ) {
    final retryOptions = original.copyWith(
      headers: {
        ...original.headers,
        'Authorization': 'Bearer $accessToken',
      },
    );
    return _refreshDio.fetch<dynamic>(retryOptions);
  }

  Future<void> _clearTokens() async {
    await _storage.deleteAll();
    notifyAuthExpired();
    if (kDebugMode) debugPrint('TokenRefreshInterceptor: tokens cleared');
  }
}
