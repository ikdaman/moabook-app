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
    this.createdAt,
    this.creationOrder,
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
  final DateTime? createdAt;
  final int? creationOrder;
}

/// Status follows the latest record date; creation order breaks same-day ties.
class ReadingJournal {
  ReadingJournal([Iterable<ReadingRecord> records = const []])
    : records = List.unmodifiable(records);
  final List<ReadingRecord> records;

  ReadingCategory? get status {
    for (final record in newestFirst) {
      if (record.category.changesStatus) return record.category;
    }
    return null;
  }

  /// The most recently dated TODO supplies the band, including an empty reason.
  String? get reason {
    for (final record in newestFirst) {
      if (record.category == ReadingCategory.todo) {
        return record.memo.trim().isEmpty ? null : record.memo;
      }
    }
    return null;
  }

  List<ReadingRecord> get newestFirst {
    final hasCreationDates = records.every(
      (record) => record.createdAt != null,
    );
    final indexed = records.indexed.toList()
      ..sort((a, b) {
        final byDate = b.$2.date.compareTo(a.$2.date);
        if (byDate != 0) return byDate;
        final aCreated = a.$2.createdAt, bCreated = b.$2.createdAt;
        if (hasCreationDates && aCreated != null && bCreated != null) {
          final byCreation = bCreated.compareTo(aCreated);
          if (byCreation != 0) return byCreation;
        }
        final aOrder = a.$2.creationOrder ?? a.$1;
        final bOrder = b.$2.creationOrder ?? b.$1;
        return bOrder.compareTo(aOrder);
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

  ReadingCollection add(String bookId, {int? slotIndex}) {
    if (contains(bookId)) throw StateError('이미 이 컬렉션에 담긴 책이에요.');
    final index = slotIndex ?? slots.indexOf(null);
    if (index < 0) throw StateError('컬렉션에는 9권까지 담을 수 있어요.');
    RangeError.checkValidIndex(index, slots, 'slotIndex');
    if (slots[index] != null) throw StateError('선택한 칸에 이미 책이 있어요.');
    final updated = slots.toList()..[index] = bookId;
    return ReadingCollection(id: id, name: name, slots: updated);
  }

  ReadingCollection removeAt(int index) {
    final updated = slots.toList()..[index] = null;
    return ReadingCollection(id: id, name: name, slots: updated);
  }
}

/// Page count sets thickness without an upper cap; unknown counts use a default.
double bookSpineWidth(int? totalPages) {
  if (totalPages == null || totalPages <= 0) return 28;
  final width = 22 + (totalPages - 100) * .04;
  return width < 22 ? 22 : width;
}
