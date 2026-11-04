import 'package:characters/characters.dart';

export 'reading_gateway.dart';

enum ReadingCategory {
  inProgress('INPROGRESS', '읽는 중', '독서 상태'),
  todo('TODO', '읽고 싶은 책', '독서 상태'),
  done('DONE', '다 읽은 책', '독서 상태'),
  buy('BUY', '구매', '책 수령'),
  lend('LEND', '도서관 대출', '책 수령'),
  gift('GIFT', '선물 받음', '책 수령'),
  ebook('EBOOK', '이북', '책 수령'),
  sentence('SENTENCE', '마음에 든 문장', '순간 기록'),
  talk('TALK', '누구랑 얘기함', '순간 기록'),
  remind('REMIND', '다시 떠오름', '순간 기록'),
  present('PRESENT', '선물함', '순간 기록'),
  borrow('BORROW', '빌려줌', '순간 기록'),
  reread('REREAD', '또 만남', '순간 기록'),
  free('FREE', '자유 기록', '');

  const ReadingCategory(this.code, this.label, this.group);
  final String code;
  final String label;
  final String group;
  bool get changesStatus => group == '독서 상태';
}

/// Calendar date, without assuming a server timezone conversion contract.
DateTime readingDay(DateTime date) => DateTime(date.year, date.month, date.day);

class ReadingRecord {
  ReadingRecord({
    required this.id,
    required this.category,
    required DateTime date,
    required this.memo,
  }) : date = readingDay(date) {
    if (memo.characters.length > 400) {
      throw ArgumentError('내용은 400자까지 입력할 수 있어요.');
    }
    if (category == ReadingCategory.free && memo.trim().isEmpty) {
      throw ArgumentError('자유 기록에는 내용을 입력해주세요.');
    }
  }
  final String id;
  final ReadingCategory category;
  final DateTime date;
  final String memo;
}

/// Records are held in successful creation order, independent of their dates.
/// Server adapters must preserve that order; display order must not infer status.
class ReadingJournal {
  ReadingJournal([Iterable<ReadingRecord> records = const []])
    : records = List.unmodifiable(records);
  final List<ReadingRecord> records;

  ReadingCategory? get status {
    for (final record in records.reversed) {
      if (record.category.changesStatus) return record.category;
    }
    return null;
  }

  /// Band policy remains date based, independently of last-added status.
  String? get reason {
    for (final record in newestFirst) {
      if (record.category == ReadingCategory.todo) {
        return record.memo.trim().isEmpty ? null : record.memo;
      }
    }
    return null;
  }

  List<ReadingRecord> get newestFirst {
    final indexed = records.indexed.toList()
      ..sort((a, b) {
        final byDate = b.$2.date.compareTo(a.$2.date);
        return byDate == 0 ? b.$1.compareTo(a.$1) : byDate;
      });
    return List.unmodifiable(indexed.map((entry) => entry.$2));
  }

  ReadingJournal add(ReadingRecord record) {
    if (records.any((existing) => existing.id == record.id)) {
      throw ArgumentError('이미 추가된 기록입니다.');
    }
    return ReadingJournal([...records, record]);
  }
}

class ReadingCollection {
  ReadingCollection({
    required this.id,
    required String name,
    Iterable<String?>? slots,
  }) : name = name.trim(),
       slots = List.unmodifiable(slots ?? List<String?>.filled(9, null)) {
    if (this.name.isEmpty) throw ArgumentError('컬렉션 이름을 입력해주세요.');
    if (this.slots.length != 9) throw ArgumentError('컬렉션은 9칸입니다.');
    final books = this.slots.whereType<String>().toList();
    if (books.any((id) => id.isEmpty) || books.toSet().length != books.length) {
      throw ArgumentError('같은 컬렉션에는 같은 책을 한 번만 담을 수 있어요.');
    }
  }
  final String id;
  final String name;
  final List<String?> slots;
  bool get isFull => !slots.contains(null);
  bool contains(String bookId) => slots.contains(bookId);

  ReadingCollection rename(String name) =>
      ReadingCollection(id: id, name: name, slots: slots);

  ReadingCollection add(String bookId) {
    if (contains(bookId)) throw StateError('이미 이 컬렉션에 담긴 책이에요.');
    final index = slots.indexOf(null);
    if (index < 0) throw StateError('컬렉션에는 9권까지 담을 수 있어요.');
    final updated = slots.toList()..[index] = bookId;
    return ReadingCollection(id: id, name: name, slots: updated);
  }

  ReadingCollection removeAt(int index) {
    final updated = slots.toList()..[index] = null;
    return ReadingCollection(id: id, name: name, slots: updated);
  }
}

/// Bounded widths preserve usable touch targets and three shelf rows.
double bookSpineWidth(int? totalPages) => totalPages == null || totalPages <= 0
    ? 28
    : (22 + (totalPages - 100) * .04).clamp(22, 38).toDouble();
