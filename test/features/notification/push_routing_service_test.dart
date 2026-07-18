import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/features/notification/service/push_routing_service.dart';

void main() {
  group('PushRoutingService.resolvePath', () {
    test('type=A → /capture', () {
      expect(
        PushRoutingService.resolvePath({'type': 'A'}),
        '/capture',
      );
    });

    test('type=a (소문자) → /capture (대소문자 무관)', () {
      expect(
        PushRoutingService.resolvePath({'type': 'a'}),
        '/capture',
      );
    });

    test('type=B + mybookId(int) → /main/book-info/{id}', () {
      expect(
        PushRoutingService.resolvePath({'type': 'B', 'mybookId': 42}),
        '/main/book-info/42',
      );
    });

    test('type=B + mybookId(string) → 동일 (파싱)', () {
      expect(
        PushRoutingService.resolvePath({'type': 'B', 'mybookId': '7'}),
        '/main/book-info/7',
      );
    });

    test('type=B + mybookId 누락 → /main/home (fallback)', () {
      expect(
        PushRoutingService.resolvePath({'type': 'B'}),
        '/main/home',
      );
    });

    test('type=B + mybookId 파싱 실패 → /main/home (fallback)', () {
      expect(
        PushRoutingService.resolvePath({'type': 'B', 'mybookId': 'abc'}),
        '/main/home',
      );
    });

    test('type=C → /main/home', () {
      expect(
        PushRoutingService.resolvePath({'type': 'C'}),
        '/main/home',
      );
    });

    test('알 수 없는 type → /main/home', () {
      expect(
        PushRoutingService.resolvePath({'type': 'X'}),
        '/main/home',
      );
    });

    test('type 누락(빈 payload) → /main/home', () {
      expect(PushRoutingService.resolvePath({}), '/main/home');
    });
  });
}
