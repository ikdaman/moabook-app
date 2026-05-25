class MyBookDetail {
  final String mybookId;
  final String readingStatus;
  final String createdDate;
  final String? reason;
  final MyBookDetailInfo bookInfo;
  final MyBookDetailHistory historyInfo;

  const MyBookDetail({
    required this.mybookId,
    required this.readingStatus,
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
