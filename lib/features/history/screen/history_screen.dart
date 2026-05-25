import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/model/my_book_detail.dart';
import '../../../features/auth/provider/auth_provider.dart';
import '../../../features/home/provider/home_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<HistoryBookInfo> _books = [];
  bool _isLoading = false;
  bool _descending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final isLoggedIn =
        await ref.read(authRepositoryProvider).isLoggedIn();
    if (!isLoggedIn) return;

    setState(() => _isLoading = true);
    try {
      final ds = ref.read(myBookDataSourceProvider);
      final books = await ds.getHistoryBooks(descending: _descending);
      setState(() { _books = books; _isLoading = false; });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn =
        ref.watch(isLoggedInProvider).valueOrNull ?? false;

    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDefault,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('로그인 후 사용이 가능합니다',
                  style: AppTypography.dungGeunMoSubtitle
                      .copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(Routes.login),
                child: const Text('로그인하기'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDefault,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text('히스토리',
                      style: AppTypography.dungGeunMoHeader
                          .copyWith(color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() => _descending = !_descending);
                      _load();
                    },
                    child: Row(
                      children: [
                        Text('최신순',
                            style: AppTypography.dungGeunMoSubtitle
                                .copyWith(color: AppColors.textPrimary)),
                        Icon(
                          _descending
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _books.isEmpty
                      ? Center(
                          child: Text('히스토리가 없습니다.',
                              style: AppTypography.dungGeunMoSubtitle
                                  .copyWith(color: AppColors.textPrimary)))
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _books.length,
                          itemBuilder: (_, i) => _HistoryItem(
                            book:  _books[i],
                            onTap: () => context
                                .push(Routes.bookInfo(_books[i].mybookId)),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final HistoryBookInfo book;
  final VoidCallback onTap;

  const _HistoryItem({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = '${book.startedDate}'
        '${book.finishedDate != null ? ' ~ ${book.finishedDate}' : ''}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 8),
        color:   AppColors.backgroundWhite,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.coverImage != null)
              CachedNetworkImage(
                  imageUrl: book.coverImage!,
                  width: 60, height: 85, fit: BoxFit.cover)
            else
              Container(
                  width: 60, height: 85, color: AppColors.surfaceGray),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: AppTypography.wantedSansBookTitle
                          .copyWith(color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(book.author.join(', '),
                      style: AppTypography.wantedSansBodySmall
                          .copyWith(color: AppColors.textGray),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(dateStr,
                      style: AppTypography.dungGeunMoTag
                          .copyWith(color: AppColors.textGray)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
