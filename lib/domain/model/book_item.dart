enum BookSource { aladin, yes24 }

class BookItem {
  final BookSource source;
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
    this.source = BookSource.aladin,
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
  Map<String, dynamic> toSaveRequestBookInfo() {
    if (source != BookSource.aladin) {
      throw StateError('YES24 save contract is not available yet');
    }
    return {
      'source': 'ALADIN',
      'aladinId': itemId,
      'isbn': isbn,
      'title': title,
      'author': author,
      'publisher': publisher,
      'description': description,
      'totalPage': totalPage,
      'publishDate': pubDate,
      'coverImage': cover,
    };
  }
}
