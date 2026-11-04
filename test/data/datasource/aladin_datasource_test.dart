import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moabook/data/datasource/aladin_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  setUp(() => dio = MockDio());
  void respond(Map<String, dynamic>? data) {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/test'),
        data: data,
        statusCode: 200,
      ),
    );
  }

  test(
    'Aladin HTTP 200 application error is a failure, not zero search results',
    () async {
      respond({'errorCode': 999, 'errorMessage': 'service failure'});
      await expectLater(
        AladinDataSource(dio: dio).searchByTitle('책'),
        throwsFormatException,
      );
    },
  );
  test('genuine empty search remains an empty list', () async {
    respond({'totalResults': 0, 'item': []});
    expect(await AladinDataSource(dio: dio).searchByTitle('책'), isEmpty);
  });
  test('search keeps exact Aladin ID and decodes metadata', () async {
    respond({
      'item': [
        {
          'itemId': 123,
          'title': '제목 &amp; 부제',
          'author': '작가',
          'subInfo': {'itemPage': 192},
        },
      ],
    });
    final result = await AladinDataSource(dio: dio).searchByTitle('책');
    expect(result.single.itemId, 123);
    expect(result.single.title, '제목 & 부제');
    expect(result.single.totalPage, 192);
  });
}
