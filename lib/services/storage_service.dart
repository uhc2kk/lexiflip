import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/folder.dart';

/// Opens Hive boxes once at startup.
/// Android / Desktop: files in the app documents dir. Web: IndexedDB.
class StorageService {
  StorageService._();

  static const cardsBoxName = 'cards';
  static const decksBoxName = 'decks';
  static const foldersBoxName = 'folders';
  static const settingsBoxName = 'settings';
  static const statsBoxName = 'stats';

  /// Name of the deck that pre-deck (v1.0) cards are moved into.
  static const defaultDeckName = 'Umumiy';

  static Future<void> init() async {
    await Hive.initFlutter('lexiflip');
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FlashcardAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(DeckAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(FolderAdapter());
    await Hive.openBox<Flashcard>(cardsBoxName);
    await Hive.openBox<Deck>(decksBoxName);
    await Hive.openBox<Folder>(foldersBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(statsBoxName);
    await _migrateOrphanCards();
    await _migrateLegacyFolders();
  }

  static Box<Flashcard> get cards => Hive.box<Flashcard>(cardsBoxName);
  static Box<Deck> get decks => Hive.box<Deck>(decksBoxName);
  static Box<Folder> get folders => Hive.box<Folder>(foldersBoxName);
  static Box get settings => Hive.box(settingsBoxName);
  static Box get stats => Hive.box(statsBoxName);

  /// v1.0 → v1.1: cards without a deck go to "Umumiy".
  static Future<void> _migrateOrphanCards() async {
    final deckIds = decks.keys.cast<String>().toSet();
    final orphans = cards.values.where((c) => !deckIds.contains(c.deckId)).toList();
    if (orphans.isEmpty) return;
    var general = decks.values.where((d) => d.name == defaultDeckName).firstOrNull;
    if (general == null) {
      general = Deck.create(name: defaultDeckName);
      await decks.put(general.id, general);
    }
    await cards.putAll({for (final c in orphans) c.id: c.copyWith(deckId: general.id)});
  }

  /// v1.x → v2.0: folder names stored on decks become real [Folder]s.
  static Future<void> _migrateLegacyFolders() async {
    final legacy = decks.values.where((d) => d.legacyFolder.isNotEmpty).toList();
    if (legacy.isEmpty) return;
    final byName = {
      for (final f in folders.values.where((f) => f.isRoot)) f.name.toLowerCase(): f,
    };
    var order = folders.length;
    for (final d in legacy) {
      final key = d.legacyFolder.toLowerCase();
      var folder = byName[key];
      if (folder == null) {
        folder = Folder.create(name: d.legacyFolder, order: order++);
        await folders.put(folder.id, folder);
        byName[key] = folder;
      }
      await decks.put(d.id, d.copyWith(folderId: folder.id, clearLegacy: true));
    }
  }
}
