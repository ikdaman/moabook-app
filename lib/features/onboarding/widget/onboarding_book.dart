import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moabook_reading_ui/moabook_reading_ui.dart';
import '../../../domain/model/book_item.dart';

class OnboardingBook extends StatelessWidget {
  const OnboardingBook({
    super.key,
    required this.book,
    this.width = 84,
    this.height = 118,
  });
  final BookItem book;
  final double width, height;
  @override
  Widget build(BuildContext context) {
    const palette = DesignPalette(Mood.a);
    final fallback = ColoredBox(
      color: const Color(0xffe3ded1),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            book.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: palette.text(
              width < 100 ? 12 : 16,
              serif: true,
              weight: 600,
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: palette.ink)),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: book.cover.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: book.cover,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// A single, quiet arrival onto a shelf rather than an endlessly running effect.
class FirstBookShelf extends StatelessWidget {
  const FirstBookShelf({super.key, required this.book});
  final BookItem book;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 224,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Container(
              height: 2,
              color: const Color(0xfff4f1ea).withValues(alpha: .5),
            ),
          ),
          Positioned(
            bottom: 14,
            child: Transform.translate(
              offset: Offset(0, -32 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: OnboardingBook(book: book, width: 132, height: 186),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
