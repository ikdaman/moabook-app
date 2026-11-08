import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/core/network/auth_event.dart';
import 'package:moabook/core/network/auth_interceptor.dart';
import 'package:moabook/core/network/dio_client.dart';
import 'package:moabook/core/network/token_refresh_interceptor.dart';

class RefreshServer implements HttpClientAdapter {
  int refreshCalls = 0;
  int refreshStatus = 200;
  Completer<void>? gate;
  final seenHeaders = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    var status = 200;
    Map<String, List<String>> headers = {
      Headers.contentTypeHeader: ['application/json'],
    };
    if (options.path == '/auth/reissue') {
      refreshCalls++;
      await gate?.future;
      status = refreshStatus;
      if (status == 200) {
        headers['Authorization'] = ['fresh-access'];
        headers['refresh-token'] = ['fresh-refresh'];
      }
    } else {
      final auth = options.headers['Authorization'].toString();
      seenHeaders.add(auth);
      status = auth == 'Bearer fresh-access' ? 200 : 401;
    }
    return ResponseBody.fromString(
      jsonEncode({'ok': status == 200}),
      status,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  late Dio dio;
  late Dio refresh;
  late RefreshServer server;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'expired-access',
      'refresh_token': 'old-refresh',
    });
    server = RefreshServer();
    refresh = Dio(BaseOptions(baseUrl: 'https://unit.test'))
      ..httpClientAdapter = server;
    dio = Dio(BaseOptions(baseUrl: 'https://unit.test'))
      ..httpClientAdapter = server;
    dio.interceptors.addAll([
      AuthInterceptor(storage),
      TokenRefreshInterceptor(refresh, storage),
    ]);
  });
  tearDown(() {
    dio.close(force: true);
    refresh.close(force: true);
  });

  test('application client does not install a request or response logger', () {
    final client = createDioClient(storage);
    expect(client.interceptors.whereType<LogInterceptor>(), isEmpty);
    client.close(force: true);
  });

  test(
    'concurrent expired requests share one refresh and retry with the new token',
    () async {
      server.gate = Completer<void>();
      final requests = Future.wait([
        dio.get<Object?>('/mybooks'),
        dio.get<Object?>('/collections'),
      ]);
      for (var i = 0; i < 50 && server.refreshCalls == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(server.refreshCalls, 1);
      server.gate!.complete();
      final responses = await requests;
      expect(responses.map((r) => r.statusCode), [200, 200]);
      expect(server.refreshCalls, 1);
      expect(
        server.seenHeaders.where((v) => v == 'Bearer fresh-access').length,
        2,
      );
      expect(await storage.read(key: 'access_token'), 'fresh-access');
      expect(await storage.read(key: 'refresh_token'), 'fresh-refresh');
    },
  );

  test(
    'temporary refresh failure keeps the existing login credentials',
    () async {
      server.refreshStatus = 500;
      await expectLater(
        dio.get<Object?>('/mybooks'),
        throwsA(isA<DioException>()),
      );
      expect(server.refreshCalls, 1);
      expect(await storage.read(key: 'access_token'), 'expired-access');
      expect(await storage.read(key: 'refresh_token'), 'old-refresh');
    },
  );

  test(
    'rejected refresh clears credentials and emits the login-expired event',
    () async {
      server.refreshStatus = 401;
      var events = 0;
      final subscription = authExpiredStream.listen((_) => events++);
      addTearDown(subscription.cancel);
      await expectLater(
        dio.get<Object?>('/mybooks'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await storage.read(key: 'access_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), isNull);
      expect(events, 1);
    },
  );
}
