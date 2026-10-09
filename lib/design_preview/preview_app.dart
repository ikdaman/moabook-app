import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_system.dart';
import 'sample_data.dart';

class DesignPreviewApp extends StatelessWidget {
  const DesignPreviewApp({
    super.key,
    this.previewKey,
    this.initialMood = Mood.a,
    this.initialScreen = 'shelf',
  });
  final GlobalKey<DesignPreviewState>? previewKey;
  final Mood initialMood;
  final String initialScreen;
  @override
  Widget build(BuildContext context) => DesignPreview(
    key: previewKey,
    initialMood: initialMood,
    initialScreen: initialScreen,
  );
}

class DesignPreview extends StatefulWidget {
  const DesignPreview({
    super.key,
    required this.initialMood,
    required this.initialScreen,
  });
  final Mood initialMood;
  final String initialScreen;
  @override
  State<DesignPreview> createState() => DesignPreviewState();
}

class DesignPreviewState extends State<DesignPreview> {
  late Mood mood = widget.initialMood;
  late String screen = widget.initialScreen;
  DesignPalette get p => DesignPalette(mood);
  PreviewBook book = previewBooks.first;
  String collectionName = '인생 책 LIST';
  String recordKind = '직접 구매';
  String searchQuery = '소년';
  String reasonDraft = '하말넘많에서 추천해줌.\n언젠가 천천히 읽어보고 싶다.';
  String memoDraft = '동네 서점에서 만난 책.\n표지를 보고 한참을 망설이다 데려왔다.';
  String date = '2026.08.05';
  String readingStatus = '읽는 중';
  final Set<String> selectedBooks = {'boy', 'human', 'vegetarian'};
  final List<(String, String)> addedRecords = [];
  final List<String> customCollections = [];
  final List<String> history = [];
  final ScrollController scroll = ScrollController();

  void showPreview(String target, String style) {
    if (!previewScreens.containsKey(target)) {
      throw ArgumentError('Unknown screen: $target');
    }
    if (style != 'A' && style != 'C') {
      throw ArgumentError('Unknown style: $style');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      mood = style == 'C' ? Mood.c : Mood.a;
      screen = target;
      book = previewBooks.first;
      collectionName = '인생 책 LIST';
      readingStatus = '읽는 중';
      recordKind = switch (target) {
        'record-quote' => '마음에 든 문장',
        'record-free' => '자유 기록',
        _ => '직접 구매',
      };
      history.clear();
      addedRecords.clear();
      customCollections.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(0);
    });
  }

  void go(String target) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      history.add(screen);
      screen = target;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(0);
    });
  }

  void back() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => screen = history.isEmpty ? 'shelf' : history.removeLast());
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '모아북 디자인 시안',
    debugShowCheckedModeBanner: false,
    theme: p.theme,
    home: AnnotatedRegion<SystemUiOverlayStyle>(
      value: p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: p.background,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scroll,
                        padding: EdgeInsets.fromLTRB(
                          22,
                          12,
                          22,
                          hasNav ? 12 : 28,
                        ),
                        child: page(),
                      ),
                    ),
                    if (hasNav) navigation(),
                    if (!hasNav && bottomAction != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          10,
                          22,
                          MediaQuery.paddingOf(context).bottom + 14,
                        ),
                        child: bottomAction!,
                      ),
                  ],
                ),
                if (overlay != null) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: back,
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: p.dark ? .68 : .5,
                        ),
                      ),
                    ),
                  ),
                  Align(alignment: Alignment.bottomCenter, child: overlay!),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  bool get hasNav => [
    'shelf',
    'shelf-empty',
    'collection',
    'collections',
    'collections-empty',
    'add-options',
    'collection-create',
  ].contains(screen);
  Widget? get bottomAction => switch (screen) {
    'book-info' => button('이 책 저장하기', () => go('save-wish'), icon: 'plus'),
    'search-empty' => button(
      '다른 검색어로 찾아보기',
      () => go('search'),
      icon: 'search',
    ),
    'card-front' => button(
      '카드 뒤의 기록 보기',
      () => go('card-back'),
      icon: 'arrow-right',
    ),
    'card-back' || 'card-empty' || 'record-options' => Align(
      alignment: Alignment.centerRight,
      child: circularRecordButton(),
    ),
    'collection-edit' => button(
      '${selectedBooks.length}권으로 컬렉션 저장',
      () => go('collection'),
      icon: 'check',
    ),
    'record-complete' => button(
      '독서카드로 돌아가기',
      () => go('card-back'),
      icon: 'arrow-right',
    ),
    'capture' => button(
      '책 정보 확인하기',
      () => go('book-info'),
      icon: 'scan-barcode',
    ),
    'gallery' => button(
      '선택한 사진으로 책 찾기',
      () => go('book-info'),
      icon: 'arrow-right',
    ),
    _ => null,
  };

  Widget? get overlay => switch (screen) {
    'add-options' => addSheet(),
    'collection-create' => createSheet(),
    'save-wish' || 'save-reading' || 'save-read' => saveSheet(),
    'duplicate' => duplicateDialog(),
    'record-options' => recordSheet(),
    'record-entry' || 'record-quote' || 'record-free' => recordEntrySheet(),
    'date-picker' => dateSheet(),
    _ => null,
  };

  Widget page() => switch (screen) {
    'shelf' ||
    'shelf-empty' ||
    'add-options' => shelf(empty: screen == 'shelf-empty'),
    'collection' || 'collection-create' => collection(),
    'collections' ||
    'collections-empty' => collections(empty: screen == 'collections-empty'),
    'collection-edit' => collectionEdit(),
    'search' || 'search-empty' => searchPage(empty: screen == 'search-empty'),
    'book-info' ||
    'save-wish' ||
    'save-reading' ||
    'save-read' ||
    'duplicate' => bookInfo(),
    'card-front' => cardFront(),
    'card-back' ||
    'card-empty' ||
    'record-options' ||
    'record-entry' ||
    'record-quote' ||
    'record-free' ||
    'date-picker' => cardBack(empty: screen == 'card-empty'),
    'record-complete' => complete(),
    'capture' => capture(),
    'gallery' => gallery(),
    _ => shelf(),
  };

  Widget t(
    String value,
    double size, {
    int weight = 400,
    Color? color,
    bool serif = false,
    bool mono = false,
    int? lines,
    TextAlign? align,
  }) => Text(
    value,
    maxLines: lines,
    overflow: lines == null ? null : TextOverflow.ellipsis,
    textAlign: align,
    style: p.text(
      math.max(size, mono ? 11 : 12),
      weight: weight,
      color: color,
      serif: serif,
      mono: mono,
    ),
  );
  Widget gap(double height) => SizedBox(height: height);
  Widget rule({Color? color, double width = 1}) =>
      Container(height: width, color: color ?? p.line);
  Widget icon(String name, {Color? color, double size = 22}) =>
      DesignIcon(name, color: color ?? p.ink, size: math.max(size, 18));
  Widget iconButton(
    String name,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) => Semantics(
    label: label,
    button: true,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: icon(name, color: color)),
      ),
    ),
  );
  Widget button(
    String label,
    VoidCallback onTap, {
    String? icon,
    bool secondary = false,
    bool compact = false,
  }) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 44 : 54),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: secondary ? p.card : p.button,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: secondary ? p.ink : p.button, width: 1.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (icon != null) ...[
              this.icon(icon, color: secondary ? p.ink : p.onButton, size: 18),
              const SizedBox(width: 9),
            ],
            Flexible(
              child: t(
                label,
                compact ? 13 : 15,
                weight: 600,
                color: secondary ? p.ink : p.onButton,
                align: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget label(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: t(value, 11, mono: true, color: p.dark ? p.accent : p.muted),
  );
  Widget header(
    String title, {
    String? eyebrow,
    bool previous = false,
    Widget? action,
    bool serif = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (previous)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            iconButton('chevron-left', '뒤로', back),
            if (eyebrow != null) t(eyebrow, 10, mono: true, color: p.muted),
          ],
        ),
      if (!previous && eyebrow != null) ...[label(eyebrow), gap(3)],
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: t(
              title,
              p.dark ? 32 : 29,
              weight: p.dark ? 600 : 700,
              color: p.dark ? p.accent : p.ink,
              serif: serif,
              lines: 2,
            ),
          ),
          ?action,
        ],
      ),
      gap(17),
      rule(color: p.ink, width: p.dark ? 1 : 1.3),
      gap(18),
    ],
  );

  Widget navigation() => Builder(
    builder: (context) => Container(
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        MediaQuery.paddingOf(context).bottom + 8,
      ),
      decoration: BoxDecoration(
        color: p.background,
        border: Border(top: BorderSide(color: p.line, width: 1)),
      ),
      child: Row(
        children: [
          navItem(
            '기본 서가',
            'library',
            screen.startsWith('shelf') || screen == 'add-options',
            () => go('shelf'),
          ),
          navItem(
            '주제 서가',
            'layers',
            !screen.startsWith('shelf') && screen != 'add-options',
            () => go('collection'),
          ),
        ],
      ),
    ),
  );
  Widget navItem(String title, String name, bool active, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 30,
                  decoration: BoxDecoration(
                    color: active
                        ? p.accent.withValues(alpha: p.dark ? .14 : .10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: icon(
                      name,
                      size: 22,
                      color: active ? (p.dark ? p.accent : p.orange) : p.muted,
                    ),
                  ),
                ),
                gap(4),
                t(
                  title,
                  13,
                  weight: active ? 600 : 400,
                  color: active ? p.ink : p.muted,
                ),
              ],
            ),
          ),
        ),
      );

  Color reasonColor(String type) => switch (type) {
    '추천' => p.orange,
    'WISH' => p.blue,
    '선물' => p.gift,
    '소개' => p.yellow,
    _ => p.line,
  };
  Color reasonTextColor(String type) =>
      type == 'WISH' || (type == '선물' && !p.dark)
      ? Colors.white
      : const Color(0xff1b1b1b);

  Widget cover(
    PreviewBook value, {
    double? width,
    double? height,
    bool shadow = false,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      border: Border.all(
        color: p.dark ? const Color(0xff121212) : p.ink,
        width: 1,
      ),
      boxShadow: shadow
          ? [const BoxShadow(color: Color(0xff1b1b1b), offset: Offset(6, 6))]
          : null,
    ),
    child: Image.asset(
      value.cover,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stack) => ColoredBox(
        color: const Color(0xffd4d4d4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: t(
              value.title,
              12,
              color: const Color(0xff1b1b1b),
              align: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
  Widget obi(PreviewBook value, {bool short = false}) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 38),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
    decoration: BoxDecoration(
      color: value.reason.isEmpty
          ? p.card
          : reasonColor(value.reasonType).withValues(alpha: p.dark ? .16 : .09),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (value.reason.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: reasonColor(value.reasonType),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            value.reason.isEmpty
                ? '저장 이유 없음'
                : short
                ? value.reasonType
                : value.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: p.text(
              12,
              height: 1.35,
              weight: 500,
              color: value.reason.isEmpty ? p.muted : p.ink,
            ),
          ),
        ),
      ],
    ),
  );

  Widget shelf({bool empty = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header(
        '서가',
        eyebrow: 'MOABOOK / MY BOOKS',
        action: iconButton('settings-2', '시안 설정', showDesignPicker),
      ),
      Row(
        children: [
          t(empty ? '0권의 책' : '${previewBooks.length}권의 책', 12, color: p.muted),
          const Spacer(),
          iconButton('download', '서가 이미지 저장', () => notice('서가 이미지 저장 시안입니다.')),
        ],
      ),
      gap(8),
      button('책 추가', () => go('add-options'), icon: 'plus'),
      gap(20),
      if (empty)
        emptyState(
          'book-open',
          '어떤 책이 떠오르나요?',
          '읽고 싶은 책도, 오래 간직한 책도.\n첫 번째 책을 서가에 꽂아보세요.',
          null,
        )
      else ...[
        for (int row = 0; row < 2; row++) ...[bookShelf(row), gap(24)],
        Center(child: t('1 / 1', 11, mono: true, color: p.muted)),
      ],
    ],
  );
  Widget bookShelf(int row) => LayoutBuilder(
    builder: (context, constraints) {
      final books = row == 0
          ? previewBooks.take(5).toList()
          : previewBooks.skip(5).toList();
      const widths = [1.12, .87, .76, 1.04, .82, 1.0, .86, .92, .78];
      const heights = [
        205.0,
        184.0,
        194.0,
        181.0,
        197.0,
        188.0,
        171.0,
        184.0,
        175.0,
      ];
      const colors = [
        Color(0xffe5dfcf),
        Color(0xff334332),
        Color(0xff8ca9b5),
        Color(0xffadc7cb),
        Color(0xffe5dbce),
        Color(0xffc3b190),
        Color(0xffcba477),
        Color(0xffe7e3d9),
        Color(0xff4d4659),
      ];
      final start = row == 0 ? 0 : 5;
      final unit = (constraints.maxWidth - 10) / 5.1;
      return Column(
        children: [
          SizedBox(
            height: row == 0 ? 205 : 188,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(books.length, (i) {
                final value = books[i];
                final n = start + i;
                final lightInk = n == 1 || n == 8;
                final foreground = lightInk
                    ? const Color(0xfff4f1ea)
                    : const Color(0xff282824);
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Semantics(
                    label: '${value.title}, 독서카드 열기',
                    button: true,
                    child: InkWell(
                      onTap: () {
                        book = value;
                        go('card-front');
                      },
                      child: Container(
                        width: unit * widths[n],
                        height: heights[n],
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: colors[n],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: .22),
                            width: .8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .10),
                              offset: const Offset(2, 0),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            gap(12),
                            Container(
                              width: 18,
                              height: 1,
                              color: foreground.withValues(alpha: .35),
                            ),
                            gap(9),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: RotatedBox(
                                  quarterTurns: 1,
                                  child: Text(
                                    value.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: p.text(
                                      13,
                                      weight: 500,
                                      height: 1.3,
                                      color: foreground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                value.author.split(' ').first,
                                maxLines: 1,
                                style: p.text(
                                  9,
                                  height: 1.2,
                                  color: foreground.withValues(alpha: .8),
                                ),
                              ),
                            ),
                            if (value.reason.isNotEmpty)
                              Container(
                                height: 17,
                                color: reasonColor(value.reasonType),
                                alignment: Alignment.center,
                                child: Text(
                                  value.reasonType == 'WISH'
                                      ? 'W'
                                      : value.reasonType.substring(0, 1),
                                  style: p.text(
                                    9,
                                    weight: 600,
                                    height: 1,
                                    color: reasonTextColor(value.reasonType),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: p.dark ? const Color(0xff4a493b) : const Color(0xffb6a98e),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .10),
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget collection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      label('COLLECTION / 01'),
      InkWell(
        key: const Key('collection-picker'),
        onTap: () => go('collections'),
        child: Row(
          children: [
            Flexible(
              child: t(
                collectionName,
                p.dark ? 31 : 28,
                serif: true,
                weight: 700,
                color: p.dark ? p.accent : p.ink,
                lines: 2,
              ),
            ),
            const SizedBox(width: 8),
            icon('chevron-down', size: 24, color: p.dark ? p.accent : p.ink),
          ],
        ),
      ),
      gap(16),
      rule(color: p.ink, width: 1.3),
      gap(9),
      Row(
        children: [
          t('9권', 12, mono: true, color: p.muted),
          const Spacer(),
          actionText('편집', 'pencil', () => go('collection-edit')),
          const SizedBox(width: 16),
          actionText('이미지 저장', 'download', () => notice('컬렉션 이미지 저장 시안입니다.')),
        ],
      ),
      gap(16),
      booksGrid(previewBooks),
      gap(10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final kind in ['추천', 'WISH', '선물', '소개'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                children: [
                  Container(width: 7, height: 7, color: reasonColor(kind)),
                  const SizedBox(width: 4),
                  t(kind, 10, color: p.muted),
                ],
              ),
            ),
        ],
      ),
      gap(8),
      Center(child: t('1 / 1', 11, mono: true, color: p.muted)),
    ],
  );
  Widget actionText(String title, String name, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon(name, size: 14),
          const SizedBox(width: 5),
          t(title, 13, weight: 500),
        ],
      ),
    ),
  );
  Widget booksGrid(
    List<PreviewBook> books, {
    bool editing = false,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = editing
          ? (constraints.maxWidth - 22) / 3
          : math.min(94.0, (constraints.maxWidth - 22) / 3);
      return Wrap(
        spacing: editing ? 11 : (constraints.maxWidth - itemWidth * 3) / 2,
        runSpacing: editing ? 19 : 18,
        children: books
            .map(
              (value) => SizedBox(
                width: itemWidth,
                child: InkWell(
                  onTap: () {
                    if (editing) {
                      setState(() {
                        selectedBooks.contains(value.id)
                            ? selectedBooks.remove(value.id)
                            : selectedBooks.add(value.id);
                      });
                    } else {
                      book = value;
                      go('card-front');
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          cover(
                            value,
                            width: itemWidth,
                            height: itemWidth * (editing ? 1.29 : 1.23),
                          ),
                          if (editing)
                            Positioned(
                              top: 7,
                              right: 7,
                              child: Container(
                                width: 25,
                                height: 25,
                                decoration: BoxDecoration(
                                  color: selectedBooks.contains(value.id)
                                      ? p.button
                                      : p.background,
                                  border: Border.all(color: p.ink),
                                  shape: BoxShape.circle,
                                ),
                                child: selectedBooks.contains(value.id)
                                    ? Center(
                                        child: icon(
                                          'check',
                                          size: 15,
                                          color: p.onButton,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                      if (!editing) ...[gap(7), obi(value)],
                      if (editing) ...[gap(6), t(value.title, 11, lines: 2)],
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );

  Widget collections({bool empty = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header('나의 컬렉션', eyebrow: 'COLLECTION INDEX', previous: true),
      Row(
        children: [
          t(
            empty ? '아직 만든 컬렉션이 없어요' : '${6 + customCollections.length}개의 컬렉션',
            12,
            color: p.muted,
          ),
          const Spacer(),
          actionText('새 컬렉션', 'plus', () => go('collection-create')),
        ],
      ),
      gap(12),
      if (empty)
        emptyState(
          'layers',
          '책을 모으는 나만의 기준',
          '인생 책, 좋아하는 작가, 읽고 싶은 계절.\n책들을 하나의 컬렉션으로 묶어보세요.',
          () => go('collection-create'),
        )
      else ...[
        for (final entry in [
          ('인생 책 LIST', '9권 · 오래 간직하고 싶은 책', 0),
          ('새드엔딩', '3권 · 마음에 오래 남은 마지막', 3),
          ('한강의 문장들', '3권 · 작가의 세계를 따라서', 1),
          ('올해 읽고 싶은 책', '8권 · 2026년의 작은 다짐', 4),
          ('선물 받은 이야기', '4권 · 함께 남은 마음', 5),
          ('다시 펼칠 책', '5권 · 한 번 더 읽고 싶어서', 7),
          for (final title in customCollections) (title, '0권 · 새로 만든 컬렉션', 0),
        ])
          collectionRow(entry.$1, entry.$2, entry.$3),
      ],
    ],
  );
  Widget collectionRow(String title, String subtitle, int index) => InkWell(
    onTap: () {
      collectionName = title;
      go('collection');
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 84,
            child: Stack(
              children: [
                Positioned(
                  left: 24,
                  top: 4,
                  child: Transform.rotate(
                    angle: .07,
                    child: cover(
                      previewBooks[(index + 1) % 9],
                      width: 49,
                      height: 70,
                    ),
                  ),
                ),
                Positioned(
                  left: 3,
                  top: 10,
                  child: Transform.rotate(
                    angle: -.06,
                    child: cover(previewBooks[index], width: 49, height: 70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                t(title, 17, weight: 600, serif: !p.dark),
                gap(5),
                t(subtitle, 11, color: p.muted),
                if (title == collectionName) ...[
                  gap(8),
                  Row(
                    children: [
                      icon(
                        'check',
                        size: 13,
                        color: p.dark ? p.accent : p.orange,
                      ),
                      const SizedBox(width: 4),
                      t(
                        '지금 보고 있는 컬렉션',
                        10,
                        weight: 500,
                        color: p.dark ? p.accent : p.orange,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          icon('chevron-right', size: 18, color: p.muted),
        ],
      ),
    ),
  );
  Widget collectionEdit() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header('컬렉션 편집', previous: true, eyebrow: 'COLLECTION / EDIT'),
      field(
        '컬렉션 이름',
        collectionName,
        onChanged: (value) => collectionName = value,
      ),
      gap(24),
      Row(
        children: [
          t('컬렉션에 담을 책', 15, weight: 600),
          const Spacer(),
          t(
            '${selectedBooks.length}권 선택',
            12,
            color: p.dark ? p.accent : p.orange,
          ),
        ],
      ),
      gap(16),
      booksGrid(previewBooks, editing: true),
    ],
  );

  Widget searchPage({bool empty = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header('책 찾기', previous: true, eyebrow: 'ADD / SEARCH'),
      TextFormField(
        key: ValueKey('$screen-query'),
        initialValue: empty ? '아무도 모르는 책 제목' : searchQuery,
        style: p.text(16),
        textInputAction: TextInputAction.search,
        onChanged: (value) => searchQuery = value,
        onFieldSubmitted: (value) => go(
          value.contains('소년') || value.contains('한강')
              ? 'search'
              : 'search-empty',
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.all(14),
            child: icon('search', size: 20),
          ),
          suffixIcon: iconButton('x', '검색어 지우기', () {
            searchQuery = '';
            go('search');
          }),
          filled: true,
          fillColor: p.card,
          hintText: '책 제목 또는 저자',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: p.ink, width: 1.3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: p.dark ? p.accent : p.ink,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
      gap(26),
      if (empty)
        emptyState('search', '아직 찾지 못했어요', '제목의 일부나 저자 이름으로\n다시 검색해보세요.', null)
      else ...[
        Row(
          children: [
            t('검색 결과', 13, weight: 600),
            const Spacer(),
            t('3권', 11, mono: true, color: p.muted),
          ],
        ),
        gap(10),
        for (final value in [previewBooks[0], previewBooks[1], previewBooks[6]])
          InkWell(
            onTap: () {
              book = value;
              go('book-info');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cover(value, width: 77, height: 106),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            gap(4),
                            t(value.title, 16, weight: 600),
                            if (value.id == 'boy')
                              t('(10만부 판매 기념 한정판)', 11, color: p.muted),
                            gap(11),
                            t(value.author, 12),
                            gap(3),
                            t(value.publisher, 11, color: p.muted),
                          ],
                        ),
                      ),
                      icon('chevron-right', size: 18, color: p.muted),
                    ],
                  ),
                  gap(18),
                  rule(),
                ],
              ),
            ),
          ),
        gap(16),
        Center(child: t('찾던 책을 선택하면 저장할 수 있어요.', 12, color: p.muted)),
      ],
    ],
  );

  Widget bookInfo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          iconButton('chevron-left', '검색 결과로 돌아가기', back),
          t('BOOK INFORMATION', 10, mono: true, color: p.muted),
        ],
      ),
      gap(16),
      Center(child: cover(book, width: 145, height: 205, shadow: true)),
      gap(29),
      t(book.title, 23, weight: 700),
      if (book.id == 'boy') ...[
        gap(3),
        t('(10만부 판매 기념 한정판)', 13, color: p.muted),
      ],
      gap(12),
      t('${book.author} · ${book.publisher}', 13, color: p.muted),
      gap(23),
      rule(color: p.ink),
      gap(19),
      Row(
        children: [
          Expanded(child: infoStat('페이지', '128쪽')),
          Expanded(child: infoStat('출간일', '2020.04.20')),
          Expanded(child: infoStat('분류', '그림 에세이')),
        ],
      ),
      gap(20),
      rule(),
      gap(22),
      t('책 소개', 15, weight: 600),
      gap(10),
      t(
        '소년과 두더지, 여우와 말이 함께 길을 걸으며 나누는 이야기. 우정과 용기, 그리고 서로에게 건네는 작은 친절에 관한 책입니다.',
        14,
        color: p.muted,
      ),
      gap(18),
      actionText('알라딘에서 더보기', 'arrow-right', () => notice('도서 정보 출처: 알라딘')),
      gap(12),
    ],
  );
  Widget infoStat(String name, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      t(name, 10, color: p.muted),
      gap(5),
      t(value, 12, weight: 500),
    ],
  );

  Widget cardFront() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          iconButton('chevron-left', '서가로 돌아가기', back),
          t('CARD 1 / 2', 10, mono: true, color: p.muted),
        ],
      ),
      gap(16),
      if (p.dark)
        Container(
          width: double.infinity,
          height: 302,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 17,
                top: 20,
                child: t(
                  readingStatus,
                  33,
                  weight: 600,
                  color: const Color(0xff121212),
                ),
              ),
              Positioned(
                left: 18,
                top: 80,
                child: t(
                  'A BOOK\nIN MY LIFE',
                  11,
                  mono: true,
                  color: const Color(0xff121212),
                ),
              ),
              Positioned(
                right: 19,
                top: 35,
                child: cover(book, width: 130, height: 180, shadow: true),
              ),
              Positioned(left: 18, bottom: 48, child: stair()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: p.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: t(
                          book.reason,
                          12,
                          weight: 600,
                          color: const Color(0xff121212),
                        ),
                      ),
                      icon(
                        'arrow-right',
                        color: const Color(0xff121212),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
      else ...[
        Center(child: cover(book, width: 151, height: 205, shadow: true)),
        gap(14),
        Center(child: SizedBox(width: 270, child: obi(book))),
        gap(22),
      ],
      gap(p.dark ? 22 : 0),
      Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: p.dark ? 0 : 300),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.ink, width: 1.3),
            ),
            child: CustomPaint(
              painter: p.dark ? null : RuledPaper(p.line),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: t(book.title, 19, weight: 700)),
                        if (!p.dark) ...[
                          const SizedBox(width: 9),
                          Transform.rotate(
                            angle: -.075,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: p.blue, width: 1.5),
                                color: p.card,
                              ),
                              child: t(
                                '2026.08.03\n추가',
                                9,
                                mono: true,
                                color: p.blue,
                                align: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    gap(13),
                    t('${book.author} · ${book.publisher}', 12, color: p.muted),
                    gap(16),
                    statusChip(readingStatus),
                    gap(27),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => go('card-back'),
                            child: Row(
                              children: [
                                t('독서 카드 기록 ', 12, weight: 500),
                                t(
                                  '${3 + addedRecords.length}개',
                                  13,
                                  weight: 600,
                                  color: p.dark ? p.accent : p.orange,
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => go('record-options'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                t('추가하기', 12, weight: 600),
                                const SizedBox(width: 6),
                                icon('arrow-right', size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    gap(27),
                    t('이 책과 함께한 순간을 모아보세요.', 11, color: p.muted),
                  ],
                ),
              ),
            ),
          ),
          if (!p.dark)
            Positioned(
              top: -13,
              left: 15,
              child: Container(
                color: p.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: t('독서 카드', 10, weight: 600, color: p.card),
              ),
            ),
        ],
      ),
      gap(20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 18, height: 4, color: p.dark ? p.accent : p.ink),
          const SizedBox(width: 6),
          Container(width: 5, height: 4, color: p.line),
        ],
      ),
    ],
  );
  Widget stair() => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (int i = 0; i < 3; i++)
        Container(width: 28, height: 24.0 * (i + 1), color: p.gift),
    ],
  );
  Widget statusChip(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: p.dark ? p.blue : p.ink,
      borderRadius: BorderRadius.circular(p.dark ? 30 : 8),
    ),
    child: t(value, 11, weight: 600, color: Colors.white),
  );

  Widget cardBack({bool empty = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          iconButton('chevron-left', '독서카드 앞면', () => go('card-front')),
          t('CARD 2 / 2', 10, mono: true, color: p.muted),
        ],
      ),
      gap(16),
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 550),
        padding: const EdgeInsets.fromLTRB(18, 21, 18, 21),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.dark ? p.line : p.ink, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            t(book.title, 18, weight: 700),
            gap(8),
            t('2026.08.03 추가', 10, mono: true, color: p.muted),
            gap(7),
            t(book.reason, 11, color: p.muted),
            gap(20),
            rule(color: p.ink),
            if (empty) ...[
              gap(80),
              Center(child: icon('pencil', size: 34, color: p.muted)),
              gap(18),
              Center(child: t('첫 번째 기억을 남겨보세요', 16, serif: true, weight: 600)),
              gap(10),
              Center(
                child: t(
                  '책을 만난 날, 떠오른 생각, 마음에 든 문장.\n어떤 순간이든 좋아요.',
                  12,
                  color: p.muted,
                  align: TextAlign.center,
                ),
              ),
            ] else ...[
              timeline(
                '08.03',
                '읽고 싶은 책 추가',
                '하말넘많에서 소개한 이야기가 마음에 남았다.\n느리게 펼쳐보고 싶어서 서가에 담았다.',
                'bookmark',
                '저장',
              ),
              timeline(
                '08.05',
                '책 수령',
                '동네 서점에서 샀다.\n책을 직접 만져보고 고르는 시간이 좋았다.',
                'gift',
                '구매',
              ),
              timeline(
                '08.12',
                '읽기',
                '첫 장부터 좋다.\n오늘은 조금만, 천천히 읽어보기로.',
                'book-open',
                '읽는 중',
              ),
              for (final record in addedRecords)
                timeline('08.18', record.$1, record.$2, 'pencil', '기록'),
              if (addedRecords.isEmpty) ...[
                gap(18),
                t('책과의 시간은 계속됩니다.', 11, color: p.muted),
              ],
            ],
          ],
        ),
      ),
    ],
  );
  Widget timeline(
    String day,
    String title,
    String memo,
    String name,
    String category,
  ) => Container(
    padding: const EdgeInsets.symmetric(vertical: 23),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: p.line, width: .8)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              t('2026', 9, mono: true, color: p.muted),
              gap(3),
              t(day, 11, mono: true, color: p.dark ? p.accent : p.muted),
              gap(12),
              icon(name, size: 16, color: p.muted),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 7,
                runSpacing: 5,
                children: [
                  t(title, 15, weight: 600),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: p.dark ? p.blue : null,
                      border: Border.all(color: p.dark ? p.blue : p.line),
                      borderRadius: BorderRadius.circular(p.dark ? 20 : 6),
                    ),
                    child: t(
                      category,
                      9,
                      color: p.dark ? Colors.white : p.muted,
                    ),
                  ),
                ],
              ),
              gap(9),
              t(memo, 14, color: p.muted),
            ],
          ),
        ),
      ],
    ),
  );
  Widget circularRecordButton() => Semantics(
    label: '기록 추가',
    button: true,
    child: InkWell(
      onTap: () => go('record-options'),
      customBorder: const CircleBorder(),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(color: p.button, shape: BoxShape.circle),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon('plus', size: 18, color: p.onButton),
            t('기록 추가', 11, weight: 600, color: p.onButton),
          ],
        ),
      ),
    ),
  );

  Widget sheet(
    String title,
    List<Widget> children, {
    Widget? footer,
    String? subtitle,
  }) => Builder(
    builder: (context) => Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .84,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.dark ? const Color(0xff1b1b1b) : p.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          14,
          22,
          math.max(MediaQuery.paddingOf(context).bottom, 18) + 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: p.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            gap(12),
            Row(
              children: [
                Expanded(child: t(title, 23, weight: 600, serif: true)),
                iconButton('x', '닫기', back),
              ],
            ),
            if (subtitle != null) ...[gap(4), t(subtitle, 12, color: p.muted)],
            gap(21),
            ...children,
            if (footer != null) ...[gap(25), footer],
          ],
        ),
      ),
    ),
  );
  Widget sheetRow(
    String title,
    String subtitle,
    String name,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 21),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.line),
            ),
            child: Center(
              child: icon(name, size: 23, color: p.dark ? p.accent : p.ink),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                t(title, 15, weight: 600),
                gap(4),
                t(subtitle, 11, color: p.muted),
              ],
            ),
          ),
          icon('arrow-right', size: 18),
        ],
      ),
    ),
  );
  Widget addSheet() => sheet('책 추가', [
    sheetRow('책 제목으로 검색', '제목이나 저자 이름으로 찾아보세요', 'search', () => go('search')),
    sheetRow(
      '책 표지나 바코드 촬영',
      '눈앞의 책을 서가에 담아보세요',
      'scan-barcode',
      () => go('capture'),
    ),
    sheetRow('갤러리 사진 불러오기', '찍어둔 표지에서 책을 찾아드려요', 'image', () => go('gallery')),
  ], subtitle: '책을 만나는 세 가지 방법');

  Widget field(
    String title,
    String value, {
    String? hint,
    int lines = 1,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      t(title, 14, weight: 500),
      gap(9),
      TextFormField(
        key: ValueKey('$screen-$title'),
        initialValue: value,
        minLines: lines,
        maxLines: lines,
        maxLength: maxLength,
        onChanged: onChanged,
        style: p.text(16),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: p.text(14, color: p.muted),
          filled: true,
          fillColor: p.card,
          contentPadding: const EdgeInsets.all(15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: p.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: p.dark ? p.accent : p.ink,
              width: 1.4,
            ),
          ),
        ),
      ),
    ],
  );
  Widget createSheet() => sheet(
    '새 컬렉션',
    [
      field(
        '컬렉션 이름',
        '가을에 읽고 싶은 책',
        onChanged: (value) => collectionName = value,
      ),
      gap(23),
      field('한 줄 소개 · 선택', '선선한 날에 천천히 펼치고 싶은 이야기', lines: 2),
      gap(15),
      t('책은 컬렉션을 만든 뒤에도 추가할 수 있어요.', 11, color: p.muted),
    ],
    footer: button('컬렉션 만들기', () {
      if (collectionName == '인생 책 LIST') collectionName = '가을에 읽고 싶은 책';
      customCollections.add(collectionName);
      go('collection-edit');
    }, icon: 'plus'),
  );

  Widget saveSheet() => sheet(
    '책 저장',
    [
      Container(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            cover(book, width: 43, height: 59),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  t(book.title, 13, weight: 600, lines: 2),
                  gap(4),
                  t(book.author, 11, color: p.muted),
                ],
              ),
            ),
          ],
        ),
      ),
      rule(),
      gap(19),
      t('지금 이 책과 어떤 사이인가요?', 16, weight: 600),
      gap(13),
      Row(
        children: [
          saveTab('읽고 싶은 책', 'save-wish'),
          const SizedBox(width: 6),
          saveTab('읽고 있는 책', 'save-reading'),
          const SizedBox(width: 6),
          saveTab('읽은 책', 'save-read'),
        ],
      ),
      gap(24),
      if (screen == 'save-wish') ...[
        field(
          '읽고 싶은 이유',
          reasonDraft,
          hint: '어디서 만났나요? 무엇이 마음에 남았나요?',
          lines: 4,
          maxLength: 400,
          onChanged: (value) {
            setState(() => reasonDraft = value);
          },
        ),
        gap(7),
        Align(
          alignment: Alignment.centerRight,
          child: t('${reasonDraft.length}/400', 10, mono: true, color: p.muted),
        ),
      ] else ...[
        dateField('읽기 시작한 날', '2026.08.03'),
        if (screen == 'save-read') ...[
          gap(17),
          dateField('다 읽은 날', '2026.08.18'),
        ],
        gap(18),
        t('책과 함께한 시간을 독서카드에 남겨요.', 13, color: p.muted),
      ],
    ],
    footer: button('저장하기', () {
      readingStatus = switch (screen) {
        'save-wish' => '읽고 싶은 책',
        'save-read' => '다 읽은 책',
        _ => '읽는 중',
      };
      go('card-front');
    }, icon: 'bookmark'),
  );
  Widget saveTab(String title, String target) => Expanded(
    child: InkWell(
      onTap: () => go(target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        decoration: BoxDecoration(
          color: screen == target ? p.button : p.card,
          border: Border.all(color: screen == target ? p.button : p.line),
          borderRadius: BorderRadius.circular(p.dark ? 28 : 8),
        ),
        child: t(
          title,
          11,
          weight: 500,
          color: screen == target ? p.onButton : p.muted,
          align: TextAlign.center,
        ),
      ),
    ),
  );
  Widget dateField(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      t(title, 14, weight: 500),
      gap(9),
      InkWell(
        onTap: () => go('date-picker'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.line),
          ),
          child: Row(
            children: [
              t(value, 14, mono: true),
              const Spacer(),
              icon('calendar-days', size: 20, color: p.muted),
            ],
          ),
        ),
      ),
    ],
  );

  Widget duplicateDialog() => Builder(
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        MediaQuery.sizeOf(context).height * .24,
      ),
      child: Container(
        padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.ink, width: 1.3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon('bookmark', color: p.dark ? p.accent : p.orange),
                const Spacer(),
                iconButton('x', '닫기', back),
              ],
            ),
            gap(14),
            t('이미 서가에 있는 책이에요', 21, weight: 600, serif: true),
            gap(12),
            t('이 책의 독서카드로 이동해서\n새로운 기억을 이어서 남길까요?', 13, color: p.muted),
            gap(26),
            button('독서카드로 이동', () => go('card-front'), icon: 'arrow-right'),
          ],
        ),
      ),
    ),
  );

  Widget recordSheet() => sheet(
    '기록 추가',
    [
      recordGroup('독서 상태', [
        ('읽는 중', 'book-open'),
        ('읽고 싶은 책', 'bookmark'),
        ('다 읽은 책', 'circle-check'),
        ('쉬고 있음', 'circle-pause'),
      ]),
      gap(23),
      recordGroup('책 수령', [
        ('구매', 'bookmark'),
        ('도서관 대출', 'library'),
        ('선물 받음', 'gift'),
        ('이북', 'book-open'),
      ]),
      gap(23),
      recordGroup('순간 기록', [
        ('마음에 든 문장', 'quote'),
        ('누구랑 얘기함', 'message-circle'),
        ('다시 떠오름', 'repeat-2'),
        ('선물함', 'gift'),
        ('빌려줌', 'handshake'),
        ('또 만남', 'heart'),
      ]),
    ],
    footer: button('자유 기록', () {
      recordKind = '자유 기록';
      go('record-free');
    }, icon: 'pencil'),
  );
  Widget recordGroup(String title, List<(String, String)> options) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          t(title, 11, weight: 600, color: p.dark ? p.accent : p.muted),
          const SizedBox(width: 12),
          Expanded(child: rule()),
        ],
      ),
      gap(12),
      Wrap(
        spacing: 7,
        runSpacing: 8,
        children: options
            .map(
              (option) => InkWell(
                onTap: () {
                  recordKind = option.$1 == '구매' ? '직접 구매' : option.$1;
                  go(option.$1 == '마음에 든 문장' ? 'record-quote' : 'record-entry');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: p.card,
                    border: Border.all(color: p.line, width: 1.1),
                    borderRadius: BorderRadius.circular(p.dark ? 30 : 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon(option.$2, size: 14, color: p.muted),
                      const SizedBox(width: 6),
                      t(option.$1, 14, weight: 500),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
  Widget recordEntrySheet() {
    final quote = screen == 'record-quote';
    final free = screen == 'record-free';
    return sheet(
      recordKind,
      [
        Row(
          children: [
            icon('chevron-left', size: 15, color: p.muted),
            const SizedBox(width: 5),
            InkWell(
              onTap: () => go('record-options'),
              child: t('기록 종류 바꾸기', 13, color: p.muted),
            ),
          ],
        ),
        gap(20),
        dateField('날짜', date),
        gap(23),
        if (quote) ...[
          field(
            '마음에 든 문장',
            '함께 걷는 것만으로도\n길은 조금 덜 낯설어진다.',
            lines: 3,
            onChanged: (value) => memoDraft = value,
          ),
          gap(16),
          field('페이지 · 선택', '32'),
          gap(16),
          field(
            '메모 · 선택',
            '오늘의 나에게 필요한 말 같았다.',
            lines: 2,
            onChanged: (value) => memoDraft = value,
          ),
        ] else ...[
          t(
            free
                ? '어떤 기억을 남기고 싶나요?'
                : recordKind == '직접 구매'
                ? '어디서, 어떤 마음으로 데려왔나요?'
                : '이 순간에는 어떤 이야기가 있었나요?',
            13,
            weight: 600,
          ),
          gap(12),
          field(
            free ? '기록' : '메모 · 선택',
            free ? '책을 펼치기 전부터\n이미 마음에 남아 있던 이야기.' : memoDraft,
            lines: 4,
            onChanged: (value) => memoDraft = value,
          ),
        ],
      ],
      footer: button('기록 완료', () {
        addedRecords.add((recordKind, memoDraft));
        go('record-complete');
      }, icon: 'check'),
    );
  }

  Widget dateSheet() => sheet(
    '날짜 선택',
    [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          iconButton(
            'chevron-left',
            '이전 달',
            () => notice('시안의 기준 월은 2026년 8월입니다.'),
          ),
          t('2026년 8월', 18, weight: 600),
          iconButton(
            'chevron-right',
            '다음 달',
            () => notice('시안의 기준 월은 2026년 8월입니다.'),
          ),
        ],
      ),
      gap(15),
      Row(
        children: [
          for (final day in ['일', '월', '화', '수', '목', '금', '토'])
            Expanded(
              child: Center(child: t(day, 11, color: p.muted)),
            ),
        ],
      ),
      gap(9),
      for (int row = 0; row < 6; row++)
        Row(
          children: [
            for (int column = 0; column < 7; column++)
              Expanded(child: calendarDay(row * 7 + column - 5)),
          ],
        ),
    ],
    footer: button('$date 선택', () {
      final previous = history.isEmpty ? 'record-entry' : history.removeLast();
      setState(() => screen = previous);
    }, icon: 'check'),
  );
  Widget calendarDay(int day) => SizedBox(
    height: 44,
    child: day < 1 || day > 31
        ? null
        : InkWell(
            onTap: () => setState(
              () => date = '2026.08.${day.toString().padLeft(2, '0')}',
            ),
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: date.endsWith(day.toString().padLeft(2, '0'))
                    ? p.button
                    : null,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: t(
                  '$day',
                  14,
                  mono: true,
                  color: date.endsWith(day.toString().padLeft(2, '0'))
                      ? p.onButton
                      : p.ink,
                ),
              ),
            ),
          ),
  );

  Widget complete() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header('기억을 남겼어요', eyebrow: 'READING CARD / SAVED', previous: true),
      gap(38),
      Center(
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(color: p.button, shape: BoxShape.circle),
          child: Center(
            child: icon('check-check', color: p.onButton, size: 29),
          ),
        ),
      ),
      gap(27),
      Center(
        child: t(
          '책과의 시간이 한 장 더 쌓였어요.',
          17,
          serif: true,
          weight: 600,
          align: TextAlign.center,
        ),
      ),
      gap(35),
      Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.ink),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            t('2026.08.05', 11, mono: true, color: p.dark ? p.accent : p.muted),
            gap(18),
            t(recordKind, 19, weight: 600),
            gap(10),
            t(memoDraft, 14, color: p.muted),
            gap(22),
            rule(),
            gap(18),
            Row(
              children: [
                cover(book, width: 38, height: 51),
                const SizedBox(width: 11),
                Expanded(child: t(book.title, 12, weight: 500)),
              ],
            ),
          ],
        ),
      ),
    ],
  );
  Widget emptyState(
    String name,
    String title,
    String subtitle,
    VoidCallback? action,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 65),
    child: Column(
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.line),
            ),
            child: Center(
              child: icon(name, size: 34, color: p.dark ? p.accent : p.muted),
            ),
          ),
        ),
        gap(25),
        t(title, 20, weight: 600, serif: true, align: TextAlign.center),
        gap(13),
        t(subtitle, 13, color: p.muted, align: TextAlign.center),
        if (action != null) ...[
          gap(26),
          button('첫 컬렉션 만들기', action, icon: 'plus'),
        ],
      ],
    ),
  );

  Widget capture() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header('책을 비춰주세요', eyebrow: 'ADD / SCAN', previous: true),
      t('표지 또는 ISBN 바코드를 화면 안에 맞춰주세요.', 12, color: p.muted),
      gap(24),
      Container(
        height: 405,
        width: double.infinity,
        color: const Color(0xff292925),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -.09,
              child: cover(book, width: 171, height: 238, shadow: true),
            ),
            Container(
              width: 235,
              height: 303,
              decoration: BoxDecoration(
                border: Border.all(color: p.accent, width: 1.6),
              ),
            ),
            Positioned(
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                color: const Color(0xff121212),
                child: t('표지를 찾았어요', 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      gap(24),
      Center(child: icon('scan-barcode', size: 28, color: p.muted)),
      gap(10),
      Center(child: t('사진을 찍거나 바코드를 인식해 책을 찾아요.', 11, color: p.muted)),
    ],
  );
  Widget gallery() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header('사진에서 책 찾기', eyebrow: 'ADD / PHOTO', previous: true),
      t('책 표지가 잘 보이는 사진을 선택해주세요.', 12, color: p.muted),
      gap(24),
      Container(
        height: 245,
        width: double.infinity,
        color: p.card,
        child: Center(
          child: Transform.rotate(
            angle: -.04,
            child: cover(book, width: 145, height: 198, shadow: true),
          ),
        ),
      ),
      gap(22),
      Row(
        children: [
          t('최근 사진', 13, weight: 600),
          const Spacer(),
          t('1장 선택', 11, color: p.dark ? p.accent : p.orange),
        ],
      ),
      gap(12),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: previewBooks
              .take(6)
              .map(
                (value) => SizedBox(
                  width: (constraints.maxWidth - 16) / 3,
                  height: 98,
                  child: InkWell(
                    onTap: () => setState(() => book = value),
                    child: Stack(
                      children: [
                        Positioned.fill(child: cover(value)),
                        if (value == book)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 23,
                              height: 23,
                              decoration: BoxDecoration(
                                color: p.button,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: icon(
                                  'check',
                                  size: 14,
                                  color: p.onButton,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );

  void notice(String message) {
    // Product-only actions without a backend remain local in this offline preview.
    final context = scroll.position.context.notificationContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  void showDesignPicker() {
    final context = scroll.position.context.notificationContext;
    if (context == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.background,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              t('디자인 시안', 22, weight: 600),
              gap(18),
              button('A · 에디토리얼 라인', () {
                Navigator.pop(context);
                setState(() => mood = Mood.a);
              }),
              gap(10),
              button('C · 컬러 블록', () {
                Navigator.pop(context);
                setState(() => mood = Mood.c);
              }, secondary: true),
            ],
          ),
        ),
      ),
    );
  }
}
