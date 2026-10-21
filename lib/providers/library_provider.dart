import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../models/deck.dart';
import '../models/flashcard.dart';
import '../services/json_sync_service.dart';
import '../services/storage_service.dart';

/// Bucket counts for one deck (or all decks).
class DeckCounts {
  const DeckCounts({this.review = 0, this.problem = 0, this.learned = 0});
  final int review;
  final int problem;
  final int learned;
  int get total => review + problem + learned;
  double get learnedRatio => total == 0 ? 0 : learned / total;
}

/// All decks, folders and cards + every write to the database.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider() {
    _reload();
  }

  final Box<Flashcard> _cardBox = StorageService.cards;
  final Box<Deck> _deckBox = StorageService.decks;

  List<Deck> _decks = [];
  List<Flashcard> _cards = [];

  List<Deck> get decks => List.unmodifiable(_decks);
  List<Flashcard> get allCards => List.unmodifiable(_cards);
  bool get isEmpty => _decks.isEmpty;

  void _reload() {
    _decks = _deckBox.values.toList()
      ..sort((a, b) {
        final f = a.folder.toLowerCase().compareTo(b.folder.toLowerCase());
        return f != 0 ? f : _naturalCompare(a.name, b.name);
      });
    _cards = _cardBox.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// "Mavzu 2" < "Mavzu 10".
  static int _naturalCompare(String a, String b) {
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

  // ---------------- Queries ----------------

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

  /// Folder names in display order; '' (no folder) comes last.
  List<String> get folders {
    final set = _decks.map((d) => d.folder).toSet().toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return set;
  }

  List<String> get namedFolders => folders.where((f) => f.isNotEmpty).toList();

  List<Deck> decksIn(String folder) =>
      _decks.where((d) => d.folder == folder).toList();

  List<Flashcard> cardsOf(String deckId) =>
      _cards.where((c) => c.deckId == deckId).toList();

  List<Flashcard> cardsOfStatus(String deckId, CardStatus status) =>
      _cards.where((c) => c.deckId == deckId && c.status == status).toList();

  DeckCounts _count(Iterable<Flashcard> cards) {
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

  DeckCounts countsOf(String deckId) =>
      _count(_cards.where((c) => c.deckId == deckId));

  DeckCounts countsOfFolder(String folder) {
    final ids = decksIn(folder).map((d) => d.id).toSet();
    return _count(_cards.where((c) => ids.contains(c.deckId)));
  }

  DeckCounts get totalCounts => _count(_cards);

  /// Number of decks that are 100% learned (and non-empty).
  int get masteredDecks => _decks.where((d) {
        final c = countsOf(d.id);
        return c.total > 0 && c.learned == c.total;
      }).length;

  bool wordExists(String deckId, String word, {String? exceptId}) {
    final w = word.trim().toLowerCase();
    return _cards.any((c) =>
        c.deckId == deckId && c.id != exceptId && c.word.toLowerCase() == w);
  }

  // ---------------- Decks ----------------

  Future<Deck> createDeck(String name, {String folder = ''}) async {
    final deck = Deck.create(name: name, folder: folder);
    await _deckBox.put(deck.id, deck);
    _reload();
    notifyListeners();
    return deck;
  }

  Future<void> updateDeck(Deck deck, {String? name, String? folder}) async {
    await _deckBox.put(deck.id, deck.copyWith(name: name, folder: folder));
    _reload();
    notifyListeners();
  }

  Future<void> renameFolder(String from, String to) async {
    final updates = {
      for (final d in decksIn(from)) d.id: d.copyWith(folder: to.trim()),
    };
    await _deckBox.putAll(updates);
    _reload();
    notifyListeners();
  }

  Future<void> deleteDeck(String deckId) async {
    await _cardBox.deleteAll(cardsOf(deckId).map((c) => c.id));
    await _deckBox.delete(deckId);
    _reload();
    notifyListeners();
  }

  /// Puts every card of the deck back into "Qaytarilishi kerak".
  Future<void> resetProgress(String deckId) async {
    await _cardBox.putAll({
      for (final c in cardsOf(deckId))
        c.id: c.copyWith(status: CardStatus.review).touched(),
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
    await upsertCard(card.copyWith(status: status).touched());
  }

  /// Bilaman → Yodlangan, Bilmayman → Muammoli.
  Future<Flashcard?> answer(String id, {required bool known}) async {
    final card = cardById(id);
    if (card == null) return null;
    final now = DateTime.now().toUtc();
    final updated = card.copyWith(
      status: known ? CardStatus.learned : CardStatus.problem,
      correct: card.correct + (known ? 1 : 0),
      wrong: card.wrong + (known ? 0 : 1),
      lastReviewedAt: now,
      updatedAt: now,
    );
    await upsertCard(updated);
    return updated;
  }

  // ---------------- Import ----------------

  /// Imports decks: a deck with the same id, or the same folder + name, is
  /// merged into; otherwise a new deck is created.
  Future<MergeResult> importDecks(List<ImportedDeck> incoming) async {
    final total = MergeResult();
    for (final imp in incoming) {
      Deck? target = imp.id == null ? null : deckById(imp.id!);
      target ??= _decks
          .where((d) =>
              d.name.toLowerCase() == imp.name.toLowerCase() &&
              d.folder.toLowerCase() == imp.folder.toLowerCase())
          .firstOrNull;
      if (target == null) {
        final now = DateTime.now().toUtc();
        target = imp.id != null
            ? Deck(id: imp.id!, name: imp.name, folder: imp.folder, createdAt: now, updatedAt: now)
            : Deck.create(name: imp.name, folder: imp.folder);
        await _deckBox.put(target.id, target);
      }
      final (toWrite, result) = JsonSyncService.merge(
        target.id,
        cardsOf(target.id),
        _cards,
        imp.cards,
      );
      await _cardBox.putAll({for (final c in toWrite) c.id: c});
      _reload();
      total.addAll(result);
    }
    notifyListeners();
    return total;
  }
}
