import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../providers/library_provider.dart';
import '../services/json_sync_service.dart';
import 'ui_helpers.dart';

/// UI glue for JSON export / import.
class SyncActions {
  SyncActions._();

  /// Exports one deck, or every deck when [deck] is null.
  static Future<void> export(BuildContext context, {Deck? deck}) async {
    final lib = context.read<LibraryProvider>();
    final decks = deck == null ? lib.decks : [deck];
    final cards = deck == null ? lib.allCards : lib.cardsOf(deck.id);
    if (cards.isEmpty) {
      showSnack(context, 'Eksport qilish uchun so\'z yo\'q.');
      return;
    }
    try {
      final saved = await JsonSyncService.exportToFile(
        decks,
        cards,
        baseName: deck == null ? 'hammasi' : '${deck.folder}_${deck.name}',
      );
      if (!context.mounted || saved == null) return;
      showSnack(context, '${cards.length} ta so\'z saqlandi → $saved');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Eksport xatosi: $e');
    }
  }

  /// Picks a file and imports it. Each deck in the file goes into its own
  /// deck (matched by id or folder + name); files without deck info ask
  /// for a name and folder first.
  static Future<void> import(BuildContext context) async {
    final lib = context.read<LibraryProvider>();
    try {
      final incoming = await JsonSyncService.pickAndDecode();
      if (!context.mounted || incoming == null) return;
      incoming.removeWhere((d) => d.cards.isEmpty);
      if (incoming.isEmpty) {
        showSnack(context, 'Faylda so\'z topilmadi.');
        return;
      }

      for (final d in incoming) {
        // Files exported by LexiFlip carry deck id, name and folder → no
        // questions. Old / hand-made files: ask where to put the words.
        if (d.id != null) continue;
        final res = await showDeckForm(
          context,
          title: 'Yangi to\'plam',
          subtitle: '${d.cards.length} ta so\'z import qilinadi',
          name: d.name,
          folder: d.folder,
          okLabel: 'Import',
        );
        if (res == null || !context.mounted) return;
        d.name = res.name;
        d.folder = res.folder;
      }

      final result = await lib.importDecks(incoming);
      if (context.mounted) showSnack(context, 'Import tayyor: $result');
    } on FormatException catch (e) {
      if (context.mounted) showSnack(context, 'Noto\'g\'ri fayl: ${e.message}');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Import xatosi: $e');
    }
  }
}
