import '../../../domain/model/book_item.dart';
import '../../onboarding/provider/pending_book_provider.dart';

/// saveBook 만 추상화해 테스트 가능하게 한 인터페이스.
/// BookSearchNotifier 가 이를 만족한다(saveBook 시그니처 동일).
abstract class PendingSaver {
  Future<bool> saveBook({
    required BookItem book,
    String? reason,
    String? startedDate,
    String? finishedDate,
  });
}

/// 보류책이 있으면 저장하고 성공 여부 반환. 없으면 false.
Future<bool> consumePendingBook({
  required PendingBook? pending,
  required PendingSaver saver,
}) async {
  if (pending == null) return false;
  return saver.saveBook(book: pending.book, reason: pending.reason);
}
