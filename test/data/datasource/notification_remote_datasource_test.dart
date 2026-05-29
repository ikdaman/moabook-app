import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moabook/data/datasource/notification_remote_datasource.dart';

class MockDio extends Mock implements Dio {}

Response<T> _resp<T>(T data, {int status = 200}) => Response<T>(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: status,
    );

void main() {
  late MockDio dio;
  late NotificationRemoteDataSource ds;

  setUp(() {
    dio = MockDio();
    ds = NotificationRemoteDataSource(dio);
  });

  group('registerDeviceToken', () {
    test('POST /notifications/device-token with fcmToken + platform', () async {
      when(() => dio.post<void>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp<void>(null));

      await ds.registerDeviceToken('tok-123', 'IOS');

      verify(() => dio.post<void>(
            '/notifications/device-token',
            data: {'fcmToken': 'tok-123', 'platform': 'IOS'},
          )).called(1);
    });
  });

  group('unregisterDeviceToken', () {
    test('DELETE /notifications/device-token with fcmToken', () async {
      when(() => dio.delete<void>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp<void>(null, status: 204));

      await ds.unregisterDeviceToken('tok-123');

      verify(() => dio.delete<void>(
            '/notifications/device-token',
            data: {'fcmToken': 'tok-123'},
          )).called(1);
    });
  });

  group('getSettings', () {
    test('GET /notifications/settings → pushEnabled', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => _resp(<String, dynamic>{'pushEnabled': false}));

      final result = await ds.getSettings();

      expect(result.pushEnabled, false);
      verify(() => dio.get<Map<String, dynamic>>('/notifications/settings'))
          .called(1);
    });

    test('응답 누락 시 기본 true', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => _resp(<String, dynamic>{}));

      final result = await ds.getSettings();

      expect(result.pushEnabled, true);
    });
  });

  group('updateSettings', () {
    test('PATCH /notifications/settings with pushEnabled', () async {
      when(() => dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _resp(<String, dynamic>{'pushEnabled': true}));

      final result = await ds.updateSettings(true);

      expect(result.pushEnabled, true);
      verify(() => dio.patch<Map<String, dynamic>>(
            '/notifications/settings',
            data: {'pushEnabled': true},
          )).called(1);
    });
  });
}
