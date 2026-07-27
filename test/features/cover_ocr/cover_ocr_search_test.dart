import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/book_item.dart';
import 'package:moabook/features/cover_ocr/service/book_cover_ocr.dart'
    show OcrLineBox, combineAdjacentTitleLines, isOcrNoiseLine;
import 'package:moabook/features/cover_ocr/service/cover_ocr_search.dart';

extension on List<OcrQuery> {
  List<String> get texts => map((e) => e.text).toList();
}

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
      expect(q.texts, contains('그릿'));
    });

    test('괄호 안 부가정보(저자)를 제거한 변형을 만든다', () {
      // img2: "여름(김애란)" → "여름" 도 검색 대상이어야 함
      final q = buildOcrQueries(['여름(김애란)']);
      expect(q.texts, contains('여름(김애란)'));
      expect(q.texts, contains('여름'));
    });

    test('선행 장식기호 + 괄호 저자/부제를 제거한다', () {
      // img8: "-모순(양귀자/소설)" → "모순"
      final q = buildOcrQueries(['-모순(양귀자/소설)']);
      expect(q.texts, contains('모순'));
    });

    test('상위 candidateCount개 후보만 사용한다', () {
      final texts = List.generate(10, (i) => '후보$i');
      final q = buildOcrQueries(texts, candidateCount: 5);
      expect(q.texts, contains('후보0'));
      expect(q.texts, contains('후보4'));
      expect(q.texts, isNot(contains('후보5')));
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
      expect(q.texts, contains('바깥은 여름'));
    });

    test('중복 쿼리를 제거한다', () {
      final q = buildOcrQueries(['모순', '모순']);
      expect(q.texts.where((e) => e == '모순').length, 1);
    });

    test('maxQueries 상한을 넘지 않는다', () {
      final texts = List.generate(5, (i) => '제목$i(저자$i)');
      final q = buildOcrQueries(texts, queryLimit: 4);
      expect(q.length, lessThanOrEqualTo(4));
    });

    test('2자 미만 후보는 무시한다', () {
      final q = buildOcrQueries(['하', 'A', '그릿']);
      expect(q.texts, isNot(contains('하')));
      expect(q.texts, isNot(contains('A')));
      expect(q.texts, contains('그릿'));
    });

    test('정제 결과가 원문과 같으면 변형을 추가하지 않는다', () {
      final q = buildOcrQueries(['눈물을 마시는 새']);
      expect(q.length, 1);
    });
  });

  group('작가명 결합 검색', () {
    test('"지음" 라인에서 작가 추출 → 제목+작가 Keyword 쿼리를 최우선 배치', () {
      final q = buildOcrQueries(['아몬드', '손원평 지음']);
      expect(q.first.text, '아몬드 손원평');
      expect(q.first.byKeyword, isTrue);
    });

    test('"지음" 라인은 단독 제목 쿼리로 쓰지 않는다', () {
      final q = buildOcrQueries(['아몬드', '손원평 지음']);
      expect(q.texts, isNot(contains('손원평 지음')));
    });

    test('"장편소설" 라인은 작가 추출하되 제목 쿼리로도 유지한다', () {
      final q = buildOcrQueries(['불편한 편의점', '김호연 장편소설']);
      expect(q.first.text, '불편한 편의점 김호연');
      expect(q.first.byKeyword, isTrue);
      expect(q.texts, contains('김호연 장편소설'));
    });

    test('작가 라인이 없으면 Keyword 쿼리도 없다', () {
      final q = buildOcrQueries(['그릿']);
      expect(q.any((e) => e.byKeyword), isFalse);
    });

    test('공백 포함 외국 작가 이름도 추출한다', () {
      final q = buildOcrQueries(['개미', '베르나르 베르베르 지음']);
      expect(q.first.text, '개미 베르나르 베르베르');
    });

    test('제목 후보의 정제 변형과 작가를 결합한다', () {
      // 괄호 부가정보가 붙은 제목이라도 결합 쿼리는 정제본 기준
      final q = buildOcrQueries(['여름(김애란)', '김애란 지음']);
      expect(q.first.text, '여름 김애란');
    });

    test('작가 라인이 candidateCount 밖에 있어도 추출한다', () {
      final texts = [...List.generate(6, (i) => '후보$i'), '정세랑 지음'];
      final q = buildOcrQueries(texts, candidateCount: 5);
      expect(q.first.text, '후보0 정세랑');
    });

    test('접두형 "지은이 ○○○" 라인에서도 작가를 추출한다', () {
      // 실측: 디자인 구구단 표지 — "지은이 에이핫"
      final q = buildOcrQueries(['디자인 구구단', '지은이 에이핫']);
      expect(q.first.text, '디자인 구구단 에이핫');
      expect(q.first.byKeyword, isTrue);
      expect(q.texts, isNot(contains('지은이 에이핫')));
    });

    test('"옮긴이/옮김"도 결합 검색 단서로 쓴다', () {
      final q = buildOcrQueries(['결혼• 여름', '장소미 옮김']);
      expect(q.first.text, '결혼 여름 장소미');
    });

    test('외국어 제목이 상위여도 첫 한글 후보를 작가와 결합한다', () {
      // 실측: SNS 스크린샷 — 프랑스어 원제가 1위, 한글판 제목은 3위
      final texts = [
        'Noces suivi de LiEte',
        '내가 이런 문장을 영접해되나 싶을만큼',
        '결혼• 여름',
        '장소미 옮김',
      ];
      final q = buildOcrQueries(texts);
      final keywordTexts =
          q.where((e) => e.byKeyword).map((e) => e.text).toList();
      expect(keywordTexts, contains('결혼 여름 장소미'));
    });
  });

  group('isOcrNoiseLine — 스크린샷/SNS 잡동사니', () {
    test('상태바 시계·아이콘 오독을 거른다', () {
      // 실측: "1:53"(시계), "087a05"/"G1"(상태바 아이콘 오독)
      expect(isOcrNoiseLine('1:53'), isTrue);
      expect(isOcrNoiseLine('087a05'), isTrue);
      expect(isOcrNoiseLine('G1'), isTrue);
    });

    test('SNS 유저명·경과시간을 거른다', () {
      expect(isOcrNoiseLine('facelessowner 1일'), isTrue);
      expect(isOcrNoiseLine('elly_camping 22시간'), isTrue);
      expect(isOcrNoiseLine('travel_0photo'), isTrue);
      expect(isOcrNoiseLine('7분'), isTrue);
      expect(isOcrNoiseLine('1천'), isTrue);
    });

    test('정상 제목은 거르지 않는다', () {
      expect(isOcrNoiseLine('디자인 구구단'), isFalse);
      expect(isOcrNoiseLine('결혼• 여름'), isFalse);
      expect(isOcrNoiseLine('DESIGN BASICS'), isFalse);
      expect(isOcrNoiseLine('82년생 김지영'), isFalse);
      expect(isOcrNoiseLine('Noces suivi de LiEte'), isFalse);
    });

    test('기호 섞인 숫자 라인을 거른다', () {
      // 실측: X 스크린샷 상태바 "154 3•"
      expect(isOcrNoiseLine('154 3•'), isTrue);
      expect(isOcrNoiseLine('7:32'), isTrue);
    });
  });

  group('combineAdjacentTitleLines — 여러 줄 제목', () {
    // 실측: "질문으로 시작하는"(작게) + "세계사 수업"(크게) 두 줄 제목.
    // 좌표는 위에서 아래로 증가하는 정규 좌표(0~1) 가정.
    OcrLineBox line(String text, double top, double h,
            {double left = 0.3, double right = 0.7}) =>
        OcrLineBox(text: text, top: top, height: h, left: left, right: right);

    test('최대 크기 라인 위의 인접 라인을 결합한다', () {
      final combined = combineAdjacentTitleLines([
        line('질문으로 시작하는', 0.49, 0.026),
        line('세계사 수업', 0.52, 0.065),
        line('오늘의 세계는', 0.60, 0.010), // 너무 작아 제외
      ]);
      expect(combined, '질문으로 시작하는 세계사 수업');
    });

    test('세로로 먼 라인은 결합하지 않는다', () {
      final combined = combineAdjacentTitleLines([
        line('내가 이런 문장을', 0.20, 0.030),
        line('세계사 수업', 0.52, 0.065),
      ]);
      expect(combined, isNull);
    });

    test('가로 범위가 겹치지 않는 라인은 결합하지 않는다', () {
      final combined = combineAdjacentTitleLines([
        line('옆 책 제목', 0.49, 0.030, left: 0.8, right: 0.95),
        line('세계사 수업', 0.52, 0.065),
      ]);
      expect(combined, isNull);
    });

    test('한 줄 제목이면 null', () {
      expect(combineAdjacentTitleLines([line('그릿', 0.3, 0.06)]), isNull);
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
