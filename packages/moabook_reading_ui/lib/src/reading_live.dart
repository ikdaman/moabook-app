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
        final books = shelf.books
            .map(
              (book) => book.withPageCountFallback(
                library[book.id]?.totalPage ?? catalog[book.id]?.totalPage,
              ),
            )
            .toList();
        library
          ..clear()
          ..addEntries(books.map((b) => MapEntry(b.id, b)));
        catalog.addAll(library);
        totalShelfCount = shelf.totalCount;
        shelfLoaded = true;
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
      final summaries = (await gateway.loadCollections()).reversed.toList();
      if (!mounted || request != collectionsRequest) return;
      _update(() {
        collectionSummaries
          ..clear()
          ..addEntries(summaries.map((c) => MapEntry(c.id, c)));
        final previous = {for (final value in collectionData) value.id: value};
        final ids = summaries.map((summary) => summary.id).toSet();
        collectionData = [
          for (final summary in summaries)
            ReadingCollection(
              id: summary.id,
              name: summary.name,
              slots: previous[summary.id]?.slots,
            ),
        ];
        loadedCollections.retainAll(ids);
        staleCollections
          ..clear()
          ..addAll(loadedCollections);
        collectionsLoaded = true;
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
      collectionData.insert(0, value);
    } else {
      collectionData[index] = value;
    }
    catalog.addEntries(detail.books.map((b) => MapEntry(b.id, b)));
    loadedCollections.add(value.id);
    staleCollections.remove(value.id);
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
        ((loadedCollections.contains(id) && !staleCollections.contains(id)) ||
            loadingCollections.contains(id))) {
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
        final book = card.book.withPageCountFallback(
          library[id]?.totalPage ?? catalog[id]?.totalPage,
        );
        cards[id] = ReadingCard(
          book: book,
          createdDate: card.createdDate,
          status: card.status,
          recordCount: card.recordCount,
        );
        selectedBook = book;
        catalog[id] = book;
        if (library.containsKey(id)) library[id] = book;
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
    final query = keyword.trim();
    _update(() {
      searchQuery = activeSearchQuery = query;
      isSearching = query.isNotEmpty;
      searchError = searchMoreError = null;
      remoteSearchResults = [];
      remoteSearchPage = 0;
      remoteSearchTotalCount = null;
      remoteSearchHasMore = loadingMoreSearch = false;
      screen = 'search';
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    if (query.isEmpty) return;
    try {
      final result = await gateway.searchBooks(query);
      if (!mounted || request != searchRequest) return;
      if (result.page != 1) throw const FormatException('Wrong search page');
      _update(() {
        remoteSearchResults = {
          for (final book in result.books) book.id: book,
        }.values.toList();
        remoteSearchPage = result.page;
        remoteSearchTotalCount = result.totalCount;
        remoteSearchHasMore = result.hasMore;
        isSearching = false;
        screen = result.books.isEmpty ? 'search-empty' : 'search';
      });
      _checkSearchAfterLayout();
    } catch (_) {
      if (!mounted || request != searchRequest) return;
      _update(() {
        isSearching = false;
        searchError = '검색 결과를 불러오지 못했어요.';
        screen = 'search-empty';
      });
    }
  }

  Future<void> loadMoreRemoteBooks() async {
    if (isSearching || loadingMoreSearch || !remoteSearchHasMore) return;
    final request = searchRequest;
    final nextPage = remoteSearchPage + 1;
    final query = activeSearchQuery;
    _update(() {
      loadingMoreSearch = true;
      searchMoreError = null;
    });
    try {
      final result = await gateway.searchBooks(query, page: nextPage);
      if (!mounted || request != searchRequest) return;
      if (result.page != nextPage) {
        throw const FormatException('Wrong search page');
      }
      _update(() {
        remoteSearchResults = {
          for (final book in remoteSearchResults) book.id: book,
          for (final book in result.books) book.id: book,
        }.values.toList();
        remoteSearchPage = result.page;
        remoteSearchTotalCount = result.totalCount;
        remoteSearchHasMore = result.hasMore;
        loadingMoreSearch = false;
      });
      _checkSearchAfterLayout();
    } catch (_) {
      if (!mounted || request != searchRequest) return;
      _update(() {
        loadingMoreSearch = false;
        searchMoreError = '다음 검색 결과를 불러오지 못했어요. 다시 시도해주세요.';
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
      if (mounted) notice('바코드로 책을 찾지 못했어요. 다시 시도해주세요.');
    } finally {
      selectingMedia = false;
    }
  }

  Future<void> confirmRemoteBook() async {
    if (isSaving) return;
    _update(() => isSaving = true);
    try {
      final result = await gateway.checkBook(
        selectedBook,
        collectionId: targetCollectionId,
      );
      if (!mounted) return;
      if (result.bookId == null) {
        reasonDraft = '';
        bookSaveCategory = ReadingCategory.todo;
        operationError = null;
        startedDate = finishedDate = readingDay(DateTime.now());
        go('save-wish');
      } else {
        final card = await gateway.loadCard(result.bookId!);
        if (!mounted) return;
        selectedBook = card.book;
        if (targetCollectionId == null) {
          go('duplicate');
        } else if (result.alreadyInCollection) {
          go('collection-duplicate');
        } else {
          // This method owns its own submission lock.
          _update(() => isSaving = false);
          await addRemoteBookToCollection();
        }
      }
    } catch (_) {
      if (mounted) notice('저장 여부를 확인하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) _update(() => isSaving = false);
    }
  }

  Future<void> saveRemoteBook() async {
    if (isSaving) return;
    final searchBook = selectedBook;
    final key = searchBook.id;
    if (uncertainInitialBookWrites.contains(key)) return;
    final category = bookSaveCategory;
    final date = category == ReadingCategory.inProgress
        ? startedDate
        : category == ReadingCategory.done
        ? finishedDate
        : readingDay(DateTime.now());
    final memo = category == ReadingCategory.todo ? reasonDraft.trim() : '';
    _update(() {
      isSaving = true;
      operationError = null;
    });
    var creatingBook = false;
    var creatingInitialRecord = false;
    try {
      var id = pendingSavedBooks[key];
      if (id == null) {
        final check = await gateway.checkBook(
          searchBook,
          collectionId: targetCollectionId,
        );
        if (!mounted) return;
        if (check.bookId != null) {
          if (uncertainBookWrites.contains(key)) {
            id = check.bookId!;
            pendingSavedBooks[key] = id;
            uncertainBookWrites.remove(key);
          } else {
            final card = await gateway.loadCard(check.bookId!);
            if (!mounted) return;
            selectedBook = card.book;
            if (targetCollectionId == null) {
              go('duplicate');
            } else if (check.alreadyInCollection) {
              go('collection-duplicate');
            } else {
              _update(() => isSaving = false);
              await addRemoteBookToCollection();
            }
            return;
          }
        } else {
          if (uncertainBookWrites.contains(key)) {
            _update(
              () => operationError = '책 저장 결과를 아직 확인하지 못했어요. 잠시 후 다시 확인해주세요.',
            );
            return;
          }
          creatingBook = true;
          id = await gateway.saveBook(searchBook, reason: memo);
          // Keep this even when the screen unmounts while the write is running.
          pendingSavedBooks[key] = id;
          creatingBook = false;
        }
      }
      if (!initializedSavedBooks.contains(key)) {
        creatingInitialRecord = true;
        await gateway.addRecord(id, category: category, date: date, memo: memo);
        initializedSavedBooks.add(key);
        creatingInitialRecord = false;
      }
      final card = await gateway.loadCard(id);
      if (!mounted) return;
      pendingSavedBooks.remove(key);
      initializedSavedBooks.remove(key);
      selectedBook = card.book;
      await refreshRemoteShelf();
      if (!mounted) return;
      notice('책이 잘 저장되었습니다!');
      if (targetCollectionId != null) {
        _update(() => isSaving = false);
        await addRemoteBookToCollection();
      } else {
        _update(() {
          history
            ..clear()
            ..add('shelf');
          screen = 'card-front';
        });
        await loadRemoteCard(id);
      }
    } on ReadingWriteUncertain {
      if (creatingBook) uncertainBookWrites.add(key);
      if (creatingInitialRecord) uncertainInitialBookWrites.add(key);
      if (mounted) {
        _update(
          () => operationError = creatingInitialRecord
              ? '책은 저장됐지만 독서 상태의 저장 결과를 확인하지 못했어요. 독서카드에서 확인해주세요.'
              : '저장 결과를 확인하지 못했어요. 다시 누르면 저장 여부부터 확인해요.',
        );
      }
    } catch (_) {
      if (mounted) {
        _update(
          () => operationError = pendingSavedBooks.containsKey(key)
              ? (creatingInitialRecord
                    ? '책은 저장됐지만 독서 상태를 저장하지 못했어요. 다시 시도해주세요.'
                    : '책은 저장됐지만 독서카드를 불러오지 못했어요. 다시 확인해주세요.')
              : '책을 저장하지 못했어요. 입력은 그대로 남아 있어요.',
        );
      }
    } finally {
      if (mounted) _update(() => isSaving = false);
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
        collectionData.insert(
          0,
          ReadingCollection(id: created.id, name: created.name),
        );
        collectionPage = 0;
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
      final next = current.collection.add(
        selectedBook.id,
        slotIndex: targetCollectionSlot,
      );
      final result = await gateway.updateCollection(next);
      if (!mounted) return;
      _update(() {
        installRemoteCollection(result);
        collectionPage = collectionData.indexWhere((c) => c.id == id);
        targetCollectionId = null;
        targetCollectionSlot = null;
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
      showRecordComplete();
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
    final id = selectedBook.yes24Id;
    final url =
        selectedBook.link ??
        (id == null
            ? null
            : 'https://www.yes24.com/product/goods/${Uri.encodeQueryComponent(id)}');
    if (url != null) {
      unawaited(widget.onOpenLink?.call(url) ?? Future<void>.value());
    }
  }

  Widget? remoteBlockingBody() {
    if (!isLive || _sectionTransitioning) return null;
    if (isShelfScreen && !shelfLoaded && (shelfLoading || shelfError != null)) {
      return remoteMessage(
        shelfError,
        () => unawaited(refreshRemoteShelf()),
        loading: shelfLoading,
      );
    }
    if ((isCollectionScreen || screen == 'collections') &&
        !collectionsLoaded &&
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
