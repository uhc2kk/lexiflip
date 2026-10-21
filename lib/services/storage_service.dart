import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/deck.dart';
import '../models/flashcard.dart';

/// Opens Hive boxes once at startup.
/// Android / Desktop: files in the app documents dir. Web: IndexedDB.
class StorageService {
  StorageService._();

  static const cardsBoxName = 'cards';
  static const decksBoxName = 'decks';
  static const settingsBoxName = 'settings';
  static const statsBoxName = 'stats';

  /// Name of the deck that older (pre-deck) cards are moved into.
  static const defaultDeckName = 'Umumiy';

  static Future<void> init() async {
    await Hive.initFlutter('lexiflip');
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FlashcardAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(DeckAdapter());
    await Hive.openBox<Flashcard>(cardsBoxName);
    await Hive.openBox<Deck>(decksBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(statsBoxName);
    await _migrate();
  }

  static Box<Flashcard> get cards => Hive.box<Flashcard>(cardsBoxName);
  static Box<Deck> get decks => Hive.box<Deck>(decksBoxName);
  static Box get settings => Hive.box(settingsBoxName);
  static Box get stats => Hive.box(statsBoxName);

  /// v1 → v2: cards without a deck (or whose deck is gone) go to "Umumiy".
  static Future<void> _migrate() async {
    final deckIds = decks.keys.cast<String>().toSet();
    final orphans =
        cards.values.where((c) => !deckIds.contains(c.deckId)).toList();
    if (orphans.isEmpty) return;

    var general = decks.values
        .where((d) => d.name == defaultDeckName && d.folder.isEmpty)
        .firstOrNull;
    if (general == null) {
      general = Deck.create(name: defaultDeckName);
      await decks.put(general.id, general);
    }
    await cards.putAll({
      for (final c in orphans) c.id: c.copyWith(deckId: general.id),
    });
  }
}
