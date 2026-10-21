import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../models/flashcard.dart';
import '../services/json_sync_service.dart';
import '../services/storage_service.dart';

/// Holds the deck, the study position and all persistence calls.
class DeckProvider extends ChangeNotifier {
  DeckProvider() {
    _reload();
  }

  final Box<Flashcard> _box = StorageService.cards;

  List<Flashcard> _cards = [];
  int _index = 0;
  bool _shuffled = false;

  List<Flashcard> get cards => List.unmodifiable(_cards);
  int get index => _index;
  int get length => _cards.length;
  bool get isEmpty => _cards.isEmpty;
  bool get isShuffled => _shuffled;
  Flashcard? get current => _cards.isEmpty ? null : _cards[_index];

  void _reload() {
    _cards = _box.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _shuffled = false;
    _clampIndex();
  }

  void _clampIndex() {
    if (_cards.isEmpty) {
      _index = 0;
    } else if (_index >= _cards.length) {
      _index = _cards.length - 1;
    } else if (_index < 0) {
      _index = 0;
    }
  }

  // ---------- Navigation ----------

  void next() {
    if (_cards.isEmpty) return;
    _index = (_index + 1) % _cards.length;
    notifyListeners();
  }

  void previous() {
    if (_cards.isEmpty) return;
    _index = (_index - 1 + _cards.length) % _cards.length;
    notifyListeners();
  }

  void goToId(String id) {
    final i = _cards.indexWhere((c) => c.id == id);
    if (i >= 0) {
      _index = i;
      notifyListeners();
    }
  }

  /// Toggles between shuffled order and the original (date added) order.
  void toggleShuffle() {
    if (_shuffled) {
      final currentId = current?.id;
      _reload();
      _index = currentId == null ? 0 : _cards.indexWhere((c) => c.id == currentId);
      _clampIndex();
    } else {
      _cards.shuffle();
      _shuffled = true;
      _index = 0;
    }
    notifyListeners();
  }

  // ---------- CRUD ----------

  bool wordExists(String word, {String? exceptId}) {
    final w = word.trim().toLowerCase();
    return _cards.any((c) => c.id != exceptId && c.word.toLowerCase() == w);
  }

  Future<void> upsert(Flashcard card) async {
    final i = _cards.indexWhere((c) => c.id == card.id);
    if (i >= 0) {
      _cards[i] = card;
    } else {
      _cards.add(card);
    }
    await _box.put(card.id, card);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _cards.removeWhere((c) => c.id == id);
    _clampIndex();
    await _box.delete(id);
    notifyListeners();
  }

  Future<void> updateMnemonic(String id, String text) async {
    final i = _cards.indexWhere((c) => c.id == id);
    if (i < 0 || _cards[i].mnemonic == text.trim()) return;
    await upsert(_cards[i].copyWith(mnemonic: text.trim()).touched());
  }

  // ---------- Import ----------

  Future<MergeResult> mergeImport(List<Flashcard> incoming) async {
    final result = JsonSyncService.merge(_box.values, incoming);
    await _box.putAll({for (final c in result.toWrite) c.id: c});
    _reload();
    notifyListeners();
    return result;
  }

  Future<void> replaceAll(List<Flashcard> incoming) async {
    await _box.clear();
    await _box.putAll({for (final c in incoming) c.id: c});
    _index = 0;
    _reload();
    notifyListeners();
  }
}
