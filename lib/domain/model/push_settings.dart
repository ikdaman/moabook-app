/// 푸시 알림 설정 도메인 모델.
///
/// 백엔드 `GET/PATCH /notifications/settings` 의 `pushEnabled` 와 1:1.
class PushSettings {
  final bool pushEnabled;

  const PushSettings({required this.pushEnabled});

  PushSettings copyWith({bool? pushEnabled}) =>
      PushSettings(pushEnabled: pushEnabled ?? this.pushEnabled);
}
