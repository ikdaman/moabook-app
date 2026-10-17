class PreviewBook {
  const PreviewBook(
    this.id,
    this.title,
    this.author,
    this.publisher,
    this.reason,
    this.reasonType, {
    this.demo = false,
  });
  final String id, title, author, publisher, reason, reasonType;
  final bool demo;
  String get cover => 'assets/design_preview/covers/$id.jpg';
}

const previewBooks = [
  PreviewBook('boy', '소년과 두더지와 여우와 말', '찰리 맥커시', '상상의힘', '하말넘많에서 추천해줌', '추천'),
  PreviewBook('human', '소년이 온다', '한강', '창비', '오래 기억하고 싶은 이야기', '소개'),
  PreviewBook('vegetarian', '채식주의자', '한강', '창비', '언젠가 꼭 읽고 싶은 책', 'WISH'),
  PreviewBook('farewell', '작별하지 않는다', '한강', '문학동네', '생일 선물로 받음', '선물'),
  PreviewBook('contradiction', '모순', '양귀자', '쓰다', '친구가 인생 책이라고 했던 책', '추천'),
  PreviewBook('store', '불편한 편의점', '김호연', '나무옆의자', '', ''),
  PreviewBook('almond', '아몬드', '손원평', '창비', '', ''),
  PreviewBook('kim', '82년생 김지영', '조남주', '민음사', '다음에 읽어보고 싶어서', 'WISH'),
  PreviewBook('demian', '데미안', '헤르만 헤세', '민음사', '선생님이 소개해준 책', '소개'),
];

// Fictional titles for pagination review; collection samples keep their nine real covers.
final shelfPreviewBooks = List<PreviewBook>.unmodifiable([
  ...previewBooks,
  for (var i = 0; i < 81; i++)
    PreviewBook(
      'shelf-demo-${i + 1}',
      '${['느린', '고요한', '작은', '푸른', '오래된', '다정한', '낯선', '평범한', '새로운'][i ~/ 9]} ${['문장의 숲', '밤의 산책', '시간의 지도', '계절의 기록', '도시의 뒷면', '마음의 여백', '바람의 서랍', '기억의 온도', '여름의 편지'][i % 9]}',
      ['김서연', '이도윤', '박지우', '최수현', '정하린', '강유진', '윤서우', '임나래', '한이솔'][i % 9],
      '모아북 샘플',
      ['친구가 추천해준 책', '다음 계절에 읽고 싶어서', '선물로 받은 이야기', '독서 모임에서 소개받음', ''][i % 5],
      ['추천', 'WISH', '선물', '소개', ''][i % 5],
      demo: true,
    ),
]);

const previewScreens = <String, String>{
  'shelf': '기본 서가',
  'shelf-empty': '기본 서가 · 빈 화면',
  'collection': '주제 서가',
  'collection-next': '주제 서가 · 다음 책장',
  'collection-end': '주제 서가 · 새 책장 만들기',
  'collections': '나의 컬렉션',
  'collections-empty': '나의 컬렉션 · 빈 화면',
  'collection-create': '컬렉션 만들기',
  'collection-edit': '컬렉션 편집',
  'add-options': '책 추가 · 진입 방식',
  'search': '책 검색 · 결과',
  'search-empty': '책 검색 · 결과 없음',
  'book-info': '책 정보',
  'save-wish': '책 저장 · 읽고 싶은 책',
  'save-reading': '책 저장 · 읽고 있는 책',
  'save-read': '책 저장 · 읽은 책',
  'duplicate': '이미 저장한 책',
  'card-front': '독서카드 · 앞면',
  'card-back': '독서카드 · 기록',
  'card-empty': '독서카드 · 기록 없음',
  'record-options': '기록 추가 · 종류 선택',
  'record-entry': '기록 추가 · 구매',
  'record-quote': '기록 추가 · 문장',
  'record-free': '기록 추가 · 자유 기록',
  'record-complete': '기록 추가 · 완료',
  'date-picker': '날짜 선택',
  'capture': '표지·바코드 촬영',
  'gallery': '갤러리에서 추가',
};
