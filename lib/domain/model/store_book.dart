class StoreBook {
  final List<StoreBookItem> content;
  final int totalPages;
  final int totalElements;
  final bool last;
  final bool first;
  final int number;
  final bool empty;

  const StoreBook({
    required this.content,
    required this.totalPages,
    required this.totalElements,
    required this.last,
    required this.first,
    required this.number,
    required this.empty,
  });
}

class StoreBookItem {
  final int mybookId;
  final String createdDate;
  final String title;
  final List<String> author;
  final String? coverImage;
  final String? description;
  final String? reason;

  const StoreBookItem({
    required this.mybookId,
    required this.createdDate,
    required this.title,
    required this.author,
    this.coverImage,
    this.description,
    this.reason,
  });
}
