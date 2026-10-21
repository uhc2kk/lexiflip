import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/flashcard.dart';

/// Opens Hive boxes once at startup.
/// Android / Desktop: files in the app documents dir. Web: IndexedDB.
class StorageService {
  StorageService._();

  static const cardsBoxName = 'cards';
  static const settingsBoxName = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter('lexiflip');
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FlashcardAdapter());
    }
    await Hive.openBox<Flashcard>(cardsBoxName);
    await Hive.openBox(settingsBoxName);
  }

  static Box<Flashcard> get cards => Hive.box<Flashcard>(cardsBoxName);
  static Box get settings => Hive.box(settingsBoxName);
}
