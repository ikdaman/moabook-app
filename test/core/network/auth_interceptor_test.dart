import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moabook/core/network/auth_interceptor.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class FakeRequestInterceptorHandler extends Fake
    implements RequestInterceptorHandler {
  RequestOptions? captured;

  @override
  void next(RequestOptions options) => captured = options;
}

void main() {
  late MockFlutterSecureStorage storage;
  late AuthInterceptor interceptor;

  setUp(() {
    storage = MockFlutterSecureStorage();
    interceptor = AuthInterceptor(storage);
  });

  test('adds Bearer token when access_token exists', () async {
    when(() => storage.read(key: 'access_token'))
        .thenAnswer((_) async => 'test_token_123');

    final handler = FakeRequestInterceptorHandler();
    await interceptor.onRequest(RequestOptions(path: '/test'), handler);

    expect(handler.captured!.headers['Authorization'], 'Bearer test_token_123');
  });

  test('does not add header when no token', () async {
    when(() => storage.read(key: 'access_token'))
        .thenAnswer((_) async => null);

    final handler = FakeRequestInterceptorHandler();
    await interceptor.onRequest(RequestOptions(path: '/test'), handler);

    expect(handler.captured!.headers.containsKey('Authorization'), isFalse);
  });
}
