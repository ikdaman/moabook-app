import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/cover_ocr/service/cover_ocr_search.dart';

BookItem _book(int id, String title) => BookItem(
      title: title,
      author: '',
      cover: '',
      publisher: '',
      isbn: '',
      itemId: id,
      link: '',
      description: '',
      pubDate: '',
    );

void main() {
  group('buildOcrQueries', () {
    test('원문을 그대로 쿼리에 포함한다', () {
      final q = buildOcrQueries(['그릿']);
      expect(q, contains('그릿'));
    });

    test('괄호 안 부가정보(저자)를 제거한 변형을 만든다', () {
      // img2: "여름(김애란)" → "여름" 도 검색 대상이어야 함
      final q = buildOcrQueries(['여름(김애란)']);
      expect(q, contains('여름(김애란)'));
      expect(q, contains('여름'));
    });

    test('선행 장식기호 + 괄호 저자/부제를 제거한다', () {
      // img8: "-모순(양귀자/소설)" → "모순"
      final q = buildOcrQueries(['-모순(양귀자/소설)']);
      expect(q, contains('모순'));
    });

    test('상위 candidateCount개 후보만 사용한다', () {
      final texts = List.generate(10, (i) => '후보$i');
      final q = buildOcrQueries(texts, candidateCount: 5);
      expect(q, contains('후보0'));
      expect(q, contains('후보4'));
      expect(q, isNot(contains('후보5')));
    });

    test('실제 제목이 4위여도 top5 안이면 포함된다', () {
      // img2 실제 OCR 후보 순서(상위 5) — "바깥은 여름"이 4위
      final texts = [
        '한국 소설붙은온!',
        '여름(김애란)',
        'horts',
        '바깥은 여름',
        '지금 풀매수구그 한국 소설 3권',
      ];
      final q = buildOcrQueries(texts);
      expect(q, contains('바깥은 여름'));
    });

    test('중복 쿼리를 제거한다', () {
      final q = buildOcrQueries(['모순', '모순']);
      expect(q.where((e) => e == '모순').length, 1);
    });

    test('maxQueries 상한을 넘지 않는다', () {
      final texts = List.generate(5, (i) => '제목$i(저자$i)');
      final q = buildOcrQueries(texts, queryLimit: 4);
      expect(q.length, lessThanOrEqualTo(4));
    });

    test('2자 미만 후보는 무시한다', () {
      final q = buildOcrQueries(['하', 'A', '그릿']);
      expect(q, isNot(contains('하')));
      expect(q, isNot(contains('A')));
      expect(q, contains('그릿'));
    });

    test('정제 결과가 원문과 같으면 변형을 추가하지 않는다', () {
      final q = buildOcrQueries(['눈물을 마시는 새']);
      expect(q.length, 1);
    });
  });

  group('mergeCoverSearchResults', () {
    test('라운드로빈 — 각 쿼리의 1위끼리 먼저 배치한다', () {
      // 쿼리A(잡탕)=[1,2,3], 쿼리B(정답)=[10,11]
      // concat이면 정답10이 4번째로 밀리지만, 라운드로빈이면 2번째.
      final merged = mergeCoverSearchResults([
        [_book(1, 'junkA1'), _book(2, 'junkA2'), _book(3, 'junkA3')],
        [_book(10, '정답'), _book(11, '정답시리즈')],
      ]);
      expect(merged[0].itemId, 1);
      expect(merged[1].itemId, 10); // 정답이 2번째로 상단 노출
    });

    test('itemId 기준 중복 제거', () {
      final merged = mergeCoverSearchResults([
        [_book(1, 'a'), _book(2, 'b')],
        [_book(2, 'b-dup'), _book(3, 'c')],
      ]);
      expect(merged.map((e) => e.itemId), [1, 2, 3]);
    });

    test('빈 리스트가 섞여도 안전하다', () {
      final merged = mergeCoverSearchResults([
        [],
        [_book(5, 'x')],
        [],
      ]);
      expect(merged.map((e) => e.itemId), [5]);
    });

    test('전부 비면 빈 결과', () {
      expect(mergeCoverSearchResults([[], []]), isEmpty);
    });
  });
}
