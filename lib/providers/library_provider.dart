import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/folder.dart';
import '../services/json_sync_service.dart';
import '../services/quick_add.dart';
import '../services/storage_service.dart';

/// Bucket counts for a set of cards.
class DeckCounts {
  const DeckCounts({this.review = 0, this.problem = 0, this.learned = 0});
  final int review;
  final int problem;
  final int learned;
  int get total => review + problem + learned;
  double get learnedRatio => total == 0 ? 0 : learned / total;
}

/// What a study hub / session works on.
enum SourceKind { deck, folder, starred, multi, hardest }

/// Days until a learned word comes back to "Qaytarish", by level 1–6.
const kReturnDays = [3, 7, 14, 30, 60, 120];

/// How many words the "Eng qiyin so'zlar" list holds.
const kHardestSize = 50;

class CardSource {
  const CardSource.deck(this.id)
      : kind = SourceKind.deck,
        deckIds = const [];
  const CardSource.folder(this.id)
      : kind = SourceKind.folder,
        deckIds = const [];
  const CardSource.starred()
      : kind = SourceKind.starred,
        id = '',
        deckIds = const [];
  const CardSource.multi(this.deckIds)
      : kind = SourceKind.multi,
        id = '';
  const CardSource.hardest()
      : kind = SourceKind.hardest,
        id = '',
        deckIds = const [];

  final SourceKind kind;
  final String id;
  final List<String> deckIds;

  /// Stable key used for records ("best score in this set").
  String get key => switch (kind) {
        SourceKind.deck => id,
        SourceKind.folder => 'folder:$id',
        SourceKind.starred => 'starred',
        SourceKind.multi => 'multi:${([...deckIds]..sort()).join(',')}',
        SourceKind.hardest => 'hardest',
      };
}

/// Folders, decks and cards + every write to the database.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider() {
    _reload();
    refreshDue();
  }

  final Box<Flashcard> _cardBox = StorageService.cards;
  final Box<Deck> _deckBox = StorageService.decks;
  final Box<Folder> _folderBox = StorageService.folders;

  List<Folder> _folders = [];
  List<Deck> _decks = [];
  List<Flashcard> _cards = [];

  List<Folder> get folders => List.unmodifiable(_folders);
  List<Deck> get decks => List.unmodifiable(_decks);
  List<Flashcard> get allCards => List.unmodifiable(_cards);
  bool get isEmpty => _decks.isEmpty && _folders.isEmpty;

  void _reload() {
    _folders = _folderBox.values.toList()..sort(_byOrderThenName((f) => f.order, (f) => f.name));
    _decks = _deckBox.values.toList()..sort(_byOrderThenName((d) => d.order, (d) => d.name));
    _cards = _cardBox.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static int Function(T, T) _byOrderThenName<T>(int Function(T) order, String Function(T) name) =>
      (a, b) {
        final o = order(a).compareTo(order(b));
        return o != 0 ? o : naturalCompare(name(a), name(b));
      };

  /// "Mavzu 2" < "Mavzu 10".
  static int naturalCompare(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    final pb = re.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]), nb = int.tryParse(pb[i]);
      final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  // ---------------- Lookups ----------------

  Folder? folderById(String? id) {
    if (id == null) return null;
    for (final f in _folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  Deck? deckById(String id) {
    for (final d in _decks) {
      if (d.id == id) return d;
    }
    return null;
  }

  Flashcard? cardById(String id) {
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Folders directly inside [parentId] (null = top level).
  List<Folder> subfolders(String? parentId) =>
      _folders.where((f) => f.parentId == parentId).toList();

  /// Decks directly inside [folderId] (null = top level).
  List<Deck> decksIn(String? folderId) =>
      _decks.where((d) => d.folderId == folderId).toList();

  /// Folder ids of [folderId] and all its sub-folders.
  Set<String> _folderTree(String folderId) =>
      {folderId, ...subfolders(folderId).map((f) => f.id)};

  /// Every deck inside the folder, including its sub-folders.
  List<Deck> decksInTree(String folderId) {
    final ids = _folderTree(folderId);
    return _decks.where((d) => d.folderId != null && ids.contains(d.folderId)).toList();
  }

  /// "Arabcha › Kitob 1"
  List<String> folderPathNames(String? folderId) {
    final f = folderById(folderId);
    if (f == null) return const [];
    final parent = folderById(f.parentId);
    return [if (parent != null) parent.name, f.name];
  }

  List<String> deckFolderPath(Deck d) => folderPathNames(d.folderId);

  String deckTitle(Deck d) => [...deckFolderPath(d), d.name].join(' › ');

  /// All folders in display order: each root followed by its sub-folders.
  List<Folder> get foldersFlat => [
        for (final root in subfolders(null)) ...[root, ...subfolders(root.id)],
      ];

  // ---------------- Cards for a source ----------------

  List<Flashcard> cardsOf(String deckId) => _cards.where((c) => c.deckId == deckId).toList();

  List<Flashcard> cardsFor(CardSource s) {
    switch (s.kind) {
      case SourceKind.deck:
        return cardsOf(s.id);
      case SourceKind.folder:
        final ids = decksInTree(s.id).map((d) => d.id).toSet();
        return _cards.where((c) => ids.contains(c.deckId)).toList();
      case SourceKind.starred:
        return _cards.where((c) => c.starred).toList();
      case SourceKind.multi:
        final ids = s.deckIds.toSet();
        return _cards.where((c) => ids.contains(c.deckId)).toList();
      case SourceKind.hardest:
        return hardestCards;
    }
  }

  DeckCounts count(Iterable<Flashcard> cards) {
    var r = 0, p = 0, l = 0;
    for (final c in cards) {
      switch (c.status) {
        case CardStatus.review:
          r++;
        case CardStatus.problem:
          p++;
        case CardStatus.learned:
          l++;
      }
    }
    return DeckCounts(review: r, problem: p, learned: l);
  }

  DeckCounts countsOf(String deckId) => count(_cards.where((c) => c.deckId == deckId));
  DeckCounts countsFor(CardSource s) => count(cardsFor(s));
  DeckCounts countsOfFolder(String folderId) => countsFor(CardSource.folder(folderId));
  DeckCounts get totalCounts => count(_cards);
  int get starredCount => _cards.where((c) => c.starred).length;

  /// Words with the most mistakes (at least one), worst first.
  List<Flashcard> get hardestCards {
    final list = _cards.where((c) => c.wrong > 0).toList()
      ..sort((a, b) {
        final w = b.wrong.compareTo(a.wrong);
        if (w != 0) return w;
        double ratio(Flashcard c) => c.wrong / (c.wrong + c.correct);
        return ratio(b).compareTo(ratio(a));
      });
    return list.take(kHardestSize).toList();
  }

  List<Deck> get starredDecks => _decks.where((d) => d.starred).toList();

  int get masteredDecks => _decks.where((d) {
        final c = countsOf(d.id);
        return c.total > 0 && c.learned == c.total;
      }).length;

  bool wordExists(String deckId, String word, {String? exceptId}) {
    final w = word.trim().toLowerCase();
    return _cards.any((c) => c.deckId == deckId && c.id != exceptId && c.word.toLowerCase() == w);
  }

  // ---------------- Folders ----------------

  int _nextFolderOrder(String? parentId) =>
      subfolders(parentId).fold(-1, (m, f) => f.order > m ? f.order : m) + 1;

  int _nextDeckOrder(String? folderId) =>
      decksIn(folderId).fold(-1, (m, d) => d.order > m ? d.order : m) + 1;

  Future<Folder> createFolder(String name, {String? parentId}) async {
    // Only 2 levels: a sub-folder's parent must be a root folder.
    final parent = folderById(parentId);
    final pid = parent == null ? null : (parent.isRoot ? parent.id : parent.parentId);
    final f = Folder.create(name: name, parentId: pid, order: _nextFolderOrder(pid));
    await _folderBox.put(f.id, f);
    _reload();
    notifyListeners();
    return f;
  }

  Future<void> renameFolder(Folder f, String name) async {
    await _folderBox.put(f.id, f.copyWith(name: name.trim()));
    _reload();
    notifyListeners();
  }

  /// Moves a folder under [newParentId] (null = top level). A folder that
  /// has sub-folders can only stay at the top level (2-level limit).
  Future<bool> moveFolder(Folder f, String? newParentId) async {
    if (newParentId == f.id) return false;
    if (newParentId != null) {
      final p = folderById(newParentId);
      if (p == null || !p.isRoot || subfolders(f.id).isNotEmpty) return false;
    }
    final moved = newParentId == null
        ? f.copyWith(clearParent: true, order: _nextFolderOrder(null))
        : f.copyWith(parentId: newParentId, order: _nextFolderOrder(newParentId));
    await _folderBox.put(f.id, moved);
    _reload();
    notifyListeners();
    return true;
  }

  /// Deletes the folder, its sub-folders, decks and cards.
  Future<void> deleteFolder(String folderId) async {
    final tree = _folderTree(folderId);
    final deckIds = decksInTree(folderId).map((d) => d.id).toSet();
    await _cardBox.deleteAll(_cards.where((c) => deckIds.contains(c.deckId)).map((c) => c.id));
    await _deckBox.deleteAll(deckIds);
    await _folderBox.deleteAll(tree);
    _reload();
    notifyListeners();
  }

  /// Saves a new drag-and-drop order.
  Future<void> reorderFolders(List<Folder> ordered) async {
    await _folderBox.putAll({
      for (var i = 0; i < ordered.length; i++) ordered[i].id: ordered[i].copyWith(order: i),
    });
    _reload();
    notifyListeners();
  }

  Future<void> reorderDecks(List<Deck> ordered) async {
    await _deckBox.putAll({
      for (var i = 0; i < ordered.length; i++) ordered[i].id: ordered[i].copyWith(order: i),
    });
    _reload();
    notifyListeners();
  }

  /// Finds (or creates) a language (top-level folder) by name.
  Future<String> ensureLanguage(String name) async {
    final n = name.trim().isEmpty ? 'Import' : name.trim();
    final existing = subfolders(null).where((f) => f.name.toLowerCase() == n.toLowerCase()).firstOrNull;
    return existing?.id ?? (await createFolder(n)).id;
  }

  /// Clears every language, book, word and statistic.
  Future<void> wipeAll() async {
    await StorageService.wipeLibrary();
    _reload();
    notifyListeners();
  }

  // ---------------- Decks ----------------

  Future<Deck> createDeck(String name, {String? folderId}) async {
    var deck = Deck.create(name: name, folderId: folderId, order: _nextDeckOrder(folderId));
    // A new deck takes the languages of its neighbours in the same folder.
    final sibling = _decks.where((d) => d.folderId == folderId && d.hasLangs).firstOrNull;
    if (folderId != null && sibling != null) {
      deck = deck.copyWith(
        wordLang: sibling.wordLang,
        primaryLang: sibling.primaryLang,
        secondaryLang: sibling.secondaryLang,
      );
    }
    await _deckBox.put(deck.id, deck);
    _reload();
    notifyListeners();
    return deck;
  }

  Future<void> updateDeck(Deck deck, {required String name, required String? folderId}) async {
    final moved = folderId != deck.folderId;
    final updated = folderId == null
        ? deck.copyWith(name: name, clearFolder: true, order: moved ? _nextDeckOrder(null) : null)
        : deck.copyWith(name: name, folderId: folderId, order: moved ? _nextDeckOrder(folderId) : null);
    await _deckBox.put(deck.id, updated);
    _reload();
    notifyListeners();
  }

  /// Sets the word / translation languages of the given decks.
  Future<void> setDeckLangs(Iterable<String> deckIds,
      {required String word, required String primary, required String secondary}) async {
    for (final id in deckIds) {
      final d = deckById(id);
      if (d == null) continue;
      await _deckBox.put(
          d.id, d.copyWith(wordLang: word, primaryLang: primary, secondaryLang: secondary));
    }
    _reload();
    notifyListeners();
  }

  Future<void> toggleDeckStar(String deckId) async {
    final d = deckById(deckId);
    if (d == null) return;
    await _deckBox.put(d.id, d.copyWith(starred: !d.starred));
    _reload();
    notifyListeners();
  }

  Future<void> deleteDeck(String deckId) async {
    await _cardBox.deleteAll(cardsOf(deckId).map((c) => c.id));
    await _deckBox.delete(deckId);
    _reload();
    notifyListeners();
  }

  Future<void> resetProgress(CardSource s) async {
    await _cardBox.putAll({
      for (final c in cardsFor(s)) c.id: c.copyWith(status: CardStatus.review, level: 0, clearDue: true).touched(),
    });
    _reload();
    notifyListeners();
  }

  // ---------------- Cards ----------------

  Future<void> upsertCard(Flashcard card) async {
    await _cardBox.put(card.id, card);
    final i = _cards.indexWhere((c) => c.id == card.id);
    if (i >= 0) {
      _cards[i] = card;
    } else {
      _cards.add(card);
    }
    notifyListeners();
  }

  Future<void> deleteCard(String id) async {
    await _cardBox.delete(id);
    _cards.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> updateMnemonic(String id, String text) async {
    final card = cardById(id);
    if (card == null || card.mnemonic == text.trim()) return;
    await upsertCard(card.copyWith(mnemonic: text.trim()).touched());
  }

  Future<void> setStatus(String id, CardStatus status) async {
    final card = cardById(id);
    if (card == null || card.status == status) return;
    final learned = status == CardStatus.learned;
    final level = learned ? (card.level < 1 ? 1 : card.level) : 0;
    await upsertCard(card
        .copyWith(
          status: status,
          level: level,
          dueAt: learned ? DateTime.now().toUtc().add(Duration(days: kReturnDays[level - 1])) : null,
          clearDue: !learned,
        )
        .touched());
  }

  /// Learned words whose time has come go back to "Qaytarish".
  /// Returns how many moved. Called at start-up and when the app resumes.
  Future<int> refreshDue() async {
    final now = DateTime.now().toUtc();
    final due = _cards
        .where((c) => c.status == CardStatus.learned && c.dueAt != null && !c.dueAt!.isAfter(now))
        .toList();
    if (due.isEmpty) return 0;
    await _cardBox.putAll({
      for (final c in due) c.id: c.copyWith(status: CardStatus.review, clearDue: true).touched(),
    });
    _reload();
    notifyListeners();
    return due.length;
  }

  /// Adds parsed "word - translation" rows to a deck; skips words already
  /// in it. Returns how many were added.
  Future<int> quickAdd(String deckId, List<QuickRow> rows) async {
    final existing = cardsOf(deckId).map((c) => c.word.trim().toLowerCase()).toSet();
    final fresh = <Flashcard>[];
    for (final r in rows) {
      final key = r.word.trim().toLowerCase();
      if (key.isEmpty || !existing.add(key)) continue;
      fresh.add(Flashcard.create(
        deckId: deckId,
        word: r.word,
        ipa: r.ipa,
        primaryTranslation: r.primary,
        secondaryTranslation: r.secondary,
      ));
    }
    await _cardBox.putAll({for (final c in fresh) c.id: c});
    _reload();
    notifyListeners();
    return fresh.length;
  }

  Future<void> toggleStar(String id) async {
    final card = cardById(id);
    if (card == null) return;
    await upsertCard(card.copyWith(starred: !card.starred).touched());
  }

  /// Bilaman → Yodlangan, Bilmayman → Muammoli.
  /// Returns the card's status BEFORE the answer (null if not found).
  Future<CardStatus?> answer(String id, {required bool known}) async {
    final card = cardById(id);
    if (card == null) return null;
    final now = DateTime.now().toUtc();
    final level = known ? (card.level + 1).clamp(1, kReturnDays.length) : 0;
    await upsertCard(card.copyWith(
      status: known ? CardStatus.learned : CardStatus.problem,
      correct: card.correct + (known ? 1 : 0),
      wrong: card.wrong + (known ? 0 : 1),
      level: level,
      dueAt: known ? now.add(Duration(days: kReturnDays[level - 1])) : null,
      clearDue: !known,
      lastReviewedAt: now,
      updatedAt: now,
    ));
    return card.status;
  }

  // ---------------- Import ----------------

  /// Imports books.
  ///  - LexiFlip exports: folderPath = [language], deck id → merged by id.
  ///  - Files with folderPath [language, book] (lessons): every lesson is
  ///    merged into ONE book named after the 2nd level.
  ///  - Otherwise the book is matched by language + name, or created.
  Future<MergeResult> importDecks(List<ImportedDeck> incoming) async {
    final total = MergeResult();
    for (final imp in incoming) {
      var bookName = imp.name;
      String? matchId = imp.id;
      String? langId = imp.targetFolderId;
      if (langId == null) {
        langId = await ensureLanguage(imp.folderPath.isEmpty ? 'Import' : imp.folderPath.first);
        if (imp.folderPath.length >= 2) {
          bookName = imp.folderPath[1];
          matchId = null;
        }
      }

      Deck? target = matchId == null ? null : deckById(matchId);
      target ??= _decks
          .where((d) => d.folderId == langId && d.name.toLowerCase() == bookName.toLowerCase())
          .firstOrNull;
      if (target == null) {
        final now = DateTime.now().toUtc();
        target = matchId != null
            ? Deck(
                id: matchId,
                name: bookName,
                folderId: langId,
                order: _nextDeckOrder(langId),
                createdAt: now,
                updatedAt: now,
              )
            : Deck.create(name: bookName, folderId: langId, order: _nextDeckOrder(langId));
        await _deckBox.put(target.id, target);
        _reload();
      }
      if (imp.wordLang != null || imp.primaryLang != null || imp.secondaryLang != null) {
        await _deckBox.put(
          target.id,
          target.copyWith(
            wordLang: imp.wordLang,
            primaryLang: imp.primaryLang,
            secondaryLang: imp.secondaryLang,
          ),
        );
        _reload();
      }
      final (toWrite, result) =
          JsonSyncService.merge(target.id, cardsOf(target.id), _cards, imp.cards);
      await _cardBox.putAll({for (final c in toWrite) c.id: c});
      _reload();
      total.addAll(result);
    }
    notifyListeners();
    return total;
  }
}
