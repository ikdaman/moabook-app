import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moabook/data/datasource/notification_remote_datasource.dart';
import 'package:moabook/data/model/push_settings_model.dart';
import 'package:moabook/data/repository/notification_repository_impl.dart';

class MockNotificationRemoteDataSource extends Mock
    implements NotificationRemoteDataSource {}

void main() {
  late MockNotificationRemoteDataSource remote;
  late NotificationRepositoryImpl repo;

  setUp(() {
    remote = MockNotificationRemoteDataSource();
    repo = NotificationRepositoryImpl(remote);
  });

  test('registerDeviceToken delegates to datasource', () async {
    when(() => remote.registerDeviceToken(any(), any()))
        .thenAnswer((_) async {});

    await repo.registerDeviceToken('t', 'ANDROID');

    verify(() => remote.registerDeviceToken('t', 'ANDROID')).called(1);
  });

  test('getSettings maps model → domain', () async {
    when(() => remote.getSettings())
        .thenAnswer((_) async => const PushSettingsModel(pushEnabled: false));

    final result = await repo.getSettings();

    expect(result.pushEnabled, false);
  });

  test('updateSettings maps model → domain', () async {
    when(() => remote.updateSettings(any()))
        .thenAnswer((_) async => const PushSettingsModel(pushEnabled: true));

    final result = await repo.updateSettings(true);

    expect(result.pushEnabled, true);
  });
}
