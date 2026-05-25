import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_event.dart';

class TokenRefreshInterceptor extends Interceptor {
  final Dio _refreshDio;
  final FlutterSecureStorage _storage;

  TokenRefreshInterceptor(this._refreshDio, this._storage);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final refreshToken = await _storage.read(key: 'refresh_token');
    final accessToken  = await _storage.read(key: 'access_token');
    if (refreshToken == null || accessToken == null) {
      await _clearTokens();
      return handler.next(err);
    }

    try {
      final response = await _refreshDio.post<dynamic>(
        '/members/reissue',
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          'refresh-token': refreshToken,
        }),
      );

      final newAccess  = response.headers.value('Authorization');
      final newRefresh = response.headers.value('refresh-token');

      if (newAccess != null && newRefresh != null) {
        await _storage.write(key: 'access_token',  value: newAccess);
        await _storage.write(key: 'refresh_token', value: newRefresh);
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retryResponse = await _refreshDio.fetch<dynamic>(retryOptions);
        return handler.resolve(retryResponse);
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403 || code == 404) {
        await _clearTokens();
      }
      // 5xx 는 토큰 유지 (서버 일시 장애 → 자동로그인 보존)
    }
    handler.next(err);
  }

  Future<void> _clearTokens() async {
    await _storage.deleteAll();
    notifyAuthExpired();
  }
}
