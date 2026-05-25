import 'dart:async';

final _authExpiredController = StreamController<void>.broadcast();

/// 토큰 갱신 실패 시 방송 — 리스너는 /login으로 강제 이동.
Stream<void> get authExpiredStream => _authExpiredController.stream;

void notifyAuthExpired() {
  if (!_authExpiredController.isClosed) _authExpiredController.add(null);
}
