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

  test(
    'backdated status overrides current status without changing timeline order',
    () {
      final journal = ReadingJournal([
        record('done', ReadingCategory.done, 4),
      ]).add(record('start', ReadingCategory.inProgress, 1));
      expect(journal.status, ReadingCategory.inProgress);
      expect(journal.newestFirst.map((r) => r.id), ['done', 'start']);
    },
  );

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
      expect(journal.status, ReadingCategory.todo);
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

  test(
    'spines follow page count, use default for missing pages, and stay bounded',
    () {
      expect(bookSpineWidth(128), lessThan(bookSpineWidth(400)));
      expect(bookSpineWidth(null), bookSpineWidth(0));
      expect(bookSpineWidth(-1), 28);
      expect(bookSpineWidth(1), 22);
      expect(bookSpineWidth(10000), 38);
    },
  );
}
