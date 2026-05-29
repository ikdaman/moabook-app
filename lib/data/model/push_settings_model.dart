import '../../domain/model/push_settings.dart';

/// `GET/PATCH /notifications/settings` 응답 DTO.
///
/// 응답 형태: `{ "pushEnabled": true }`
class PushSettingsModel {
  final bool pushEnabled;

  const PushSettingsModel({required this.pushEnabled});

  factory PushSettingsModel.fromJson(Map<String, dynamic> json) =>
      PushSettingsModel(pushEnabled: json['pushEnabled'] as bool? ?? true);

  PushSettings toDomain() => PushSettings(pushEnabled: pushEnabled);
}
