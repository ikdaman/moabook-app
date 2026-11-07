import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moabook/core/network/dio_client.dart';
import 'package:moabook/features/auth/provider/auth_provider.dart';
import 'package:moabook/features/reading/screen/reading_library_screen.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';

class ServerAdapter implements HttpClientAdapter {
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    expectSync(
      options.headers['Authorization'],
      'Bearer integration-test-only',
    );
    requests.add(options.path);
    final Object result = switch (options.path) {
      '/mybooks' => {
        'totalPages': 1,
        'totalElements': 1,
        'books': [
          {
            'mybookId': 71,
            'bookInfo': {
              'title': '인증된 내 책',
              'author': ['작가'],
            },
          },
        ],
      },
      '/collections' => {'totalCount': 0, 'collections': []},
      '/mybooks/71' => {
        'myBookId': 71,
        'title': '인증된 내 책',
        'createdDate': '2026-11-01T00:00:00',
        'readingStatus': 'DONE',
        'totalRecords': 0,
      },
      '/mybooks/71/records' => [],
      _ => throw StateError('Unexpected request ${options.path}'),
    };
    return ResponseBody.fromString(
      jsonEncode(result),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'main app uses the authenticated provider for shelf and real-ID card routes',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'integration-test-only',
      });
      final adapter = ServerAdapter();
      final dio = createDioClient(const FlutterSecureStorage())
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            isLoggedInProvider.overrideWith((ref) async => true),
          ],
          child: const MaterialApp(home: ReadingLibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<ReadingWorkspaceState>(
        find.byType(ReadingWorkspace),
      );
      expect(state.isLive, isTrue);
      expect(state.library.keys, ['71']);
      expect(adapter.requests, containsAll(['/mybooks', '/collections']));
      state.openBook(state.library['71']!);
      await tester.pumpAndSettle();
      expect(
        adapter.requests,
        containsAll(['/mybooks/71', '/mybooks/71/records']),
      );
      expect(state.readingStatus, '다 읽은 책');
      expect(find.text('인증된 내 책'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'signed-out app requests login before creating a live workspace',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isLoggedInProvider.overrideWith((ref) async => false)],
          child: const MaterialApp(home: ReadingLibraryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('로그인하고 내 서가 보기'), findsOneWidget);
      expect(find.byType(ReadingWorkspace), findsNothing);
    },
  );
}
