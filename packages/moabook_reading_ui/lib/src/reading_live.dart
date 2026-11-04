part of 'reading_workspace.dart';

extension _LiveReadingWorkspace on ReadingWorkspaceState {
  Future<void> refreshRemote() async {
    if (!isLive || isSaving) return;
    await Future.wait([refreshRemoteShelf(), refreshRemoteCollections()]);
    if (mounted && screen.startsWith('card') && selectedBook.id.isNotEmpty) {
      await loadRemoteCard(selectedBook.id);
    }
  }

  Future<void> refreshRemoteShelf() async {
    final request = ++shelfRequest;
    _update(() {
      shelfLoading = true;
      shelfError = null;
    });
    try {
      final shelf = await gateway.loadShelf();
      if (!mounted || request != shelfRequest) return;
      _update(() {
        library
          ..clear()
          ..addEntries(shelf.books.map((b) => MapEntry(b.id, b)));
        catalog.addAll(library);
        totalShelfCount = shelf.totalCount;
        shelfLoading = false;
      });
      restoreShelfPage();
    } catch (_) {
      if (!mounted || request != shelfRequest) return;
      _update(() {
        shelfLoading = false;
        shelfError = '서가를 불러오지 못했어요.';
      });
    }
  }

  Future<void> refreshRemoteCollections() async {
    final request = ++collectionsRequest;
    _update(() {
      collectionsLoading = true;
      collectionsError = null;
    });
    final selectedId = collectionData.isEmpty ? null : currentCollection.id;
    try {
      final summaries = await gateway.loadCollections();
      if (!mounted || request != collectionsRequest) return;
      _update(() {
        collectionSummaries
          ..clear()
          ..addEntries(summaries.map((c) => MapEntry(c.id, c)));
        collectionData = [
          for (final summary in summaries)
            ReadingCollection(id: summary.id, name: summary.name),
        ];
        loadedCollections.clear();
        loadingCollections.clear();
        collectionErrors.clear();
        collectionPage = math.max(
          0,
          collectionData.indexWhere((c) => c.id == selectedId),
        );
        collectionsLoading = false;
      });
      restoreShelfPage();
      if (collectionData.isNotEmpty &&
          (isCollectionScreen || screen == 'collections')) {
        await loadRemoteCollection(currentCollection.id);
      }
    } catch (_) {
      if (!mounted || request != collectionsRequest) return;
      _update(() {
        collectionsLoading = false;
        collectionsError = '컬렉션을 불러오지 못했어요.';
      });
    }
  }

  void installRemoteCollection(ReadingCollectionDetail detail) {
    final value = detail.collection;
    final index = collectionData.indexWhere((c) => c.id == value.id);
    if (index < 0) {
      collectionData.add(value);
    } else {
      collectionData[index] = value;
    }
    catalog.addEntries(detail.books.map((b) => MapEntry(b.id, b)));
    loadedCollections.add(value.id);
    collectionErrors.remove(value.id);
    collectionSummaries[value.id] = ReadingCollectionSummary(
      id: value.id,
      name: value.name,
      representatives: [
        for (final id in value.slots.whereType<String>().take(2)) catalog[id]!,
      ],
    );
  }

  Future<void> loadRemoteCollection(String id, {bool force = false}) async {
    if (!force &&
        (loadedCollections.contains(id) || loadingCollections.contains(id))) {
      return;
    }
    final generation = collectionsRequest;
    final request = (collectionRequests[id] ?? 0) + 1;
    collectionRequests[id] = request;
    _update(() {
      loadingCollections.add(id);
      collectionErrors.remove(id);
    });
    try {
      final detail = await gateway.loadCollection(id);
      if (!mounted ||
          generation != collectionsRequest ||
          collectionRequests[id] != request) {
        return;
      }
      _update(() {
        installRemoteCollection(detail);
        loadingCollections.remove(id);
      });
    } catch (_) {
      if (!mounted ||
          generation != collectionsRequest ||
          collectionRequests[id] != request) {
        return;
      }
      _update(() {
        loadingCollections.remove(id);
        collectionErrors[id] = '이 컬렉션을 불러오지 못했어요.';
      });
    }
  }

  Future<void> loadRemoteCard(String id) async {
    final request = ++cardRequest;
    _update(() {
      cardLoading = true;
      cardError = null;
      recordsError = null;
    });
    try {
      final card = await gateway.loadCard(id);
      if (!mounted || request != cardRequest) return;
      _update(() {
        cards[id] = card;
        selectedBook = card.book;
        catalog[id] = card.book;
        if (library.containsKey(id)) library[id] = card.book;
      });
    } catch (_) {
      if (!mounted || request != cardRequest) return;
      _update(() {
        cardLoading = false;
        cardError = '독서카드를 불러오지 못했어요.';
      });
      return;
    }
    try {
      final records = await gateway.loadRecords(id);
      if (!mounted || request != cardRequest) return;
      _update(() {
        journals[id] = ReadingJournal(records);
        loadedRecordBooks.add(id);
        cardLoading = false;
      });
    } catch (_) {
      if (!mounted || request != cardRequest) return;
      _update(() {
        cardLoading = false;
        recordsError = '기록 목록을 불러오지 못했어요.';
      });
    }
  }

  Future<void> searchRemoteBooks(String keyword) async {
    final request = ++searchRequest;
    _update(() {
      searchQuery = keyword.trim();
      isSearching = searchQuery.isNotEmpty;
      searchError = null;
      remoteSearchResults = [];
      screen = 'search';
    });
    if (searchQuery.isEmpty) return;
    try {
      final results = await gateway.searchBooks(searchQuery);
      if (!mounted || request != searchRequest) return;
      _update(() {
        remoteSearchResults = results;
        isSearching = false;
        screen = results.isEmpty ? 'search-empty' : 'search';
      });
    } catch (_) {
      if (!mounted || request != searchRequest) return;
      _update(() {
        isSearching = false;
        searchError = '검색 결과를 불러오지 못했어요.';
      });
    }
  }

  Future<void> selectRemoteMedia(
    Future<ReadingBook?> Function()? select,
  ) async {
    if (select == null || isSaving || selectingMedia) return;
    selectingMedia = true;
    try {
      final book = await select();
      if (!mounted || book == null) return;
      selectedBook = book;
      go('book-info');
    } catch (_) {
      if (mounted) notice('사진에서 책을 찾지 못했어요. 다시 시도해주세요.');
    } finally {
      selectingMedia = false;
    }
  }

  void confirmRemoteBook() {
    final exact =
        library[selectedBook.id] ??
        catalog.values
            .where(
              (b) =>
                  ((selectedBook.aladinId != null &&
                          b.aladinId == selectedBook.aladinId) ||
                      (selectedBook.yes24Id != null &&
                          b.yes24Id == selectedBook.yes24Id) ||
                      (selectedBook.isbn13?.isNotEmpty == true &&
                          b.isbn13 == selectedBook.isbn13)) &&
                  !b.id.contains(':'),
            )
            .firstOrNull;
    if (exact == null) {
      notice('새 책 저장과 중복 확인은 아직 지원하지 않아요. 서가에 있는 책의 기록은 남길 수 있어요.');
      return;
    }
    selectedBook = exact;
    if (targetCollectionId == null) {
      go('duplicate');
    } else if (currentCollection.contains(exact.id)) {
      go('collection-duplicate');
    } else {
      unawaited(addRemoteBookToCollection());
    }
  }

  Future<void> beginRemoteCollectionEdit() async {
    final id = currentCollection.id;
    await loadRemoteCollection(id, force: true);
    if (!mounted ||
        collectionErrors.containsKey(id) ||
        !loadedCollections.contains(id)) {
      return;
    }
    editingCollection = collectionData.firstWhere((c) => c.id == id);
    collectionNameDraft = editingCollection!.name;
    operationError = null;
    go('collection-edit');
  }

  Future<void> saveRemoteCollectionEdit() async {
    if (isSaving ||
        editingCollection == null ||
        collectionNameDraft.trim().isEmpty) {
      return;
    }
    final draft = editingCollection!.rename(collectionNameDraft);
    _update(() {
      isSaving = true;
      operationError = null;
    });
    try {
      final result = await gateway.updateCollection(draft);
      if (!mounted) return;
      _update(() {
        installRemoteCollection(result);
        editingCollection = null;
        screen = history.isEmpty ? 'collection' : history.removeLast();
      });
      restoreShelfPage();
    } catch (_) {
      if (mounted) {
        _update(() => operationError = '편집 내용을 저장하지 못했어요. 입력은 그대로 남아 있어요.');
      }
    } finally {
      if (mounted) _update(() => isSaving = false);
    }
  }

  Future<void> createRemoteCollection() async {
    if (isSaving || collectionNameDraft.trim().isEmpty) return;
    _update(() {
      isSaving = true;
      operationError = null;
    });
    try {
      final detail = await gateway.createCollection(collectionNameDraft);
      if (!mounted) return;
      _update(() {
        installRemoteCollection(detail);
        collectionPage = collectionData.indexWhere(
          (c) => c.id == detail.collection.id,
        );
        screen = 'collection';
        history.clear();
      });
      restoreShelfPage();
    } on CollectionCreatedNeedsReload catch (created) {
      if (!mounted) return;
      _update(() {
        collectionData.add(
          ReadingCollection(id: created.id, name: created.name),
        );
        collectionPage = collectionData.length - 1;
        collectionErrors[created.id] = '컬렉션은 만들었지만 내용을 불러오지 못했어요.';
        screen = 'collection';
        history.clear();
      });
      restoreShelfPage();
    } on ReadingWriteUncertain {
      if (!mounted) return;
      _update(() {
        creationWriteUncertain = true;
        operationError = '만들기 결과를 확인하지 못했어요. 다시 만들기 전에 목록을 확인해주세요.';
      });
    } catch (_) {
      if (mounted) _update(() => operationError = '컬렉션을 만들지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) _update(() => isSaving = false);
    }
  }

  Future<void> addRemoteBookToCollection() async {
    final id = targetCollectionId;
    if (id == null || isSaving) return;
    _update(() => isSaving = true);
    try {
      final current = await gateway.loadCollection(id);
      final next = current.collection.add(selectedBook.id);
      final result = await gateway.updateCollection(next);
      if (!mounted) return;
      _update(() {
        installRemoteCollection(result);
        collectionPage = collectionData.indexWhere((c) => c.id == id);
        targetCollectionId = null;
        history.clear();
        screen = 'collection';
      });
      restoreShelfPage();
    } on StateError catch (error) {
      if (mounted) notice(error.message.toString());
    } catch (_) {
      if (mounted) notice('컬렉션에 담지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) _update(() => isSaving = false);
    }
  }

  Future<void> saveRemoteRecord() async {
    if (isSaving ||
        recordWriteUncertain ||
        (recordCategory == ReadingCategory.free && memoDraft.trim().isEmpty)) {
      return;
    }
    final bookId = selectedBook.id;
    final category = recordCategory;
    final memo = memoDraft.trim();
    final date = recordDate;
    _update(() {
      isSaving = true;
      operationError = null;
    });
    try {
      final id = await gateway.addRecord(
        bookId,
        category: category,
        date: date,
        memo: memo,
      );
      if (!mounted) return;
      completedRecord = ReadingRecord(
        id: id,
        category: category,
        date: date,
        memo: memo,
      );
      // A failed refresh after a successful POST must not turn into another POST.
      await loadRemoteCard(bookId);
      if (!mounted) return;
      go('record-complete');
    } on ReadingWriteUncertain {
      if (!mounted) return;
      _update(() {
        recordWriteUncertain = true;
        operationError = '저장 결과를 확인하지 못했어요. 중복 저장을 피하려면 기록 목록을 먼저 확인해주세요.';
      });
    } catch (_) {
      if (mounted) {
        _update(() => operationError = '기록을 저장하지 못했어요. 입력은 그대로 남아 있어요.');
      }
    } finally {
      if (mounted) _update(() => isSaving = false);
    }
  }

  void openRemoteLink() {
    final id = selectedBook.aladinId;
    final url =
        selectedBook.link ??
        (id == null
            ? null
            : 'https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=${Uri.encodeQueryComponent(id)}');
    if (url != null) {
      unawaited(widget.onOpenLink?.call(url) ?? Future<void>.value());
    }
  }

  Widget? remoteBlockingBody() {
    if (!isLive) return null;
    if (isShelfScreen && (shelfLoading || shelfError != null)) {
      return remoteMessage(
        shelfError,
        () => unawaited(refreshRemoteShelf()),
        loading: shelfLoading,
      );
    }
    if ((isCollectionScreen || screen == 'collections') &&
        (collectionsLoading || collectionsError != null)) {
      return remoteMessage(
        collectionsError,
        () => unawaited(refreshRemoteCollections()),
        loading: collectionsLoading,
      );
    }
    if (screen.startsWith('card') && (cardLoading || cardError != null)) {
      return remoteMessage(
        cardError,
        () => unawaited(loadRemoteCard(selectedBook.id)),
        loading: cardLoading,
      );
    }
    if (screen == 'card-back' && recordsError != null) {
      return remoteMessage(
        recordsError,
        () => unawaited(loadRemoteCard(selectedBook.id)),
        loading: false,
      );
    }
    return null;
  }

  Widget remoteMessage(String? error, VoidCallback retry, {bool? loading}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading ?? error == null)
                CircularProgressIndicator(color: p.orange)
              else ...[
                t(error ?? '불러오지 못했어요.', 15, align: TextAlign.center),
                gap(18),
                button('다시 시도', retry),
              ],
            ],
          ),
        ),
      );
}
