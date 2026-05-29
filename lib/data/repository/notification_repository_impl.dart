import '../../domain/model/push_settings.dart';
import '../../domain/repository/notification_repository.dart';
import '../datasource/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remote;

  const NotificationRepositoryImpl(this._remote);

  @override
  Future<void> registerDeviceToken(String fcmToken, String platform) =>
      _remote.registerDeviceToken(fcmToken, platform);

  @override
  Future<void> unregisterDeviceToken(String fcmToken) =>
      _remote.unregisterDeviceToken(fcmToken);

  @override
  Future<PushSettings> getSettings() async {
    final model = await _remote.getSettings();
    return model.toDomain();
  }

  @override
  Future<PushSettings> updateSettings(bool enabled) async {
    final model = await _remote.updateSettings(enabled);
    return model.toDomain();
  }
}
