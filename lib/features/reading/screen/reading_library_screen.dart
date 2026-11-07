import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moabook_reading/moabook_reading.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../domain/model/book_item.dart';
import '../../auth/provider/auth_provider.dart';
import '../provider/reading_gateway_provider.dart';
import '../export/reading_export_screen.dart';

class ReadingLibraryScreen extends ConsumerStatefulWidget {
  const ReadingLibraryScreen({
    super.key,
    this.initialScreen = 'shelf',
    this.bookId,
  });
  final String initialScreen;
  final String? bookId;
  @override
  ConsumerState<ReadingLibraryScreen> createState() =>
      _ReadingLibraryScreenState();
}

class _ReadingLibraryScreenState extends ConsumerState<ReadingLibraryScreen> {
  final workspace = GlobalKey<ReadingWorkspaceState>();

  Future<ReadingBook?> capture() async {
    final result = await context.push<BookItem>(
      '${Routes.capture}?selection=true',
    );
    return result == null ? null : readingBookFromSearch(result);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(readingRefreshProvider, (previous, next) {
      unawaited(
        workspace.currentState?.reloadFromServer() ?? Future<void>.value(),
      );
    });
    return ref
        .watch(isLoggedInProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => ref.invalidate(isLoggedInProvider),
                child: const Text('로그인 상태 다시 확인'),
              ),
            ),
          ),
          data: (loggedIn) => !loggedIn
              ? Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => context.go(Routes.login),
                      child: const Text('로그인하고 내 서가 보기'),
                    ),
                  ),
                )
              : ReadingWorkspace(
                  key: workspace,
                  initialMood: Mood.a,
                  initialScreen: widget.initialScreen,
                  initialBookId: widget.bookId,
                  embedded: true,
                  gateway: ref.watch(readingGatewayProvider),
                  onSettings: () => context.push(Routes.setting),
                  onCapture: capture,
                  onExport: (request) => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ReadingExportScreen(request: request),
                    ),
                  ),
                  onOpenLink: (url) async {
                    final uri = Uri.tryParse(url);
                    if (uri != null && ['http', 'https'].contains(uri.scheme)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
        );
  }
}
