import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/model/book_item.dart';

/// 온보딩에서 고른 책을 로그인 완료 전까지 임시 보관.
class PendingBook {
  final BookItem book;
  final String? reason;
  const PendingBook({required this.book, this.reason});
}

/// 인메모리 보류책. 로그인 후 Home 첫 진입에서 소비 후 null 로 클리어.
final pendingBookProvider = StateProvider<PendingBook?>((ref) => null);
