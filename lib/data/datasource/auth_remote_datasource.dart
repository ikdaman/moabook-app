import 'package:dio/dio.dart';
import '../model/login_result.dart';

abstract interface class AuthRemoteDataSource {
  Future<(LoginResult?, int?)> login({
    required String socialToken,
    required String provider,
    required String providerId,
  });

  Future<LoginResult?> signup({
    required String socialToken,
    required String provider,
    required String providerId,
    required String nickname,
  });

  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSourceImpl(this._dio);

  @override
  Future<(LoginResult?, int?)> login({
    required String socialToken,
    required String provider,
    required String providerId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'provider': provider, 'providerId': providerId},
      options: Options(headers: {'social-token': socialToken}),
    );

    final authorization = response.headers.value('Authorization');
    final refreshToken  = response.headers.value('refresh-token');
    final nickname = (response.data?['nickname'] as String?) ?? '';

    if (authorization == null || refreshToken == null) return (null, null);

    return (
      LoginResult(
        provider:      provider,
        authorization: authorization,
        refreshToken:  refreshToken,
        nickname:      nickname,
      ),
      response.statusCode,
    );
  }

  @override
  Future<LoginResult?> signup({
    required String socialToken,
    required String provider,
    required String providerId,
    required String nickname,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/signup',
      data: {
        'provider':   provider,
        'providerId': providerId,
        'nickname':   nickname,
      },
      options: Options(headers: {'social-token': socialToken}),
    );

    final authorization   = response.headers.value('Authorization');
    final newRefreshToken = response.headers.value('refresh-token');
    final newNickname = (response.data?['nickname'] as String?) ?? nickname;

    if (authorization == null || newRefreshToken == null) return null;

    return LoginResult(
      provider:      provider,
      authorization: authorization,
      refreshToken:  newRefreshToken,
      nickname:      newNickname,
    );
  }

  @override
  Future<void> logout() async {
    await _dio.delete<void>('/auth/logout');
  }
}
