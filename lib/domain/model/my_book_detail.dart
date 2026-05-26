class MyBookDetail {
  final String mybookId;
  final String readingStatus;
  /// `STORE` 또는 `HISTORY` — 어느 선반에 속한 책인지.
  final String? shelfType;
  final String createdDate;
  final String? reason;
  final MyBookDetailInfo bookInfo;
  final MyBookDetailHistory historyInfo;

  const MyBookDetail({
    required this.mybookId,
    required this.readingStatus,
    this.shelfType,
    required this.createdDate,
    this.reason,
    required this.bookInfo,
    required this.historyInfo,
  });
}

class MyBookDetailInfo {
  final String title;
  final String author;
  final String? coverImage;
  final String? publisher;
  final int? totalPage;
  final String? publishDate;
  final String? isbn;
  final String? description;
  final String? aladinId;
  /// `ALADIN` / `CUSTOM` / `MANUAL` — 책 정보 출처. CUSTOM/MANUAL 일 때만 책정보 편집 가능.
  final String? source;

  const MyBookDetailInfo({
    required this.title,
    required this.author,
    this.coverImage,
    this.publisher,
    this.totalPage,
    this.publishDate,
    this.isbn,
    this.description,
    this.aladinId,
    this.source,
  });
}

class MyBookDetailHistory {
  final String? startedDate;
  final String? finishedDate;

  const MyBookDetailHistory({this.startedDate, this.finishedDate});
}

class HistoryBookInfo {
  final int mybookId;
  final String title;
  final List<String> author;
  final String? coverImage;
  final String? description;
  final String startedDate;
  final String? finishedDate;

  const HistoryBookInfo({
    required this.mybookId,
    required this.title,
    required this.author,
    this.coverImage,
    this.description,
    required this.startedDate,
    this.finishedDate,
  });
}
