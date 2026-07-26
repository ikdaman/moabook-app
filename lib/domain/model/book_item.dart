class BookItem {
  final String title;
  final String author;
  final String cover;
  final String publisher;
  final String isbn;
  final int itemId;
  final String link;
  final String description;
  final String pubDate;
  final int? totalPage;

  const BookItem({
    required this.title,
    required this.author,
    required this.cover,
    required this.publisher,
    required this.isbn,
    required this.itemId,
    required this.link,
    required this.description,
    required this.pubDate,
    this.totalPage,
  });

  /// `POST /mybooks` 요청 바디의 `bookInfo` 형태로 변환.
  Map<String, dynamic> toSaveRequestBookInfo() => {
        'source':      'ALADIN',
        'aladinId':    itemId,
        'isbn':        isbn,
        'title':       title,
        'author':      author,
        'publisher':   publisher,
        'description': description,
        'totalPage':   totalPage,
        'publishDate': pubDate,
        'coverImage':  cover,
      };
}
