import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final PageController shelfPages = PageController();
  late final PageController collectionPages = PageController(
    initialPage: collectionPage,
  );
  late int collectionPage = switch (widget.initialScreen) {
    'collection-next' => 1,
    'collection-end' => collectionTitles.length,
    _ => 0,
  };
  List<String> get collectionTitles => [
    ...customCollections.reversed,
    '인생 책 LIST',
    '새드엔딩',
    '한강의 문장들',
    '올해 읽고 싶은 책',
    '선물 받은 이야기',
    '다시 펼칠 책',
  ];
  bool get isCollectionScreen => [
    'collection',
    'collection-next',
    'collection-end',
    'collection-create',
  ].contains(screen);
  final GlobalKey<NavigatorState> previewNavigator =
      GlobalKey<NavigatorState>();
  int shelfPage = 0;
  int shelfPageCount = 1;
  bool get isShelfScreen =>
      ['shelf', 'shelf-empty', 'add-options'].contains(screen);

  void showPreview(String target, String style, {int page = 0}) {
    if (!previewScreens.containsKey(target)) {
      throw ArgumentError('Unknown screen: $target');
    }
    if (style != 'A' && style != 'C') {
      throw ArgumentError('Unknown style: $style');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      mood = style == 'C' ? Mood.c : Mood.a;
      shelfPage = page;
      screen = target;
      book = previewBooks.first;
      collectionPage = switch (target) {
        'collection-next' => 1,
        'collection-end' => 6,
        _ => 0,
      };
      collectionName =
          collectionTitles[collectionPage.clamp(
            0,
            collectionTitles.length - 1,
          )];
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
      if (collectionPages.hasClients) {
        collectionPages.jumpToPage(collectionPage);
      }
      if (shelfPages.hasClients) {
        shelfPages.jumpToPage(page.clamp(0, shelfPageCount - 1));
      }
    });
  }

  void go(String target) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      history.add(screen);
      screen = target;
    });
    restoreShelfPage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(0);
    });
  }

  void back() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => screen = history.isEmpty ? 'shelf' : history.removeLast());
    restoreShelfPage();
  }

  void restoreShelfPage() {
    final page = shelfPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isCollectionScreen && collectionPages.hasClients) {
        collectionPages.jumpToPage(collectionPage);
      }
      if (isShelfScreen && shelfPages.hasClients) {
        shelfPages.jumpToPage(page.clamp(0, shelfPageCount - 1));
      }
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    shelfPages.dispose();
    collectionPages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '모아북 디자인 시안',
    navigatorKey: previewNavigator,
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
                      child: isShelfScreen
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                12,
                                22,
                                12,
                              ),
                              child: shelf(empty: screen == 'shelf-empty'),
                            )
                          : isCollectionScreen
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                12,
                                22,
                                12,
                              ),
                              child: collectionPager(),
                            )
                          : SingleChildScrollView(
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
                          alpha: p.dark ? .62 : .55,
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
    'collection-next',
    'collection-end',
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
    Color? background,
    bool serif = false,
    bool mono = false,
    int? lines,
    TextAlign? align,
  }) => Text(
    value,
    maxLines: lines,
    overflow: lines == null ? null : TextOverflow.ellipsis,
    textAlign: align,
    style: p.text(size, weight: weight, color: color, serif: serif, mono: mono),
  );
  Widget gap(double height) => SizedBox(height: height);
  Widget rule({Color? color, double width = 1.5}) =>
      Container(height: width, color: color ?? (p.dark ? p.line : p.ink));
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
      borderRadius: BorderRadius.zero,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 44 : 54),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: secondary ? p.card : p.button,
          borderRadius: BorderRadius.zero,
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
      if (!previous && hasNav) ...[
        shelfToolbar(eyebrow ?? 'MOABOOK'),
        gap(3),
      ] else if (!previous && eyebrow != null) ...[
        label(eyebrow),
        gap(3),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: t(
              title,
              p.dark ? 36 : 28,
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
      rule(color: p.ink, width: 1.5),
      gap(18),
    ],
  );

  Widget navigation() => Builder(
    builder: (context) => Container(
      color: p.dark ? p.accent : p.background,
      child: Container(
        decoration: BoxDecoration(
          border: p.dark
              ? null
              : Border(top: BorderSide(color: p.ink, width: 1.5)),
        ),
        child: Row(
          children: [
            navItem(
              '기본 서가',
              'library',
              screen.startsWith('shelf') || screen == 'add-options',
              () => go('shelf'),
              bottomInset: MediaQuery.paddingOf(context).bottom,
            ),
            navItem(
              '주제 서가',
              'layers',
              !screen.startsWith('shelf') && screen != 'add-options',
              () {
                collectionPage = 0;
                collectionName = collectionTitles.first;
                go('collection');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (collectionPages.hasClients) collectionPages.jumpToPage(0);
                });
              },
              bottomInset: MediaQuery.paddingOf(context).bottom,
            ),
          ],
        ),
      ),
    ),
  );
  Widget navItem(
    String title,
    String name,
    bool active,
    VoidCallback onTap, {
    double bottomInset = 0,
  }) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 78 + bottomInset,
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: p.dark ? (active ? p.background : p.accent) : p.background,
          border: !p.dark && active
              ? Border(top: BorderSide(color: p.orange, width: 3))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon(
              active ? '$name-active' : name,
              size: 22,
              color: p.dark
                  ? (active ? p.accent : p.background.withValues(alpha: .45))
                  : (active ? p.ink : p.muted),
            ),
            gap(5),
            t(
              title,
              13,
              weight: active ? (p.dark ? 600 : 700) : 500,
              color: p.dark
                  ? (active ? p.accent : p.background.withValues(alpha: .45))
                  : (active ? p.ink : p.muted),
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
      type == 'WISH' || (!p.dark && (type == '선물' || type == '추천'))
      ? Colors.white
      : const Color(0xff1b1b1b);

  Widget cover(
    PreviewBook value, {
    double? width,
    double? height,
    bool shadow = false,
  }) => SizedBox(
    width: width,
    height: height,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        if (shadow)
          Positioned(
            left: 6,
            top: 6,
            right: -6,
            bottom: -6,
            child: ColoredBox(color: p.dark ? const Color(0xff121212) : p.ink),
          ),
        Positioned.fill(
          child: Container(
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                color: p.dark ? const Color(0xff121212) : p.ink,
                width: shadow && p.dark ? 3 : 1.5,
              ),
            ),
            child: value.demo
                ? ColoredBox(
                    color: const Color(0xffd4d4d4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: t(
                          value.title,
                          16,
                          weight: 600,
                          color: const Color(0xff1b1b1b),
                          align: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : Image.asset(
                    value.cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => ColoredBox(
                      color: const Color(0xffd4d4d4),
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
        ),
      ],
    ),
  );
  Widget obi(PreviewBook value, {bool short = false, bool front = false}) =>
      value.reason.isEmpty
      ? const SizedBox.shrink()
      : Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: p.dark ? 28 : 26),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: value.reason.isEmpty
                ? (p.dark ? const Color(0xff2a2a2a) : Colors.transparent)
                : reasonColor(value.reasonType),
            border: p.dark ? null : Border.all(color: p.ink, width: 1.5),
          ),
          child: Text(
            value.reason.isEmpty ? (p.dark ? '—' : '저장 이유 없음') : value.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: p.text(
              front ? 12 : 10.5,
              height: 1.25,
              weight: value.reason.isEmpty ? 400 : 600,
              color: value.reason.isEmpty
                  ? p.muted
                  : reasonTextColor(value.reasonType),
            ),
          ),
        );

  Widget shelfToolbar(String eyebrow, {String? count}) => Row(
    children: [
      Expanded(
        child: t(eyebrow, 10, mono: true, color: p.dark ? p.accent : p.muted),
      ),
      if (count != null) ...[
        t(count, 11, mono: true, color: p.muted),
        const SizedBox(width: 8),
      ],
      iconButton('settings-2', '시안 설정', showDesignPicker),
    ],
  );

  static const spineWidths = [
    38.0,
    26.0,
    22.0,
    35.0,
    28.0,
    34.0,
    24.0,
    31.0,
    26.0,
  ];
  static const spineHeights = [1.0, .90, .96, .86, .93, .98, .89, .95, .91];
  List<List<PreviewBook>> shelfRows(double width) {
    final rows = <List<PreviewBook>>[];
    var row = <PreviewBook>[];
    var used = 0.0;
    for (var i = 0; i < shelfPreviewBooks.length; i++) {
      final needed =
          spineWidths[i % spineWidths.length] + (row.isEmpty ? 0 : 5);
      if (row.isNotEmpty && used + needed > width) {
        rows.add(row);
        row = [];
        used = 0;
      }
      used += spineWidths[i % spineWidths.length] + (row.isEmpty ? 0 : 5);
      row.add(shelfPreviewBooks[i]);
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  Widget shelf({bool empty = false}) => LayoutBuilder(
    builder: (context, constraints) {
      final rows = shelfRows(constraints.maxWidth);
      final count = (rows.length / 3).ceil();
      shelfPageCount = count;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shelfToolbar(
            'MOABOOK / MY BOOKS',
            count: empty ? '0권' : '${shelfPreviewBooks.length}권',
          ),
          Row(
            children: [
              Expanded(
                child: t(
                  '서가',
                  p.dark ? 36 : 28,
                  weight: p.dark ? 600 : 700,
                  serif: true,
                  color: p.dark ? p.accent : p.ink,
                ),
              ),
              actionText('책 추가', 'plus', () => go('add-options')),
              iconButton(
                'download',
                '서가 이미지 저장',
                () => notice('서가 이미지 저장 시안입니다.'),
              ),
            ],
          ),
          gap(12),
          rule(color: p.ink),
          gap(16),
          if (empty)
            Expanded(
              child: Center(
                child: emptyState(
                  'book-open',
                  '어떤 책이 떠오르나요?',
                  '읽고 싶은 책도, 오래 간직한 책도.\n첫 번째 책을 서가에 꽂아보세요.',
                  null,
                ),
              ),
            )
          else ...[
            Expanded(
              child: PageView.builder(
                key: const Key('shelf-pager'),
                controller: shelfPages,
                itemCount: count,
                onPageChanged: (page) => setState(() => shelfPage = page),
                itemBuilder: (context, page) => Column(
                  children: [
                    for (var row = 0; row < 3; row++) ...[
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, space) => bookShelf(
                            page * 3 + row < rows.length
                                ? rows[page * 3 + row]
                                : [],
                            space.maxHeight,
                            key: ValueKey('shelf-$page-row-$row'),
                          ),
                        ),
                      ),
                      if (row != 2) gap(16),
                    ],
                  ],
                ),
              ),
            ),
            gap(10),
            Center(
              child: Text(
                '${shelfPage.clamp(0, count - 1) + 1} / $count',
                key: const Key('shelf-page-indicator'),
                style: p.text(11, mono: true, color: p.muted),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget bookShelf(List<PreviewBook> books, double height, {Key? key}) =>
      Column(
        key: key,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < books.length; i++) ...[
                  if (i != 0) const SizedBox(width: 5),
                  Builder(
                    builder: (context) {
                      final value = books[i];
                      final n = shelfPreviewBooks.indexOf(value);
                      final foreground = p.dark
                          ? const Color(0xffdddddd)
                          : p.ink;
                      return Semantics(
                        label: '${value.title}, 독서카드 열기',
                        button: true,
                        child: InkWell(
                          key: ValueKey('spine-${value.id}'),
                          onTap: () {
                            book = value;
                            go('card-front');
                          },
                          child: Container(
                            width: spineWidths[n % spineWidths.length],
                            height:
                                (height - (p.dark ? 4 : 3)) *
                                spineHeights[n % spineHeights.length],
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: p.dark
                                  ? [
                                      const Color(0xff2e2e2e),
                                      const Color(0xff3a3a3a),
                                      const Color(0xff262626),
                                    ][n % 3]
                                  : const Color(0xffe3ded1),
                              border: Border.all(
                                color: p.dark ? Colors.transparent : p.ink,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                gap(8),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: VerticalSpineTitle(
                                      value.title,
                                      style: p.text(
                                        11,
                                        weight: p.dark ? 500 : 600,
                                        height: 1,
                                        color: foreground,
                                      ),
                                    ),
                                  ),
                                ),
                                gap(8),
                                if (value.reason.isNotEmpty)
                                  Container(
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: reasonColor(value.reasonType),
                                      border: p.dark
                                          ? null
                                          : Border(
                                              top: BorderSide(
                                                color: p.ink,
                                                width: 1.5,
                                              ),
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          Container(height: p.dark ? 4 : 3, color: p.dark ? p.accent : p.ink),
        ],
      );

  Widget collectionPager() => Column(
    children: [
      Expanded(
        child: PageView.builder(
          key: const Key('collection-pager'),
          controller: collectionPages,
          itemCount: collectionTitles.length + 1,
          onPageChanged: (index) => setState(() {
            collectionPage = index;
            if (index < collectionTitles.length) {
              collectionName = collectionTitles[index];
            }
          }),
          itemBuilder: (context, index) => SingleChildScrollView(
            child: index == collectionTitles.length
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      shelfToolbar('COLLECTION'),
                      Row(
                        children: [
                          Expanded(child: t('새 책장 만들기', 28, weight: 600)),
                          iconButton(
                            'list',
                            '주제 서가 목록',
                            () => go('collections'),
                          ),
                        ],
                      ),
                      gap(16),
                      rule(color: p.ink),
                      emptyState(
                        'plus',
                        '새로운 주제로 모아보세요',
                        '나만의 책장을 하나 더 만들어보세요.',
                        () => go('collection-create'),
                        actionLabel: '새 책장 만들기',
                      ),
                    ],
                  )
                : collection(title: collectionTitles[index], index: index),
          ),
        ),
      ),
      gap(12),
      Text(
        '${collectionPage + 1} / ${collectionTitles.length + 1}',
        key: const Key('collection-page-indicator'),
        style: p.text(12, color: p.muted),
      ),
    ],
  );

  Widget collection({String? title, int index = 0}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      shelfToolbar('COLLECTION / ${(index + 1).toString().padLeft(2, '0')}'),
      Row(
        children: [
          Expanded(
            child: t(
              title ?? collectionName,
              p.dark ? 36 : 28,
              serif: true,
              weight: 600,
              color: p.dark ? p.accent : p.ink,
              lines: 2,
            ),
          ),
          IconButton(
            key: const Key('collection-picker'),
            tooltip: '주제 서가 목록',
            onPressed: () => go('collections'),
            icon: icon('list', size: 24, color: p.dark ? p.accent : p.ink),
          ),
        ],
      ),
      gap(16),
      rule(color: p.ink, width: 1.5),
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
      booksGrid(collectionPreviewBooks(index)),
    ],
  );

  List<PreviewBook> collectionPreviewBooks(int index) => [
    for (var i = 0; i < previewBooks.length; i++)
      if (i % 3 == index % 3)
        previewBooks[(i + index) % previewBooks.length]
      else
        PreviewBook(
          previewBooks[(i + index) % previewBooks.length].id,
          previewBooks[(i + index) % previewBooks.length].title,
          previewBooks[(i + index) % previewBooks.length].author,
          previewBooks[(i + index) % previewBooks.length].publisher,
          '',
          '',
        ),
  ];
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
        runSpacing: editing ? 19 : 12,
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
                          if (!editing && value.reason.isNotEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: itemWidth * .12,
                              child: obi(value),
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
                                  shape: BoxShape.rectangle,
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
      collectionPage = collectionTitles.indexOf(title);
      go('collection');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (collectionPages.hasClients) {
          collectionPages.jumpToPage(collectionPage);
        }
      });
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
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: p.ink, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
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
      Center(child: cover(book, width: 145, height: 205)),
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

  void flipCard(String target) {
    setState(() => screen = target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(0);
    });
  }

  double cardSwipeDistance = 0;
  Widget flippableCard(Widget child, {required bool front}) => GestureDetector(
    key: ValueKey(front ? 'card-front-surface' : 'card-back-surface'),
    behavior: HitTestBehavior.opaque,
    onTap: front ? () => flipCard('card-back') : null,
    onHorizontalDragStart: (_) => cardSwipeDistance = 0,
    onHorizontalDragUpdate: (event) => cardSwipeDistance += event.delta.dx,
    onHorizontalDragEnd: (event) {
      if (cardSwipeDistance.abs() >= 48 ||
          (event.primaryVelocity ?? 0).abs() >= 250) {
        flipCard(front ? 'card-back' : 'card-front');
      }
      cardSwipeDistance = 0;
    },
    child: child,
  );

  Widget cardFront() => flippableCard(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [iconButton('chevron-left', '서가로 돌아가기', back)],
        ),
        gap(16),
        if (p.dark)
          Container(
            width: double.infinity,
            height: 302,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.orange,
              borderRadius: BorderRadius.zero,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 17,
                  top: 20,
                  child: t(
                    readingStatus,
                    36,
                    weight: 600,
                    color: const Color(0xff121212),
                  ),
                ),
                Positioned(
                  right: 19,
                  top: 35,
                  child: cover(book, width: 130, height: 184, shadow: true),
                ),
                Positioned(left: 40, bottom: 0, child: stair()),
                Positioned(
                  left: 140,
                  top: 150,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: 90,
                  top: 210,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (book.reason.isNotEmpty)
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
                              15,
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
          Center(
            child: SizedBox(
              width: 160,
              height: 226,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  cover(book, width: 160, height: 226, shadow: true),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 30,
                    child: obi(book, front: true),
                  ),
                ],
              ),
            ),
          ),
          gap(32),
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
                color: p.dark ? p.background : p.card,
                borderRadius: BorderRadius.zero,
                border: p.dark ? null : Border.all(color: p.ink, width: 1.5),
              ),
              child: CustomPaint(
                painter: null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: t(
                              book.title,
                              22,
                              weight: p.dark ? 600 : 700,
                              background: p.dark ? null : p.card,
                            ),
                          ),
                        ],
                      ),
                      gap(13),
                      Row(
                        children: [
                          Expanded(
                            child: t(
                              '${book.author} · ${book.publisher}${p.dark ? ' · 2026.08.03 추가' : ''}',
                              12,
                              background: p.dark ? null : p.card,
                              color: p.muted,
                            ),
                          ),
                        ],
                      ),
                      gap(16),
                      t(readingStatus, 14, weight: 500, color: p.muted),
                      gap(27),
                      Container(
                        padding: const EdgeInsets.only(
                          top: 8,
                          bottom: 8,
                          left: 4,
                          right: 4,
                        ),
                        decoration: BoxDecoration(
                          border: p.dark
                              ? Border.all(color: p.ink, width: 1.5)
                              : Border(
                                  top: BorderSide(color: p.ink, width: 1.5),
                                ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => flipCard('card-back'),
                                child: Row(
                                  children: [
                                    t('독서 카드 기록 ', 12, weight: 500),
                                    Container(
                                      color: p.dark ? p.accent : null,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: p.dark ? 8 : 0,
                                        vertical: p.dark ? 2 : 0,
                                      ),
                                      child: t(
                                        '${3 + addedRecords.length}개',
                                        13,
                                        weight: 600,
                                        color: p.dark ? p.background : p.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => go('record-options'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
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
                  child: t('독서 카드', 11, weight: 500, mono: true, color: p.card),
                ),
              ),
          ],
        ),
      ],
    ),
    front: true,
  );
  Widget stair() => SvgPicture.asset(
    'assets/design_preview/reference/c-stair.svg',
    width: 150,
    height: 170,
  );
  Widget statusChip(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: p.dark ? p.blue : p.ink,
      borderRadius: BorderRadius.zero,
    ),
    child: t(value, 11, weight: 600, color: Colors.white),
  );

  Widget cardBack({bool empty = false}) => flippableCard(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            iconButton('chevron-left', '독서카드 앞면', () => flipCard('card-front')),
          ],
        ),
        gap(16),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 550),
          padding: p.dark
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(18, 21, 18, 21),
          decoration: BoxDecoration(
            color: p.dark ? p.background : p.card,
            borderRadius: BorderRadius.zero,
            border: p.dark ? null : Border.all(color: p.ink, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: p.dark ? const EdgeInsets.all(16) : EdgeInsets.zero,
                color: p.dark ? p.orange : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    t(
                      book.title,
                      p.dark ? 17 : 16,
                      weight: p.dark ? 600 : 700,
                      color: p.dark ? p.background : p.ink,
                    ),
                    gap(8),
                    t(
                      '2026.08.03 추가',
                      11,
                      color: p.dark ? p.background : p.muted,
                    ),
                    gap(7),
                    t(book.reason, 11, color: p.dark ? p.background : p.muted),
                  ],
                ),
              ),
              gap(14),
              if (!p.dark) rule(color: p.ink),
              if (empty) ...[
                gap(80),
                Center(child: icon('pencil', size: 34, color: p.muted)),
                gap(18),
                Center(
                  child: t('첫 번째 기억을 남겨보세요', 16, serif: true, weight: 600),
                ),
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
    ),
    front: false,
  );
  Widget timeline(
    String day,
    String title,
    String memo,
    String name,
    String category,
  ) => Container(
    margin: EdgeInsets.only(bottom: p.dark ? 10 : 0),
    padding: EdgeInsets.symmetric(vertical: 14, horizontal: p.dark ? 14 : 0),
    decoration: BoxDecoration(
      color: p.dark ? p.card : null,
      border: p.dark
          ? null
          : Border(bottom: BorderSide(color: p.line, width: 1)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: p.dark ? 66 : 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [t(day, 12, color: p.muted)],
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
                children: [t(title, 15, weight: 600)],
              ),
              gap(9),
              t(
                memo,
                14,
                color: p.dark
                    ? const Color(0xffcfcfcf)
                    : const Color(0xff333333),
              ),
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
      customBorder: const RoundedRectangleBorder(),
      child: Container(
        width: p.dark ? 68 : 70,
        height: p.dark ? 68 : 70,
        decoration: BoxDecoration(color: p.button, shape: BoxShape.rectangle),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            t(
              '기록\n추가',
              13,
              weight: 600,
              color: p.onButton,
              align: TextAlign.center,
            ),
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
        borderRadius: BorderRadius.zero,
        border: Border(
          top: BorderSide(
            color: p.dark ? p.accent : p.ink,
            width: p.dark ? 4 : 2,
          ),
        ),
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
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            gap(12),
            Row(
              children: [
                Expanded(child: t(title, 16, weight: 600)),
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
              borderRadius: BorderRadius.zero,
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
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: p.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
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
      collectionPage = 0;
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
          borderRadius: BorderRadius.zero,
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
            borderRadius: BorderRadius.zero,
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
          borderRadius: BorderRadius.zero,
          border: Border.all(color: p.ink, width: 1.5),
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
      t(title, 11, weight: 500, mono: true, color: p.dark ? p.accent : p.ink),
      if (!p.dark) ...[gap(4), rule()],
      gap(6),
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
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: p.card,
                    border: Border.all(
                      color: p.dark ? const Color(0xff555555) : p.ink,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon(option.$2, size: 14, color: p.muted),
                      const SizedBox(width: 6),
                      t(option.$1, 13, weight: 500),
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
                shape: BoxShape.rectangle,
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
          decoration: BoxDecoration(color: p.button, shape: BoxShape.rectangle),
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
          borderRadius: BorderRadius.zero,
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
    VoidCallback? action, {
    String actionLabel = '첫 컬렉션 만들기',
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 65),
    child: Column(
      children: [
        Center(child: icon(name, size: 40, color: p.dark ? p.accent : p.muted)),
        gap(25),
        t(title, 20, weight: 600, serif: true, align: TextAlign.center),
        gap(13),
        t(subtitle, 13, color: p.muted, align: TextAlign.center),
        if (action != null) ...[
          gap(26),
          button(actionLabel, action, icon: 'plus'),
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
              child: cover(book, width: 171, height: 238),
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
            child: cover(book, width: 145, height: 198),
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
                                shape: BoxShape.rectangle,
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
    final context = previewNavigator.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  void showDesignPicker() {
    final context = previewNavigator.currentContext;
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
