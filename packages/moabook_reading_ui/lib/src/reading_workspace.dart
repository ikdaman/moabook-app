import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moabook_reading/moabook_reading.dart';
import 'widgets/policy_widgets.dart';
import 'widgets/sliding_sheet_overlay.dart';
import 'widgets/shelf_section_transition.dart';
import 'design_system.dart';
import 'sample_data.dart';

part 'reading_live.dart';

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

class ReadingWorkspace extends StatefulWidget {
  const ReadingWorkspace({
    super.key,
    required this.initialMood,
    required this.initialScreen,
    this.gateway,
    this.embedded = false,
    this.initialBookId,
    this.onSettings,
    this.onCapture,
    this.onOpenLink,
    this.onExport,
  });
  final Mood initialMood;
  final String initialScreen;
  final ReadingGateway? gateway;
  final bool embedded;
  final String? initialBookId;
  final VoidCallback? onSettings;
  final Future<ReadingBook?> Function()? onCapture;
  final Future<void> Function(String url)? onOpenLink;
  final Future<void> Function(ReadingImageExport request)? onExport;
  @override
  State<ReadingWorkspace> createState() => ReadingWorkspaceState();
}

class ReadingWorkspaceState extends State<ReadingWorkspace> {
  late Mood mood = widget.initialMood;
  late String screen = widget.initialScreen;
  DesignPalette get p => DesignPalette(mood);
  bool get isLive => widget.gateway != null;
  ReadingGateway get gateway => widget.gateway!;
  bool shelfLoading = false, collectionsLoading = false, cardLoading = false;
  bool shelfLoaded = false, collectionsLoaded = false;
  bool isSaving = false, isSearching = false, recordWriteUncertain = false;
  String? shelfError,
      collectionsError,
      cardError,
      recordsError,
      searchError,
      operationError;
  bool creationWriteUncertain = false, selectingMedia = false;
  bool exporting = false;
  // Checkpoints survive navigation so partial writes are not repeated.
  final Map<String, String> pendingSavedBooks = {};
  final Set<String> uncertainBookWrites = {};
  final Set<String> initializedSavedBooks = {};
  final Set<String> uncertainInitialBookWrites = {};

  int collectionsRequest = 0;
  void _update(VoidCallback action) {
    if (mounted) setState(action);
  }

  final Map<String, int> collectionRequests = {};
  int totalShelfCount = 0, shelfRequest = 0, cardRequest = 0, searchRequest = 0;
  final Map<String, ReadingBook> catalog = {};
  final Map<String, ReadingCard> cards = {};
  final Map<String, ReadingCollectionSummary> collectionSummaries = {};
  final Set<String> loadedCollections = {}, loadingCollections = {};
  final Set<String> staleCollections = {};
  final Map<String, String> collectionErrors = {};
  final Set<String> loadedRecordBooks = {};
  List<ReadingBook> remoteSearchResults = [];
  int remoteSearchPage = 0;
  int? remoteSearchTotalCount;
  bool remoteSearchHasMore = false, loadingMoreSearch = false;
  String activeSearchQuery = '';
  String? searchMoreError;
  Future<void> reloadFromServer() => refreshRemote();
  PreviewBook selectedBook = previewBooks.first;
  final Map<String, PreviewBook> library = {
    for (final value in shelfPreviewBooks) value.id: value,
  };
  final Map<String, ReadingJournal> journals = {};
  final Map<String, DateTime> bookAddedDates = {};
  DateTime get bookAddedDate =>
      cards[selectedBook.id]?.createdDate ??
      bookAddedDates[selectedBook.id] ??
      DateTime(2026, 8, 3);
  late List<ReadingCollection> collectionData = sampleCollections();
  ReadingCollection? editingCollection;
  String collectionNameDraft = '';
  String? targetCollectionId;
  int? targetCollectionSlot;
  final GlobalKey shelfCaptureKey = GlobalKey();
  List<List<PreviewBook>> renderedShelfRows = [];
  String searchQuery = '소년';
  String reasonDraft = '';
  String memoDraft = '';
  ReadingCategory bookSaveCategory = ReadingCategory.todo;
  ReadingCategory? recordStatusDraft;
  ReadingCategory? categoryBeforeFree;
  ReadingCategory get currentBookStatus =>
      (isLive && !loadedRecordBooks.contains(selectedBook.id)
          ? cards[selectedBook.id]?.status
          : journal.status) ??
      ReadingCategory.todo;
  ReadingCategory get selectedRecordStatus =>
      recordStatusDraft ?? currentBookStatus;
  ReadingCategory recordCategory = ReadingCategory.buy;
  DateTime recordDate = readingDay(DateTime.now());
  DateTime startedDate = readingDay(DateTime.now());
  DateTime finishedDate = readingDay(DateTime.now());
  DateTime calendarSelection = readingDay(DateTime.now());
  String dateTarget = 'record';
  ReadingRecord? completedRecord;
  int localRecordId = 0;
  final List<String> history = [];
  final ScrollController scroll = ScrollController();
  final PageController shelfPages = PageController();
  late final PageController collectionPages = PageController(
    initialPage: collectionPage,
  );
  late int collectionPage = switch (widget.initialScreen) {
    'collection-next' => 1,
    'collection-end' => collectionData.length,
    _ => 0,
  };
  List<String> get collectionTitles =>
      collectionData.map((c) => c.name).toList();
  ReadingCollection get currentCollection =>
      collectionData[collectionPage.clamp(0, collectionData.length - 1)];
  String get collectionName => currentCollection.name;
  String get recordKind => recordCategory.label;
  String get readingStatus =>
      isLive && !loadedRecordBooks.contains(selectedBook.id)
      ? (recordsError == null ? '기록 확인 중' : '기록 확인 필요')
      : journal.status?.label ?? '기록 없음';
  int? get recordCount => !isLive || loadedRecordBooks.contains(selectedBook.id)
      ? journal.records.length
      : cards[selectedBook.id]?.recordCount;
  PreviewBook get book => isLive
      ? selectedBook
      : selectedBook.withReason(displayedReason(selectedBook));
  set book(PreviewBook value) => selectedBook = value;
  ReadingJournal get journal => journalFor(selectedBook);
  String get date => formatDate(recordDate);
  List<PreviewBook> get shelfBooks => library.values
      .map((value) => isLive ? value : value.withReason(displayedReason(value)))
      .toList();

  String displayedReason(PreviewBook value) {
    final records = journalFor(value);
    return records.records.any((r) => r.category == ReadingCategory.todo)
        ? records.reason ?? ''
        : value.reason;
  }

  static String formatDate(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

  List<ReadingCollection> sampleCollections() => [
    for (var i = 0; i < 6; i++)
      ReadingCollection(
        id: 'collection-$i',
        name: [
          '인생 책 LIST',
          '새드엔딩',
          '한강의 문장들',
          '올해 읽고 싶은 책',
          '선물 받은 이야기',
          '다시 펼칠 책',
        ][i],
        slots: [
          for (var slot = 0; slot < 9; slot++)
            (slot + i) % 3 == 1 ? null : previewBooks[(slot + i) % 9].id,
        ],
      ),
  ];

  ReadingJournal journalFor(PreviewBook value) =>
      journals.putIfAbsent(value.id, () {
        if (isLive || !library.containsKey(value.id)) return ReadingJournal();
        return ReadingJournal([
          ReadingRecord(
            id: '${value.id}-todo',
            category: ReadingCategory.todo,
            date: DateTime(2026, 8, 3),
            memo: value.reason,
          ),
          ReadingRecord(
            id: '${value.id}-buy',
            category: ReadingCategory.buy,
            date: DateTime(2026, 8, 5),
            memo: '동네 서점에서 만난 책.',
          ),
          ReadingRecord(
            id: '${value.id}-reading',
            category: ReadingCategory.inProgress,
            date: DateTime(2026, 8, 12),
            memo: '오늘은 조금만, 천천히 읽어보기로.',
          ),
        ]);
      });

  @override
  void initState() {
    super.initState();
    scroll.addListener(_loadSearchNearEnd);
    if (isLive) {
      library.clear();
      collectionData = [];
      searchQuery = '';
      selectedBook = ReadingBook(
        widget.initialBookId ?? '',
        '',
        '',
        '',
        '',
        '',
      );
      unawaited(refreshRemote());
      if (widget.initialBookId != null) {
        unawaited(loadRemoteCard(widget.initialBookId!));
      }
    } else {
      configureScreen(screen);
    }
  }

  void _loadSearchNearEnd() {
    if (!isLive ||
        screen != 'search' ||
        searchMoreError != null ||
        !scroll.hasClients ||
        scroll.position.extentAfter > 320) {
      return;
    }
    unawaited(loadMoreRemoteBooks());
  }

  void _checkSearchAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSearchNearEnd();
    });
  }

  @override
  void didUpdateWidget(covariant ReadingWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (isLive &&
        (oldWidget.initialScreen != widget.initialScreen ||
            oldWidget.initialBookId != widget.initialBookId)) {
      history.clear();
      screen = widget.initialScreen;
      ++cardRequest;
      if (widget.initialBookId != null) {
        selectedBook = ReadingBook(widget.initialBookId!, '', '', '', '', '');
        unawaited(loadRemoteCard(widget.initialBookId!));
      }
      if (isCollectionScreen && collectionData.isNotEmpty) {
        unawaited(loadRemoteCollection(currentCollection.id));
      }
    }
  }

  void configureScreen(String target) {
    bookSaveCategory = switch (target) {
      'save-reading' => ReadingCategory.inProgress,
      'save-read' => ReadingCategory.done,
      _ => ReadingCategory.todo,
    };
    recordStatusDraft = null;
    recordCategory = switch (target) {
      'record-quote' => ReadingCategory.sentence,
      'record-free' => ReadingCategory.free,
      'record-wish' => ReadingCategory.todo,
      'record-options' => currentBookStatus,
      _ => ReadingCategory.buy,
    };
    if (target == 'collections-empty') {
      collectionData = [];
    }
    if (target == 'collection-empty') {
      collectionData.add(
        ReadingCollection(id: 'new-collection', name: '가을에 읽고 싶은 책'),
      );
      collectionPage = collectionData.length - 1;
    }
    if (target == 'collection-duplicate') {
      targetCollectionId = currentCollection.id;
    }
    if (target == 'collection-edit') {
      editingCollection = currentCollection;
      collectionNameDraft = currentCollection.name;
    }
    if (target == 'card-empty') journals[selectedBook.id] = ReadingJournal();
    if (target.startsWith('save-')) selectedBook = newPreviewBook;
    if (target == 'record-complete') {
      completedRecord = ReadingRecord(
        id: 'completed-example',
        category: recordCategory,
        date: recordDate,
        memo: '동네 서점에서 만난 책.',
      );
    }
  }

  void startAddingToCollection({int? slotIndex}) {
    if (currentCollection.isFull) return;
    targetCollectionId = currentCollection.id;
    targetCollectionSlot = slotIndex;
    go('add-options');
  }

  void openBook(PreviewBook value) {
    selectedBook = value;
    go('card-front');
    if (isLive) unawaited(loadRemoteCard(value.id));
  }

  void beginEditCollection() {
    if (isLive) {
      unawaited(beginRemoteCollectionEdit());
      return;
    }
    editingCollection = currentCollection;
    collectionNameDraft = currentCollection.name;
    go('collection-edit');
  }

  void saveCollectionEdit() {
    if (isLive) {
      unawaited(saveRemoteCollectionEdit());
      return;
    }
    if (collectionNameDraft.trim().isEmpty || editingCollection == null) return;
    final index = collectionData.indexWhere(
      (c) => c.id == editingCollection!.id,
    );
    setState(() {
      collectionData[index] = editingCollection!.rename(collectionNameDraft);
      editingCollection = null;
      screen = history.isEmpty ? 'collection' : history.removeLast();
    });
    restoreShelfPage();
  }

  void confirmBook() {
    if (isLive) {
      unawaited(confirmRemoteBook());
      return;
    }
    if (targetCollectionId != null) {
      final target = collectionData.firstWhere(
        (c) => c.id == targetCollectionId,
      );
      if (target.contains(selectedBook.id)) {
        go('collection-duplicate');
        return;
      }
      if (target.isFull) {
        notice('컬렉션에는 9권까지 담을 수 있어요.');
        return;
      }
      if (library.containsKey(selectedBook.id)) {
        addBookToCollection();
        return;
      }
    } else if (library.containsKey(selectedBook.id)) {
      go('duplicate');
      return;
    }
    reasonDraft = '';
    bookSaveCategory = ReadingCategory.todo;
    startedDate = finishedDate = readingDay(DateTime.now());
    go('save-wish');
  }

  void addBookToCollection() {
    if (isLive) {
      unawaited(addRemoteBookToCollection());
      return;
    }
    final index = collectionData.indexWhere((c) => c.id == targetCollectionId);
    if (index < 0) return;
    setState(() {
      collectionData[index] = collectionData[index].add(
        selectedBook.id,
        slotIndex: targetCollectionSlot,
      );
      collectionPage = index;
      targetCollectionId = null;
      targetCollectionSlot = null;
      history.clear();
      screen = 'collection';
    });
    restoreShelfPage();
  }

  void saveBookLocally() {
    if (isLive) {
      unawaited(saveRemoteBook());
      return;
    }
    if (library.containsKey(selectedBook.id)) {
      go('duplicate');
      return;
    }
    setState(() {
      selectedBook = selectedBook.withReason(
        bookSaveCategory == ReadingCategory.todo ? reasonDraft.trim() : '',
      );
      library[selectedBook.id] = selectedBook;
      bookAddedDates[selectedBook.id] = readingDay(DateTime.now());
      journals[selectedBook.id] = ReadingJournal([
        ReadingRecord(
          id: 'local-${localRecordId++}',
          category: bookSaveCategory,
          date: bookSaveCategory == ReadingCategory.inProgress
              ? startedDate
              : bookSaveCategory == ReadingCategory.done
              ? finishedDate
              : DateTime.now(),
          memo: bookSaveCategory == ReadingCategory.todo
              ? reasonDraft.trim()
              : '',
        ),
      ]);
    });
    if (targetCollectionId != null) {
      addBookToCollection();
    } else {
      setState(() {
        history
          ..clear()
          ..add('shelf');
        screen = 'card-front';
      });
    }
    notice('책이 잘 저장되었습니다!');
  }

  Future<void> confirmDeleteBook() async {
    if (isSaving) return;
    final dialogContext = widget.embedded
        ? context
        : previewNavigator.currentContext;
    if (dialogContext == null) return;
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      barrierColor: Colors.black.withValues(alpha: p.dark ? .72 : .55),
      builder: (context) => Theme(
        data: p.theme,
        child: Dialog(
          backgroundColor: p.card,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: p.ink, width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: t('독서카드', 11, weight: 500, color: p.muted),
                      ),
                      iconButton(
                        'x',
                        '닫기',
                        () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  gap(8),
                  t('책을 삭제할까요?', 25, weight: 600, serif: true),
                  gap(18),
                  rule(color: p.ink, width: 1.5),
                  gap(20),
                  t(book.title, 15, weight: 600, lines: 3),
                  gap(12),
                  t('책을 삭제하면 함께 남긴 모든 기록도 사라져요.', 14, color: p.muted),
                  gap(8),
                  t('삭제한 책과 기록은 되돌릴 수 없어요.', 12, color: p.orange),
                  gap(28),
                  Row(
                    children: [
                      Expanded(
                        child: button(
                          '취소',
                          () => Navigator.of(context).pop(false),
                          secondary: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: button(
                          '삭제',
                          () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = selectedBook.id;
    setState(() => isSaving = true);
    try {
      if (isLive) await gateway.deleteBook(id);
    } catch (_) {
      if (mounted) {
        setState(() => isSaving = false);
        notice('책을 삭제하지 못했어요. 다시 시도해주세요.');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      // Invalidate requests which could restore the deleted card or shelf.
      cardRequest++;
      shelfRequest++;
      collectionsRequest++;
      library.remove(id);
      catalog.remove(id);
      cards.remove(id);
      journals.remove(id);
      bookAddedDates.remove(id);
      loadedRecordBooks.remove(id);
      pendingSavedBooks.removeWhere((_, bookId) => bookId == id);
      collectionData = [
        for (final collection in collectionData)
          ReadingCollection(
            id: collection.id,
            name: collection.name,
            slots: [
              for (final slot in collection.slots) slot == id ? null : slot,
            ],
          ),
      ];
      collectionSummaries.clear();
      loadedCollections.clear();
      staleCollections.clear();
      loadingCollections.clear();
      isSaving = false;
    });
    go('shelf');
    if (isLive) {
      await Future.wait([refreshRemoteShelf(), refreshRemoteCollections()]);
    }
  }

  void showRecordComplete() {
    // Completed forms must never be reopened by back navigation.
    setState(() {
      history
        ..clear()
        ..add('shelf');
      screen = 'record-complete';
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void returnToCardRecords() {
    final cardIndex = history.indexWhere(
      (route) => route == 'card-front' || route == 'card-back',
    );
    setState(() {
      if (cardIndex >= 0) {
        history.removeRange(cardIndex, history.length);
      } else {
        history
          ..clear()
          ..add('shelf');
      }
      screen = 'card-back';
    });
  }

  void saveRecordLocally() {
    if (isLive) {
      unawaited(saveRemoteRecord());
      return;
    }
    if (recordCategory == ReadingCategory.free && memoDraft.trim().isEmpty) {
      return;
    }
    final record = ReadingRecord(
      id: 'local-${localRecordId++}',
      category: recordCategory,
      date: recordDate,
      memo: memoDraft.trim(),
    );
    setState(() {
      journals[selectedBook.id] = journal.add(record);
      completedRecord = record;
    });
    showRecordComplete();
  }

  bool get isCollectionScreen =>
      [
        'collection',
        'collection-next',
        'collection-end',
        'collection-create',
        'collection-empty',
      ].contains(screen) ||
      (screen == 'add-options' && targetCollectionId != null);
  final GlobalKey<NavigatorState> previewNavigator =
      GlobalKey<NavigatorState>();
  final _shelfPage = ValueNotifier<int>(0);
  int get shelfPage => _shelfPage.value;
  set shelfPage(int value) => _shelfPage.value = value;
  int shelfPageCount = 1;
  bool get isShelfScreen =>
      ['shelf', 'shelf-empty'].contains(screen) ||
      (screen == 'add-options' && targetCollectionId == null);

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
      screen = target;
      selectedBook = previewBooks.first;
      library
        ..clear()
        ..addEntries(shelfPreviewBooks.map((b) => MapEntry(b.id, b)));
      journals.clear();
      bookAddedDates.clear();
      collectionData = sampleCollections();
      collectionPage = target == 'collection-next'
          ? 1
          : target == 'collection-end'
          ? 6
          : 0;
      shelfPage = page;
      reasonDraft = memoDraft = collectionNameDraft = '';
      recordDate = startedDate = finishedDate = readingDay(DateTime.now());
      editingCollection = null;
      targetCollectionId = null;
      targetCollectionSlot = null;
      completedRecord = null;
      dateTarget = 'record';
      calendarSelection = recordDate;
      searchQuery = '소년';
      searchQueryRevision++;
      history.clear();
      configureScreen(target);
    });
    restoreShelfPage();
  }

  Timer? _exitBackTimer;
  void _resetExitGuide() {
    _exitBackTimer?.cancel();
    _exitBackTimer = null;
  }

  bool get atLibraryRoot => const [
    'shelf',
    'shelf-empty',
    'collection',
    'collection-next',
    'collection-end',
    'collection-empty',
  ].contains(screen);
  bool get _androidExitGuide =>
      widget.embedded &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  Future<bool> handleSystemBack() async {
    // A pushed route (settings, camera, export) owns its own back action.
    if (widget.embedded &&
        (ModalRoute.of(context)?.isCurrent == false ||
            Navigator.of(context, rootNavigator: true).canPop())) {
      return false;
    }
    if (isSaving) return true;
    if (!atLibraryRoot) {
      back();
      return true;
    }
    if (!_androidExitGuide) return false;
    if (_exitBackTimer?.isActive ?? false) {
      _resetExitGuide();
      await SystemNavigator.pop();
    } else {
      _exitBackTimer = Timer(const Duration(seconds: 2), _resetExitGuide);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('뒤로가기를 한 번 더 누르면 종료돼요.'),
            duration: Duration(seconds: 2),
          ),
        );
    }
    return true;
  }

  bool _sectionTransitioning = false;
  int _sectionDirection = 0;
  double _sectionOverscroll = 0;
  bool _sectionDragAtBoundary = false;
  bool _sectionSwitchQueued = false;

  bool _handleShelfBoundary(ScrollNotification event) {
    if (event.depth != 0 ||
        event.metrics.axis != Axis.horizontal ||
        _sectionTransitioning ||
        _sectionSwitchQueued) {
      return false;
    }
    if (event is ScrollStartNotification) {
      _sectionOverscroll = 0;
      _sectionDragAtBoundary =
          event.dragDetails != null &&
          ((isShelfScreen &&
                  shelfPage == shelfPageCount - 1 &&
                  event.metrics.extentAfter < 1) ||
              (isCollectionScreen &&
                  collectionPage == 0 &&
                  event.metrics.extentBefore < 1));
    } else if (event is OverscrollNotification &&
        event.dragDetails != null &&
        _sectionDragAtBoundary) {
      final delta = isShelfScreen ? event.overscroll : -event.overscroll;
      _sectionOverscroll = math.max(0, _sectionOverscroll + delta);
    } else if (event is ScrollEndNotification &&
        _sectionDragAtBoundary &&
        _sectionOverscroll >= 48) {
      final toCollections = isShelfScreen;
      _sectionSwitchQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sectionSwitchQueued = false;
        if (!mounted || isSaving || !(isShelfScreen || isCollectionScreen)) {
          return;
        }
        _sectionTransitioning = true;
        _sectionDirection = toCollections ? 1 : -1;
        targetCollectionId = null;
        targetCollectionSlot = null;
        if (toCollections) {
          collectionPage = 0;
        } else {
          shelfPage = shelfPageCount - 1;
        }
        go(toCollections ? 'collection' : 'shelf', deferLibraryLoad: true);
      });
    }
    return false;
  }

  void _finishShelfSectionTransition() {
    if (!mounted || !_sectionTransitioning) return;
    setState(() {
      _sectionTransitioning = false;
      _sectionDirection = 0;
    });
    if (!isLive) return;
    if (isShelfScreen && !shelfLoading) {
      unawaited(refreshRemoteShelf());
    } else if (isCollectionScreen && !collectionsLoading) {
      unawaited(refreshRemoteCollections());
    }
  }

  void go(
    String target, {
    bool refreshLibrary = false,
    bool deferLibraryLoad = false,
  }) {
    _resetExitGuide();
    if (isLive && target == 'book-info') {
      cardRequest++;
      cardLoading = false;
      cardError = null;
      recordsError = null;
    }
    if (isLive && (isSearching || loadingMoreSearch) && target != 'search') {
      searchRequest++;
      isSearching = false;
      loadingMoreSearch = false;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (target == 'collection-create') {
      collectionNameDraft = '';
      operationError = null;
      creationWriteUncertain = false;
    }
    if (target == 'add-options' && isShelfScreen) {
      targetCollectionId = null;
      targetCollectionSlot = null;
    }
    if (target == 'record-options' &&
        ['card-front', 'card-back', 'card-empty'].contains(screen)) {
      memoDraft = '';
      recordStatusDraft = null;
      categoryBeforeFree = null;
      recordCategory = currentBookStatus;
      recordWriteUncertain = false;
      operationError = null;
      recordDate = readingDay(DateTime.now());
    }
    setState(() {
      if (const ['shelf', 'collection'].contains(target)) {
        history.clear();
      } else {
        history.add(screen);
      }
      screen = target;
    });
    restoreShelfPage();
    if (isLive && !deferLibraryLoad && refreshLibrary && target == 'shelf') {
      if (!shelfLoading) unawaited(refreshRemoteShelf());
    } else if (isLive &&
        !deferLibraryLoad &&
        refreshLibrary &&
        target == 'collection') {
      if (!collectionsLoading) unawaited(refreshRemoteCollections());
    } else if (isLive &&
        !deferLibraryLoad &&
        ['collection', 'collections'].contains(target)) {
      if (collectionData.isNotEmpty) {
        unawaited(loadRemoteCollection(currentCollection.id));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(0);
    });
  }

  void back() {
    if (isSaving) return;
    _resetExitGuide();
    if (isLive && cardLoading) {
      cardRequest++;
      cardLoading = false;
      cardError = null;
    }
    if (isLive && isSearching) {
      searchRequest++;
      isSearching = false;
      loadingMoreSearch = false;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (screen == 'record-free' && categoryBeforeFree != null) {
      recordCategory = categoryBeforeFree!;
      categoryBeforeFree = null;
      memoDraft = '';
    }
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
    _resetExitGuide();
    scroll.dispose();
    shelfPages.dispose();
    _shelfPage.dispose();
    collectionPages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = AnnotatedRegion<SystemUiOverlayStyle>(
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
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleShelfBoundary,
                        child: ShelfSectionTransition(
                          direction: _sectionTransitioning
                              ? _sectionDirection
                              : 0,
                          onCompleted: _finishShelfSectionTransition,
                          child: KeyedSubtree(
                            key: ValueKey(
                              isShelfScreen
                                  ? 'shelf-section'
                                  : isCollectionScreen
                                  ? 'collection-section'
                                  : screen == 'search' ||
                                        screen == 'search-empty'
                                  ? 'search-section'
                                  : screen,
                            ),
                            child: _workspaceBody(context),
                          ),
                        ),
                      ),
                    ),
                    if (hasNav)
                      IgnorePointer(
                        ignoring: _sectionTransitioning,
                        child: navigation(),
                      ),
                    if (!hasNav &&
                        bottomAction != null &&
                        (!screen.startsWith('card') ||
                            (!cardLoading && cardError == null)))
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
                Positioned.fill(
                  child: SlidingSheetOverlay(
                    sheet: overlay,
                    identity: screen,
                    barrierColor: Colors.black.withValues(
                      alpha: p.dark ? .62 : .55,
                    ),
                    onDismiss: back,
                  ),
                ),
                if (isSaving)
                  const Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: Color(0x33000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final navigable = PopScope(
      canPop: !isSaving && atLibraryRoot && !_androidExitGuide,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(handleSystemBack());
      },
      child: content,
    );
    final embeddedContent = Router.maybeOf(context) == null
        ? navigable
        : BackButtonListener(
            onBackButtonPressed: handleSystemBack,
            child: navigable,
          );
    return widget.embedded
        ? Theme(data: p.theme, child: embeddedContent)
        : MaterialApp(
            title: '모아북 디자인 시안',
            navigatorKey: previewNavigator,
            debugShowCheckedModeBanner: false,
            theme: p.theme,
            home: navigable,
          );
  }

  Widget _workspaceBody(BuildContext context) =>
      remoteBlockingBody() ??
      (isShelfScreen
          ? Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
              child: shelf(
                empty: screen == 'shelf-empty' || (isLive && library.isEmpty),
              ),
            )
          : isCollectionScreen
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: collectionPager(),
            )
          : usesCardBackLayout
          ? Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                12,
                22,
                MediaQuery.paddingOf(context).bottom + 14,
              ),
              child: page(),
            )
          : NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                // Layout changes also cover short pages and
                // resizing without requiring another swipe.
                _checkSearchAfterLayout();
                return false;
              },
              child: SingleChildScrollView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(22, 12, 22, hasNav ? 12 : 28),
                child: page(),
              ),
            ));

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
    'collection-empty',
  ].contains(screen);
  Widget? get bottomAction => switch (screen) {
    'book-info' => button(
      targetCollectionId == null ? '이 책 저장하기' : '컬렉션에 담기',
      confirmBook,
      icon: 'plus',
    ),
    'search-empty' => button(
      '다른 검색어로 찾아보기',
      () => go('search'),
      icon: 'search',
    ),
    'collection-edit' => button(
      '편집 완료',
      collectionNameDraft.trim().isEmpty ? null : saveCollectionEdit,
      icon: 'check',
    ),
    'record-complete' => button(
      '독서카드로 돌아가기',
      returnToCardRecords,
      icon: 'arrow-right',
    ),
    'capture' => button(
      '책 정보 확인하기',
      () => go('book-info'),
      icon: 'scan-barcode',
    ),
    _ => null,
  };

  Widget? get overlay => switch (screen) {
    'add-options' => addSheet(),
    'collection-create' => createSheet(),
    'save-wish' || 'save-reading' || 'save-read' => saveSheet(),
    'duplicate' => duplicateDialog(),
    'collection-duplicate' => collectionDuplicateDialog(),
    'record-options' => recordSheet(),
    'record-entry' ||
    'record-quote' ||
    'record-free' ||
    'record-wish' => recordEntrySheet(),
    'date-picker' => dateSheet(),
    _ => null,
  };

  bool get usesCardBackLayout =>
      const [
        'card-back',
        'card-empty',
        'record-options',
        'record-entry',
        'record-quote',
        'record-free',
        'record-wish',
      ].contains(screen) ||
      (screen == 'date-picker' && dateTarget == 'record');

  Widget page() => switch (screen) {
    'shelf' ||
    'shelf-empty' ||
    'add-options' => shelf(empty: screen == 'shelf-empty'),
    'collection' || 'collection-create' || 'collection-empty' => collection(),
    'collections' ||
    'collections-empty' => collections(empty: screen == 'collections-empty'),
    'collection-edit' => collectionEdit(),
    'search' || 'search-empty' => searchPage(empty: screen == 'search-empty'),
    'book-info' ||
    'save-wish' ||
    'save-reading' ||
    'save-read' ||
    'duplicate' ||
    'collection-duplicate' => bookInfo(),
    'card-front' => cardFront(),
    'card-back' ||
    'card-empty' ||
    'record-options' ||
    'record-entry' ||
    'record-quote' ||
    'record-free' ||
    'record-wish' => cardBack(empty: screen == 'card-empty'),
    'date-picker' => dateTarget == 'record' ? cardBack() : bookInfo(),
    'record-complete' => complete(),
    'capture' => capture(),
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
        child: Align(
          // Leading arrows share the content edge without an extra half-cell
          // inset. Keep the full 44dp hit area for comfortable back navigation.
          alignment: name == 'chevron-left'
              ? Alignment.centerLeft
              : Alignment.center,
          child: icon(name, color: color),
        ),
      ),
    ),
  );
  Widget button(
    String label,
    VoidCallback? onTap, {
    String? icon,
    bool secondary = false,
    bool compact = false,
  }) => Semantics(
    button: true,
    enabled: onTap != null,
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
          color: onTap == null
              ? p.line
              : secondary
              ? p.card
              : p.button,
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
              screen.startsWith('shelf') ||
                  (screen == 'add-options' && targetCollectionId == null),
              () => go('shelf', refreshLibrary: true),
              bottomInset: MediaQuery.paddingOf(context).bottom,
              textHeight: MediaQuery.textScalerOf(context).scale(13) * 1.5,
            ),
            navItem(
              '주제 서가',
              'layers',
              !screen.startsWith('shelf') &&
                  (screen != 'add-options' || targetCollectionId != null),
              () {
                collectionPage = 0;
                targetCollectionId = null;
                targetCollectionSlot = null;
                go('collection', refreshLibrary: true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (collectionPages.hasClients) collectionPages.jumpToPage(0);
                });
              },
              bottomInset: MediaQuery.paddingOf(context).bottom,
              textHeight: MediaQuery.textScalerOf(context).scale(13) * 1.5,
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
    double textHeight = 19.5,
  }) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: math.max(78, textHeight + 51) + bottomInset,
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

  Color reasonColor(String type) => p.orange;
  Color reasonTextColor(String type) => Colors.white;

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
            child: isLive
                ? (value.coverUrl == null || value.coverUrl!.isEmpty
                      ? const ColoredBox(color: Color(0xffd4d4d4))
                      : CachedNetworkImage(
                          imageUrl: value.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const ColoredBox(color: Color(0xffd4d4d4)),
                          errorWidget: (_, _, _) =>
                              const ColoredBox(color: Color(0xffd4d4d4)),
                        ))
                : value.demo
                ? ColoredBox(
                    color: const Color(0xffd4d4d4),
                    child: Padding(
                      padding: EdgeInsets.all((width ?? 120) < 60 ? 4 : 12),
                      child: Center(
                        child: t(
                          value.title,
                          ((width ?? 160) * .1).clamp(8.0, 16.0),
                          lines: 4,
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
                    errorBuilder: (_, error, stack) =>
                        const ColoredBox(color: Color(0xffd4d4d4)),
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
      iconButton('settings-2', isLive ? '설정' : '시안 설정', showDesignPicker),
    ],
  );

  static const spineHeights = [1.0, .90, .96, .86, .93, .98, .89, .95, .91];
  double spineWidth(PreviewBook book, TextScaler scaler) =>
      math.max(bookSpineWidth(book.totalPage), scaler.scale(11) + 12);

  List<List<PreviewBook>> shelfRows(double width, TextScaler scaler) {
    final books = shelfBooks;
    final rows = <List<PreviewBook>>[];
    var row = <PreviewBook>[];
    var used = 0.0;
    for (var i = 0; i < books.length; i++) {
      final needed = spineWidth(books[i], scaler);
      if (row.isNotEmpty && used + needed > width) {
        rows.add(row);
        row = [];
        used = 0;
      }
      used += needed;
      row.add(books[i]);
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  Widget shelf({bool empty = false}) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final rows = shelfRows(constraints.maxWidth, scaler);
      renderedShelfRows = rows;
      final bookIndices = {
        for (final (index, id) in library.keys.indexed) id: index,
      };
      final count = math.max(1, (rows.length / 3).ceil());
      shelfPageCount = count;
      return ColoredBox(
        color: p.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shelfToolbar(
              'MOABOOK / MY BOOKS',
              count: empty
                  ? '0권'
                  : '${isLive ? totalShelfCount : shelfBooks.length}권',
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
                  () => unawaited(exportImages()),
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
                child: RepaintBoundary(
                  key: shelfCaptureKey,
                  child: ColoredBox(
                    color: p.background,
                    child: PageView.builder(
                      key: const Key('shelf-pager'),
                      controller: shelfPages,
                      physics: const PageScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                      ),
                      itemCount: count,
                      allowImplicitScrolling: true,
                      onPageChanged: (page) => shelfPage = page,
                      itemBuilder: (context, page) => _KeepAliveShelfPage(
                        keepAlive: count <= 5,
                        child: Column(
                          children: [
                            for (var row = 0; row < 3; row++) ...[
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, space) => bookShelf(
                                    page * 3 + row < rows.length
                                        ? rows[page * 3 + row]
                                        : [],
                                    space.maxHeight,
                                    scaler: scaler,
                                    bookIndices: bookIndices,
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
                  ),
                ),
              ),
              gap(10),
              Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: _shelfPage,
                  builder: (context, page, _) => Text(
                    '${page.clamp(0, count - 1) + 1} / $count',
                    key: const Key('shelf-page-indicator'),
                    style: p.text(11, mono: true, color: p.muted),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget bookShelf(
    List<PreviewBook> books,
    double height, {
    Key? key,
    required TextScaler scaler,
    required Map<String, int> bookIndices,
  }) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < books.length; i++) ...[
                Builder(
                  builder: (context) {
                    final value = books[i];
                    final n = bookIndices[value.id] ?? 0;
                    final foreground = p.dark ? const Color(0xffdddddd) : p.ink;
                    return Semantics(
                      label: '${value.title}, 독서카드 열기',
                      button: true,
                      child: InkWell(
                        key: ValueKey('spine-${value.id}'),
                        onTap: () {
                          openBook(value);
                        },
                        child: Container(
                          width: spineWidth(value, scaler),
                          height:
                              (height - (p.dark ? 4 : 3)) *
                              spineHeights[n % spineHeights.length],
                          clipBehavior: Clip.hardEdge,
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
      ),
      Container(height: p.dark ? 4 : 3, color: p.dark ? p.accent : p.ink),
    ],
  );

  Widget collectionPager() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            Expanded(
              child: t(
                'COLLECTION',
                10,
                mono: true,
                color: p.dark ? p.accent : p.muted,
              ),
            ),
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                key: const Key('collection-picker'),
                tooltip: '주제 서가 목록',
                onPressed: () => go('collections'),
                icon: icon('list', size: 24, color: p.dark ? p.accent : p.ink),
              ),
            ),
            iconButton('settings-2', isLive ? '설정' : '시안 설정', showDesignPicker),
          ],
        ),
      ),
      Expanded(
        child: PageView.builder(
          key: const Key('collection-pager'),
          controller: collectionPages,
          physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
          itemCount: collectionTitles.length + 1,
          onPageChanged: (index) => setState(() {
            collectionPage = index;
            if (isLive && index < collectionData.length) {
              unawaited(loadRemoteCollection(collectionData[index].id));
            }
          }),
          itemBuilder: (context, index) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: index == collectionTitles.length
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      t('새 컬렉션 만들기', 28, weight: 600),
                      gap(16),
                      rule(color: p.ink),
                      emptyState(
                        'plus',
                        '새로운 주제로 모아보세요',
                        '나만의 컬렉션을 하나 더 만들어보세요.',
                        () => go('collection-create'),
                        actionLabel: '새 컬렉션 만들기',
                      ),
                    ],
                  )
                : collection(index: index, showToolbar: false),
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

  Widget collection({int index = 0, bool showToolbar = true}) {
    final value = collectionData[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showToolbar) shelfToolbar('COLLECTION'),
        Row(
          children: [
            Expanded(
              child: t(
                value.name,
                p.dark ? 32 : 28,
                serif: true,
                weight: 600,
                color: p.dark ? p.accent : p.ink,
                lines: 2,
              ),
            ),
            if (showToolbar)
              IconButton(
                key: const Key('collection-picker'),
                tooltip: '주제 서가 목록',
                onPressed: () => go('collections'),
                icon: icon('list', size: 24, color: p.dark ? p.accent : p.ink),
              ),
          ],
        ),
        gap(16),
        rule(color: p.ink),
        gap(9),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            actionText('편집', 'pencil', beginEditCollection),
            const SizedBox(width: 16),
            actionText(
              '이미지 저장',
              'download',
              () => unawaited(exportImages(collection: value)),
            ),
          ],
        ),
        gap(16),
        if (isLive && !loadedCollections.contains(value.id))
          _sectionTransitioning
              ? const SizedBox(height: 300)
              : remoteMessage(
                  collectionErrors[value.id],
                  () => unawaited(loadRemoteCollection(value.id, force: true)),
                )
        else
          collectionGrid(value),
      ],
    );
  }

  Widget collectionGrid(ReadingCollection value, {bool editing = false}) =>
      CollectionSlotGrid(
        palette: p,
        slotBuilder: (index, width) {
          final id = value.slots[index];
          if (id == null) {
            return EmptyCollectionSlot(
              palette: p,
              index: index,
              onTap: editing
                  ? null
                  : () => startAddingToCollection(slotIndex: index),
            );
          }
          final original = library[id] ?? catalog[id]!;
          final display = isLive
              ? original
              : original.withReason(journalFor(original).reason ?? '');
          return Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  label: '${index + 1}번 칸, ${display.title}',
                  button: !editing,
                  child: InkWell(
                    onTap: editing ? null : () => openBook(original),
                    child: cover(display, width: width, height: width * 1.35),
                  ),
                ),
              ),
              if (!editing && display.reason.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: width * .12,
                  child: obi(display),
                ),
              if (editing)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    color: p.background,
                    child: IconButton(
                      key: ValueKey('remove-slot-$index'),
                      tooltip: '${index + 1}번 칸 책 빼기',
                      icon: icon('x', size: 18),
                      onPressed: () => setState(() {
                        editingCollection = editingCollection!.removeAt(index);
                      }),
                    ),
                  ),
                ),
            ],
          );
        },
      );

  Widget actionText(
    String title,
    String name,
    VoidCallback onTap, {
    Color? color,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon(name, size: 14, color: color),
          const SizedBox(width: 5),
          t(title, 13, weight: 500, color: color),
        ],
      ),
    ),
  );
  Widget collections({bool empty = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header('나의 컬렉션', eyebrow: 'COLLECTION INDEX', previous: true),
      Row(
        children: [
          Expanded(
            child: t(
              empty ? '아직 만든 컬렉션이 없어요' : '${collectionData.length}개의 컬렉션',
              12,
              color: p.muted,
            ),
          ),
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
      else
        for (var index = 0; index < collectionData.length; index++)
          collectionRow(collectionData[index], index),
    ],
  );

  Widget collectionRow(ReadingCollection value, int index) {
    final representativeBooks = isLive
        ? collectionSummaries[value.id]?.representatives ??
              [
                for (final id in value.slots.whereType<String>().take(2))
                  catalog[id]!,
              ]
        : [
            for (final id in value.slots.whereType<String>().take(2))
              library[id]!,
          ];
    final representatives = representativeBooks;
    return InkWell(
      onTap: () {
        collectionPage = index;
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
              child: representatives.isEmpty
                  ? EmptyCollectionSlot(palette: p, index: 0)
                  : Stack(
                      children: [
                        if (representatives.length == 2)
                          Positioned(
                            left: 24,
                            top: 4,
                            child: Transform.rotate(
                              angle: .07,
                              child: cover(
                                representatives[1],
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
                            child: cover(
                              representatives.first,
                              width: 49,
                              height: 70,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: t(value.name, 17, weight: 600, serif: !p.dark, lines: 2),
            ),
            icon('chevron-right', size: 18, color: p.muted),
          ],
        ),
      ),
    );
  }

  Widget collectionEdit() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header('컬렉션 편집', previous: true, eyebrow: 'COLLECTION / EDIT'),
      field(
        '컬렉션 이름',
        collectionNameDraft,
        onChanged: (value) => setState(() => collectionNameDraft = value),
      ),
      gap(24),
      t('담긴 책', 15, weight: 600),
      gap(8),
      t('책을 빼도 서가의 책과 기록은 그대로 남아요.', 12, color: p.muted),
      gap(16),
      collectionGrid(editingCollection!, editing: true),
      if (operationError != null) ...[
        gap(12),
        t(operationError!, 13, color: p.orange),
      ],
    ],
  );

  int searchQueryRevision = 0;
  List<PreviewBook> get searchResults {
    if (isLive) return remoteSearchResults;
    final keyword = searchQuery.trim().toLowerCase();
    return [...previewBooks, newPreviewBook]
        .where(
          (value) =>
              keyword.isEmpty ||
              value.title.toLowerCase().contains(keyword) ||
              value.author.toLowerCase().contains(keyword),
        )
        .toList();
  }

  Widget searchPage({bool empty = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      header('책 찾기', previous: true, eyebrow: 'ADD / SEARCH'),
      TextFormField(
        key: ValueKey('search-query-$searchQueryRevision'),
        autofocus: true,
        initialValue: empty && !isLive ? '아무도 모르는 책 제목' : searchQuery,
        style: p.text(16),
        textInputAction: TextInputAction.search,
        onChanged: (value) => searchQuery = value,
        onFieldSubmitted: (value) {
          if (isLive) {
            unawaited(searchRemoteBooks(value));
            return;
          }
          setState(() {
            searchQuery = value;
            screen = searchResults.isEmpty ? 'search-empty' : 'search';
          });
        },
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.all(14),
            child: icon('search', size: 20),
          ),
          suffixIcon: iconButton('x', '검색어 지우기', () {
            setState(() {
              searchQuery = '';
              searchQueryRevision++;
              remoteSearchResults = [];
              remoteSearchPage = 0;
              remoteSearchHasMore = false;
              remoteSearchTotalCount = null;
              loadingMoreSearch = false;
              searchMoreError = null;
              activeSearchQuery = '';
              searchRequest++;
              isSearching = false;
              searchError = null;
              screen = 'search';
            });
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
      if (isLive && (isSearching || searchError != null))
        remoteMessage(
          searchError,
          () => unawaited(searchRemoteBooks(searchQuery)),
          loading: isSearching,
        )
      else if (empty)
        emptyState('search', '아직 찾지 못했어요.', '제목의 일부나 저자 이름으로\n다시 검색해보세요', null)
      else ...[
        Row(
          children: [
            t('검색 결과', 13, weight: 600),
            const Spacer(),
            t(
              isLive && remoteSearchTotalCount != null
                  ? '${searchResults.length} / $remoteSearchTotalCount권'
                  : '${searchResults.length}권',
              11,
              mono: true,
              color: p.muted,
            ),
          ],
        ),
        gap(10),
        for (final value in searchResults)
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
        if (isLive && searchMoreError != null) ...[
          gap(12),
          t(searchMoreError!, 13, color: p.orange),
        ],
        if (isLive && remoteSearchHasMore) ...[
          gap(16),
          if (loadingMoreSearch)
            Center(
              child: Semantics(
                label: '다음 책 불러오는 중',
                child: const CircularProgressIndicator(),
              ),
            )
          else if (searchMoreError != null)
            button('다시 불러오기', () => unawaited(loadMoreRemoteBooks())),
        ],
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
      gap(12),
      t('${book.author} · ${book.publisher}', 13, color: p.muted),
      gap(23),
      if ((book.totalPage != null && book.totalPage! > 0) ||
          (book.publishDate?.trim().isNotEmpty ?? false)) ...[
        Container(
          key: const ValueKey('book-info-metadata'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: p.ink, width: 3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (book.totalPage != null && book.totalPage! > 0)
                Expanded(child: infoStat('페이지', '${book.totalPage}쪽')),
              if (book.publishDate?.trim().isNotEmpty ?? false)
                Expanded(
                  child: infoStat(
                    '출간일',
                    formatPublicationDate(book.publishDate!),
                  ),
                ),
            ],
          ),
        ),
        gap(18),
      ],
      actionText(
        isLive && book.yes24Id != null ? 'YES24에서 더보기' : '알라딘에서 더보기',
        'arrow-right',
        () {
          if (isLive) {
            openRemoteLink();
          } else {
            notice('도서 정보 출처: 알라딘');
          }
        },
      ),
      gap(12),
    ],
  );
  String formatPublicationDate(String value) {
    final date = DateTime.tryParse(value.replaceAll('.', '-'));
    return date == null ? value : formatDate(date);
  }

  Widget infoStat(String name, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      t(name, 11, color: p.muted),
      gap(7),
      t(value, 16, weight: 600, mono: true, color: p.dark ? p.accent : p.ink),
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
          children: [
            iconButton('chevron-left', '서가로 돌아가기', back),
            TextButton.icon(
              onPressed: confirmDeleteBook,
              style: TextButton.styleFrom(
                foregroundColor: p.muted,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: p.muted,
              ),
              label: t('삭제', 12, weight: 600, color: p.muted),
            ),
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
                              lines: 2,
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
                  if (book.reason.isNotEmpty)
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
                              '${book.author} · ${book.publisher}${p.dark ? ' · ${formatDate(bookAddedDate)} 추가' : ''}',
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
                        width: double.infinity,
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
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            InkWell(
                              onTap: () => flipCard('card-back'),
                              child: Text.rich(
                                TextSpan(
                                  style: p.text(12, weight: 500),
                                  children: [
                                    const TextSpan(text: '독서 카드 기록 '),
                                    TextSpan(
                                      text: recordCount == null
                                          ? '—'
                                          : '$recordCount개',
                                      style: p.text(
                                        13,
                                        weight: 600,
                                        color: p.dark ? p.background : p.orange,
                                        background: p.dark ? p.accent : null,
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
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    t(
                                      recordCount == 0 ? '첫 기록 남기기' : '추가하기',
                                      12,
                                      weight: 600,
                                    ),
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
        iconButton('chevron-left', '독서카드 앞면', () => flipCard('card-front')),
        gap(16),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: p.dark
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(18, 21, 18, 21),
            decoration: BoxDecoration(
              color: p.dark ? p.background : p.card,
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
                        lines: 2,
                      ),
                      gap(8),
                      t(
                        '${formatDate(bookAddedDate)} 추가',
                        11,
                        color: p.dark ? p.background : p.muted,
                      ),
                    ],
                  ),
                ),
                gap(14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: t('독서 기록', 15, weight: 600)),
                    if (journal.records.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Semantics(
                        button: true,
                        child: InkWell(
                          onTap: () => go('record-options'),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            color: const Color(0xff121212),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                icon('plus', size: 18, color: Colors.white),
                                const SizedBox(width: 7),
                                t(
                                  '기록 추가',
                                  13,
                                  weight: 600,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                gap(10),
                rule(color: p.ink),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('card-record-list'),
                    controller: scroll,
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (journal.records.isEmpty) ...[
                          gap(40),
                          Center(
                            child: icon('pencil', size: 34, color: p.muted),
                          ),
                          gap(18),
                          Center(
                            child: t(
                              '첫 번째 기억을 남겨보세요',
                              16,
                              serif: true,
                              weight: 600,
                            ),
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
                          gap(24),
                          button(
                            '첫 기록 남기기',
                            () => go('record-options'),
                            icon: 'pencil',
                          ),
                        ] else ...[
                          t('책과의 시간은 계속됩니다.', 11, color: p.muted),
                          gap(18),
                          for (final record in journal.newestFirst)
                            timeline(
                              formatDate(record.date).substring(5),
                              record.category.label,
                              record.memo,
                              categoryIcon(record.category),
                              record.category.group,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
  Widget sheet(
    String title,
    List<Widget> children, {
    Widget? footer,
    Widget? titleAction,
    String? subtitle,
    bool bookSave = false,
    bool recordEntry = false,
  }) => Builder(
    builder: (context) => Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * (recordEntry ? .68 : .84),
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.dark ? const Color(0xff1b1b1b) : p.background,
        border: Border(
          top: BorderSide(
            color: recordEntry ? p.line : (p.dark ? p.accent : p.ink),
            width: bookSave || recordEntry ? 1 : (p.dark ? 4 : 2),
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
      child: Column(
        mainAxisSize: recordEntry ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 32, height: 4, color: p.line)),
                gap(12),
                Row(
                  children: [
                    Expanded(
                      child: t(
                        title,
                        16,
                        weight: bookSave || recordEntry ? 700 : 600,
                      ),
                    ),
                    iconButton('x', '닫기', back),
                  ],
                ),
                ?titleAction,
                if (subtitle != null) ...[
                  gap(4),
                  t(subtitle, 12, color: p.muted),
                ],
              ],
            ),
          ),
          Flexible(
            fit: recordEntry ? FlexFit.tight : FlexFit.loose,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(22, 12, 22, footer == null ? 24 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 32),
              child: footer,
            ),
        ],
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
      '바코드 스캔',
      '책 뒷면의 ISBN 바코드로 찾아보세요',
      'scan-barcode',
      () => isLive
          ? unawaited(selectRemoteMedia(widget.onCapture))
          : go('capture'),
    ),
  ], subtitle: '책을 검색하거나 바코드로 찾아보세요');

  Widget field(
    String title,
    String value, {
    String? hint,
    int lines = 1,
    int? maxLength,
    String? requirement,
    ValueChanged<String>? onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (requirement == null)
        t(title, 14, weight: 500)
      else
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            t(title, 14, weight: 700),
            t('· $requirement', 11, color: p.muted),
          ],
        ),
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
        collectionNameDraft,
        hint: '컬렉션 이름을 입력해주세요',
        onChanged: (value) => setState(() => collectionNameDraft = value),
      ),
      gap(15),
      t('책은 컬렉션을 만든 뒤에도 추가할 수 있어요.', 11, color: p.muted),
      if (operationError != null) ...[
        gap(12),
        t(operationError!, 13, color: p.orange),
      ],
    ],
    footer: button(
      creationWriteUncertain ? '컬렉션 목록에서 결과 확인' : '컬렉션 만들기',
      creationWriteUncertain
          ? () {
              go('collections');
              unawaited(refreshRemoteCollections());
            }
          : collectionNameDraft.trim().isEmpty
          ? null
          : () {
              if (isLive) {
                unawaited(createRemoteCollection());
                return;
              }
              final created = ReadingCollection(
                id: 'local-collection-${collectionData.length}',
                name: collectionNameDraft,
              );
              setState(() {
                collectionData.add(created);
                collectionPage = collectionData.length - 1;
                history.clear();
                screen = 'collection';
              });
              restoreShelfPage();
            },
      icon: 'plus',
    ),
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
      rule(color: p.ink),
      gap(20),
      t('지금 이 책과 어떤 사이인가요?', 16, weight: 700),
      gap(12),
      Row(
        children: [
          for (final category in [
            ReadingCategory.todo,
            ReadingCategory.inProgress,
            ReadingCategory.done,
          ]) ...[
            if (category != ReadingCategory.todo) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                selected: bookSaveCategory == category,
                button: true,
                child: InkWell(
                  key: ValueKey('save-status-${category.code}'),
                  onTap: () => setState(() => bookSaveCategory = category),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: bookSaveCategory == category ? p.button : p.card,
                      border: Border.all(
                        color: bookSaveCategory == category ? p.button : p.line,
                      ),
                    ),
                    child: t(
                      switch (category) {
                        ReadingCategory.todo => '읽고 싶은 책',
                        ReadingCategory.inProgress => '읽고 있는 책',
                        _ => '읽은 책',
                      },
                      13,
                      weight: bookSaveCategory == category ? 600 : 400,
                      align: TextAlign.center,
                      color: bookSaveCategory == category
                          ? p.onButton
                          : p.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      gap(24),
      if (bookSaveCategory == ReadingCategory.todo) ...[
        saveReasonField(),
        gap(7),
        Align(
          alignment: Alignment.centerRight,
          child: t(
            '${reasonDraft.characters.length}/400',
            11,
            mono: true,
            color: p.muted,
          ),
        ),
      ] else ...[
        if (bookSaveCategory == ReadingCategory.inProgress)
          dateField('읽기 시작한 날', startedDate, target: 'start', emphasized: true)
        else
          dateField('다 읽은 날', finishedDate, target: 'finish', emphasized: true),
        gap(14),
        t('책과 함께한 시간을 독서카드에 남겨요.', 12, color: p.muted),
      ],
      gap(24),
      if (operationError != null) ...[
        gap(12),
        t(operationError!, 13, color: p.orange),
      ],
    ],
    footer: button(
      uncertainInitialBookWrites.contains(selectedBook.id)
          ? '독서카드에서 저장 결과 확인'
          : '저장하기',
      uncertainInitialBookWrites.contains(selectedBook.id)
          ? openPendingSavedCard
          : saveBookLocally,
      icon: 'bookmark',
    ),
    bookSave: true,
  );
  Widget saveReasonField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '읽고 싶은 이유', style: p.text(14, weight: 700)),
            TextSpan(
              text: ' · 선택',
              style: p.text(12, color: p.muted),
            ),
          ],
        ),
      ),
      gap(10),
      SizedBox(
        height: 120,
        child: TextFormField(
          key: const ValueKey('save-reason'),
          initialValue: reasonDraft,
          expands: true,
          minLines: null,
          maxLines: null,
          maxLength: 400,
          textAlignVertical: TextAlignVertical.top,
          onChanged: (value) => setState(() => reasonDraft = value),
          style: p.text(16),
          decoration: InputDecoration(
            counterText: '',
            hintText: '이 책을 읽고 싶은 이유를 남겨보세요',
            hintStyle: p.text(14, color: p.muted),
            filled: true,
            fillColor: p.card,
            contentPadding: const EdgeInsets.all(16),
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
      ),
    ],
  );

  void openPendingSavedCard() {
    final id = pendingSavedBooks[selectedBook.id];
    if (id == null) return;
    selectedBook = ReadingBook(
      id,
      selectedBook.title,
      selectedBook.author,
      selectedBook.publisher,
      '',
      '',
    );
    history
      ..clear()
      ..add('shelf');
    go('card-back');
    unawaited(loadRemoteCard(id));
  }

  Widget dateField(
    String title,
    DateTime value, {
    String target = 'record',
    bool emphasized = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      t(title, 14, weight: emphasized ? 700 : 500),
      gap(9),
      InkWell(
        onTap: () {
          dateTarget = target;
          calendarSelection = value;
          go('date-picker');
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: emphasized ? 16 : 14,
            vertical: emphasized ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: p.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: t(
                      formatDate(value),
                      emphasized ? 18 : 14,
                      mono: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              icon('calendar-days', size: emphasized ? 18 : 20, color: p.muted),
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
            button('독서카드로 이동', () {
              if (isLive) {
                openBook(selectedBook);
              } else {
                go('card-front');
              }
            }, icon: 'arrow-right'),
          ],
        ),
      ),
    ),
  );

  Widget collectionDuplicateDialog() => sheet(
    '이미 이 컬렉션에 담긴 책이에요',
    [t('같은 컬렉션에는 같은 책을 한 번만 담을 수 있어요.', 14, color: p.muted)],
    footer: button('확인', () {
      if (screen == 'collection-duplicate' && history.isEmpty) {
        setState(() => screen = 'book-info');
      } else {
        back();
      }
    }),
  );

  String categoryIcon(ReadingCategory category) => switch (category) {
    ReadingCategory.inProgress => 'book-open',
    ReadingCategory.todo => 'bookmark',
    ReadingCategory.done => 'circle-check',
    ReadingCategory.lend => 'library',
    ReadingCategory.gift || ReadingCategory.present => 'gift',
    ReadingCategory.sentence => 'quote',
    ReadingCategory.talk => 'message-circle',
    ReadingCategory.remind => 'repeat-2',
    ReadingCategory.borrow => 'handshake',
    ReadingCategory.reread => 'heart',
    ReadingCategory.free => 'pencil',
    _ => 'book-open',
  };

  void chooseCategory(ReadingCategory value) {
    if (isSaving || recordWriteUncertain) return;
    if (value == ReadingCategory.free) {
      categoryBeforeFree = recordCategory == ReadingCategory.free
          ? selectedRecordStatus
          : recordCategory;
      recordCategory = value;
      memoDraft = '';
      go('record-free');
      return;
    }
    setState(() {
      recordCategory = value;
      memoDraft = '';
      if (value.changesStatus) recordStatusDraft = value;
    });
    go('record-entry');
  }

  bool recordOptionSelected(ReadingCategory option) => option.changesStatus
      ? option == selectedRecordStatus
      : option == recordCategory;

  Widget recordSheet() => sheet(
    '기록 추가',
    [
      for (final group in ['독서 상태', '책 수령', '순간 기록']) ...[
        recordGroup(
          group,
          ReadingCategory.values.where((c) => c.group == group).toList(),
        ),
        gap(18),
      ],
      if (operationError != null) ...[
        gap(12),
        t(operationError!, 13, color: p.orange),
      ],
    ],
    footer: recordWriteUncertain
        ? button('기록 목록에서 저장 결과 확인', () {
            returnToCardRecords();
            unawaited(loadRemoteCard(selectedBook.id));
          }, icon: 'check')
        : button(
            '자유 기록',
            () => chooseCategory(ReadingCategory.free),
            icon: 'pencil',
          ),
  );

  Widget recordGroup(String title, List<ReadingCategory> options) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      t(title, 11, weight: 500, mono: true, color: p.dark ? p.accent : p.ink),
      if (!p.dark) ...[gap(4), rule()],
      gap(6),
      Wrap(
        spacing: 7,
        runSpacing: 8,
        children: [
          for (final option in options)
            Semantics(
              selected: recordOptionSelected(option),
              button: true,
              child: InkWell(
                key: ValueKey('category-${option.code}'),
                onTap: isSaving || recordWriteUncertain
                    ? null
                    : () => chooseCategory(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: recordOptionSelected(option) ? p.button : p.card,
                    border: Border.all(
                      color: p.dark ? const Color(0xff555555) : p.ink,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon(
                        categoryIcon(option),
                        size: 18,
                        color: recordOptionSelected(option)
                            ? p.onButton
                            : p.muted,
                      ),
                      const SizedBox(width: 6),
                      t(
                        option.label,
                        13,
                        weight: 500,
                        color: recordOptionSelected(option)
                            ? p.onButton
                            : p.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget recordEntrySheet() {
    final wish = recordCategory == ReadingCategory.todo;
    final free = recordCategory == ReadingCategory.free;
    return sheet(
      recordKind,
      [
        if (operationError != null) ...[
          t(operationError!, 13, color: p.orange),
          gap(12),
        ],
        dateField('날짜', recordDate, emphasized: true),
        gap(23),
        field(
          wish ? '읽고 싶은 이유' : '어떤 기억을 남기고 싶나요?',
          memoDraft,
          requirement: free ? '필수' : '선택',
          hint: wish ? '이 책을 읽고 싶은 이유를 남겨보세요' : '기억하고 싶은 순간을 남겨보세요',
          lines: 4,
          maxLength: 400,
          onChanged: (value) => setState(() => memoDraft = value),
        ),
        gap(7),
        Align(
          alignment: Alignment.centerRight,
          child: t(
            '${memoDraft.characters.length}/400',
            10,
            mono: true,
            color: p.muted,
          ),
        ),
      ],
      recordEntry: true,
      titleAction: actionText('카테고리 바꾸기', 'chevron-left', () {
        if (history.isNotEmpty && history.last == 'record-options') {
          back();
          return;
        }
        if (recordCategory == ReadingCategory.free) {
          recordCategory = categoryBeforeFree ?? selectedRecordStatus;
          categoryBeforeFree = null;
          memoDraft = '';
        }
        go('record-options');
      }, color: p.muted),
      footer: button(
        recordWriteUncertain ? '기록 목록에서 저장 결과 확인' : '기록 완료',
        recordWriteUncertain
            ? () {
                returnToCardRecords();
                unawaited(loadRemoteCard(selectedBook.id));
              }
            : free && memoDraft.trim().isEmpty
            ? null
            : saveRecordLocally,
        icon: 'check',
      ),
    );
  }

  Widget dateSheet() => sheet(
    '날짜 선택',
    [
      ReadingCalendar(
        palette: p,
        selected: calendarSelection,
        onChanged: (value) => setState(() => calendarSelection = value),
      ),
    ],
    footer: button('${formatDate(calendarSelection)} 선택', () {
      setState(() {
        switch (dateTarget) {
          case 'start':
            startedDate = calendarSelection;
          case 'finish':
            finishedDate = calendarSelection;
          default:
            recordDate = calendarSelection;
        }
      });
      back();
    }, icon: 'check'),
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
            t(
              formatDate(completedRecord?.date ?? recordDate),
              11,
              mono: true,
              color: p.dark ? p.accent : p.muted,
            ),
            gap(18),
            t(completedRecord?.category.label ?? recordKind, 19, weight: 600),
            gap(10),
            if ((completedRecord?.memo ?? memoDraft).isNotEmpty)
              t(completedRecord?.memo ?? memoDraft, 14, color: p.muted),
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
      t('책 뒷면의 ISBN 바코드를 화면 안에 맞춰주세요.', 12, color: p.muted),
      gap(24),
      Container(
        height: 405,
        width: double.infinity,
        color: const Color(0xff292925),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 130,
              color: Colors.white,
              child: Center(
                child: icon('scan-barcode', size: 110, color: Colors.black),
              ),
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
                child: t('ISBN 바코드를 인식하고 있어요', 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      gap(24),
      Center(child: icon('scan-barcode', size: 28, color: p.muted)),
      gap(10),
      Center(child: t('바코드가 인식되면 책을 찾아요.', 11, color: p.muted)),
    ],
  );
  Future<ReadingImageExport> captureShelfImages() async {
    final rows = renderedShelfRows.map((row) => row.toList()).toList();
    final count = (rows.length / 3).ceil();
    final originalPage = shelfPage;
    final pages = <ReadingShelfImage>[];
    try {
      for (var page = 0; page < count; page++) {
        if (!mounted || !shelfPages.hasClients) {
          throw StateError('Shelf is no longer visible');
        }
        shelfPages.jumpToPage(page);
        shelfPage = page;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) throw StateError('Shelf is no longer visible');
        final boundary =
            shelfCaptureKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(
          pixelRatio: (1080 - 96) / boundary.size.width,
        );
        try {
          // Keep the shelf title and books, without any interactive controls.
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final scale = 984 / boundary.size.width;
          final title = TextPainter(
            text: TextSpan(
              text: '서가',
              style: p.text(
                (p.dark ? 36 : 28) * scale,
                weight: p.dark ? 600 : 700,
                serif: true,
                color: p.dark ? p.accent : p.ink,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 984);
          final shelfTop = 48 + title.height.ceil() + 48;
          final height = image.height + shelfTop + 48;
          canvas.drawRect(
            Rect.fromLTWH(0, 0, 1080, height.toDouble()),
            Paint()..color = p.background,
          );
          title.paint(canvas, const Offset(48, 48));
          title.dispose();
          canvas.drawLine(
            Offset(48, (shelfTop - 24).toDouble()),
            Offset(1032, (shelfTop - 24).toDouble()),
            Paint()
              ..color = p.ink
              ..strokeWidth = scale,
          );
          canvas.drawImage(image, Offset(48, shelfTop.toDouble()), Paint());
          final picture = recorder.endRecording();
          late ui.Image framedImage;
          try {
            framedImage = await picture.toImage(1080, height);
          } finally {
            picture.dispose();
          }
          ByteData? data;
          try {
            data = await framedImage.toByteData(format: ui.ImageByteFormat.png);
          } finally {
            framedImage.dispose();
          }
          if (data == null) throw StateError('PNG encoding failed');
          pages.add(
            ReadingShelfImage(
              books: rows.skip(page * 3).take(3).expand((row) => row),
              png: data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
              ),
            ),
          );
        } finally {
          image.dispose();
        }
      }
    } finally {
      if (mounted && shelfPages.hasClients) {
        shelfPages.jumpToPage(originalPage);
        shelfPage = originalPage;
      }
    }
    return ReadingImageExport.shelf(title: '나의 서가', pages: pages);
  }

  Future<void> exportImages({ReadingCollection? collection}) async {
    if (exporting) return;
    if (widget.onExport == null) {
      notice('이미지 저장은 본앱에서 사용할 수 있어요.');
      return;
    }
    if (collection != null && !loadedCollections.contains(collection.id)) {
      notice('컬렉션을 먼저 불러와주세요.');
      return;
    }
    final books = collection == null
        ? shelfBooks
        : [for (final id in collection.slots.whereType<String>()) catalog[id]!];
    if (books.isEmpty) {
      notice('저장할 책이 없어요.');
      return;
    }
    exporting = true;
    try {
      await widget.onExport!(
        collection == null
            ? await captureShelfImages()
            : ReadingImageExport.collection(
                title: collection.name,
                slots: [
                  for (final id in collection.slots)
                    id == null ? null : catalog[id]!,
                ],
              ),
      );
    } catch (_) {
      if (mounted) notice('이미지를 만들지 못했어요. 다시 시도해주세요.');
    } finally {
      exporting = false;
    }
  }

  void notice(String message) {
    // Product-only actions without a backend remain local in this offline preview.
    final context = widget.embedded
        ? this.context
        : previewNavigator.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  void showDesignPicker() {
    if (isLive) {
      widget.onSettings?.call();
      return;
    }
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

class _KeepAliveShelfPage extends StatefulWidget {
  const _KeepAliveShelfPage({required this.child, required this.keepAlive});
  final Widget child;
  final bool keepAlive;
  @override
  State<_KeepAliveShelfPage> createState() => _KeepAliveShelfPageState();
}

class _KeepAliveShelfPageState extends State<_KeepAliveShelfPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;
  @override
  void didUpdateWidget(covariant _KeepAliveShelfPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// Backwards-compatible offline preview entry points.
typedef DesignPreview = ReadingWorkspace;
typedef DesignPreviewState = ReadingWorkspaceState;
