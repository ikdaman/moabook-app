import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/domain/model/book_item.dart';

void main() {
  group('BookItem.toSaveRequestBookInfo', () {
    const book = BookItem(
      title: '모순 - 개정판',
      author: '양귀자 (지은이)',
      cover: 'https://image.aladin.co.kr/cover/1.jpg',
      publisher: '쓰다',
      isbn: '9788998441012',
      itemId: 12345,
      link: 'https://www.aladin.co.kr/item/12345',
      description: '설명',
      pubDate: '2013-04-01',
      totalPage: 307,
    );

    test('POST /mybooks bookInfo 스펙과 일치한다', () {
      expect(book.toSaveRequestBookInfo(), {
        'source': 'ALADIN',
        'aladinId': 12345,
        'isbn': '9788998441012',
        'title': '모순 - 개정판',
        'author': '양귀자 (지은이)',
        'publisher': '쓰다',
        'description': '설명',
        'totalPage': 307,
        'publishDate': '2013-04-01',
        'coverImage': 'https://image.aladin.co.kr/cover/1.jpg',
      });
    });

    test('link 는 저장 바디에 포함되지 않는다', () {
      expect(book.toSaveRequestBookInfo().containsKey('link'), isFalse);
    });
  });
}
