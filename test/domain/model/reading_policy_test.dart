import 'package:flutter_test/flutter_test.dart';
import 'package:moabook_reading/moabook_reading.dart';

void main() {
  ReadingRecord record(
    String id,
    ReadingCategory category,
    int day, [
    String memo = '',
  ]) => ReadingRecord(
    id: id,
    category: category,
    date: DateTime(2026, 11, day),
    memo: memo,
  );

  test('backdated status cannot override the latest dated status', () {
    final journal = ReadingJournal([
      record('done', ReadingCategory.done, 4),
    ]).add(record('start', ReadingCategory.inProgress, 1));
    expect(journal.status, ReadingCategory.done);
    expect(journal.newestFirst.map((r) => r.id), ['done', 'start']);
  });

  test('same-day status uses creation order rather than response order', () {
    final journal = ReadingJournal([
      ReadingRecord(
        id: '20',
        category: ReadingCategory.done,
        date: DateTime(2026, 11, 2),
        memo: '',
        creationOrder: 20,
      ),
      ReadingRecord(
        id: '10',
        category: ReadingCategory.inProgress,
        date: DateTime(2026, 11, 2),
        memo: '',
        creationOrder: 10,
      ),
      ReadingRecord(
        id: '30',
        category: ReadingCategory.todo,
        date: DateTime(2026, 11, 1),
        memo: '',
        creationOrder: 30,
      ),
    ]);
    expect(journal.status, ReadingCategory.done);
    expect(journal.newestFirst.map((record) => record.id), ['20', '10', '30']);
    final dated = ReadingJournal([
      ReadingRecord(
        id: '1',
        category: ReadingCategory.inProgress,
        date: DateTime(2026, 11, 2),
        memo: '',
        createdAt: DateTime(2026, 11, 3, 12),
      ),
      ReadingRecord(
        id: '2',
        category: ReadingCategory.done,
        date: DateTime(2026, 11, 2),
        memo: '',
        createdAt: DateTime(2026, 11, 3, 10),
      ),
    ]);
    expect(dated.status, ReadingCategory.inProgress);
  });

  test('non-status records never override the last status', () {
    var journal = ReadingJournal([record('done', ReadingCategory.done, 1)]);
    for (final category in ReadingCategory.values.where(
      (c) => !c.changesStatus,
    )) {
      journal = journal.add(record(category.code, category, 5, '내용'));
      expect(journal.status, ReadingCategory.done);
    }
  });

  test(
    'same-date state follows insertion order, band follows latest TODO date',
    () {
      final journal = ReadingJournal([
        record('new-reason', ReadingCategory.todo, 4, '최근 이유'),
        record('done', ReadingCategory.done, 4),
        record('old-reason', ReadingCategory.todo, 1, '과거 이유'),
      ]);
      expect(journal.status, ReadingCategory.done);
      expect(journal.reason, '최근 이유');
      expect(journal.newestFirst.map((r) => r.id), [
        'done',
        'new-reason',
        'old-reason',
      ]);
    },
  );

  test(
    'an empty latest TODO hides the band instead of using an older reason',
    () {
      final journal = ReadingJournal([
        record('old', ReadingCategory.todo, 1, '이전 이유'),
        record('new', ReadingCategory.todo, 4),
      ]);
      expect(journal.reason, isNull);
    },
  );

  test(
    'FREE rejects blank content and the limit counts visible characters',
    () {
      expect(
        () => record('blank', ReadingCategory.free, 1, '  \n '),
        throwsArgumentError,
      );
      final emoji = List.filled(400, '👨‍👩‍👧‍👦').join();
      expect(record('emoji', ReadingCategory.free, 1, emoji).memo, emoji);
      expect(
        () => record('long', ReadingCategory.free, 1, '$emoji!'),
        throwsArgumentError,
      );
      expect(record('optional', ReadingCategory.buy, 1).memo, isEmpty);
    },
  );

  test(
    'removal preserves other slots and next book uses the first empty slot',
    () {
      final original = ReadingCollection(
        id: 'c',
        name: '모음',
        slots: ['a', 'b', 'c', null, null, null, null, null, null],
      );
      final updated = original.removeAt(1).add('d');
      expect(updated.slots, [
        'a',
        'd',
        'c',
        null,
        null,
        null,
        null,
        null,
        null,
      ]);
      expect(original.slots[1], 'b');
      expect(() => updated.slots[0] = 'x', throwsUnsupportedError);
    },
  );

  test(
    'adding to a selected slot preserves earlier gaps and occupied slots',
    () {
      final original = ReadingCollection(
        id: 'c',
        name: '모음',
      ).add('a', slotIndex: 2);
      final updated = original.add('b', slotIndex: 8);
      expect(updated.slots, [
        null,
        null,
        'a',
        null,
        null,
        null,
        null,
        null,
        'b',
      ]);
      expect(() => updated.add('c', slotIndex: 8), throwsStateError);
      expect(() => updated.add('c', slotIndex: 9), throwsRangeError);
      expect(original.slots[8], isNull);
    },
  );

  test(
    'duplicate and full collection reject additions; another collection accepts same book',
    () {
      var collection = ReadingCollection(id: 'one', name: '하나');
      for (var i = 0; i < 9; i++) {
        collection = collection.add('book-$i');
      }
      expect(collection.isFull, isTrue);
      expect(() => collection.add('book-0'), throwsStateError);
      expect(() => collection.add('extra'), throwsStateError);
      expect(
        ReadingCollection(id: 'two', name: '둘').add('book-0').slots.first,
        'book-0',
      );
      expect(collection.rename('바뀐 이름').slots, collection.slots);
      expect(() => collection.rename('  '), throwsArgumentError);
    },
  );

  test('spines keep increasing beyond 500 pages without an upper cap', () {
    expect(bookSpineWidth(128), lessThan(bookSpineWidth(400)));
    expect(bookSpineWidth(null), bookSpineWidth(0));
    expect(bookSpineWidth(-1), 28);
    expect(bookSpineWidth(1), 22);
    expect(bookSpineWidth(1000), greaterThan(bookSpineWidth(500)));
    expect(bookSpineWidth(10000), 418);
  });
}
