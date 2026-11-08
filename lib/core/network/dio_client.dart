import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../env/env.dart';
import 'auth_interceptor.dart';
import 'token_refresh_interceptor.dart';

Dio createDioClient(FlutterSecureStorage storage) {
  final refreshDio = Dio(BaseOptions(baseUrl: Env.baseUrl));

  final dio = Dio(
    BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(storage),
    TokenRefreshInterceptor(refreshDio, storage),
  ]);

  return dio;
}
