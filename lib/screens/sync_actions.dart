import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/deck.dart';
import '../providers/library_provider.dart';
import '../services/json_sync_service.dart';
import 'ui_helpers.dart';

/// UI glue for JSON export / import.
class SyncActions {
  SyncActions._();

  /// Exports one deck, a whole folder, or everything (both null).
  static Future<void> export(BuildContext context, {Deck? deck, String? folderId}) async {
    final lib = context.read<LibraryProvider>();
    final t = S.of(context);
    final decks = deck != null
        ? [deck]
        : folderId != null
            ? lib.decksInTree(folderId)
            : lib.decks;
    final ids = decks.map((d) => d.id).toSet();
    final cards = lib.allCards.where((c) => ids.contains(c.deckId)).toList();
    if (cards.isEmpty) {
      showSnack(context, t.nothingToExport);
      return;
    }
    final base = deck != null
        ? [...lib.deckFolderPath(deck), deck.name].join('_')
        : folderId != null
            ? lib.folderPathNames(folderId).join('_')
            : 'all';
    try {
      final saved = await JsonSyncService.exportToFile(decks, cards, lib.deckFolderPath, baseName: base);
      if (!context.mounted || saved == null) return;
      showSnack(context, t.exported(cards.length, saved));
    } catch (e) {
      if (context.mounted) showSnack(context, t.exportError(e));
    }
  }

  /// Picks a file and imports it.
  ///  - LexiFlip exports carry deck id + folder path → go straight in.
  ///  - Other files: asks for a deck name and folder ([intoFolderId] or
  ///    the file's folder path is pre-selected).
  static Future<void> import(BuildContext context, {String? intoFolderId}) async {
    final lib = context.read<LibraryProvider>();
    final t = S.of(context);
    try {
      final incoming = await JsonSyncService.pickAndDecode();
      if (!context.mounted || incoming == null) return;
      incoming.removeWhere((d) => d.cards.isEmpty);
      if (incoming.isEmpty) {
        showSnack(context, t.noWordsInFile);
        return;
      }

      for (final d in incoming) {
        if (d.id != null) continue;
        // Pre-select: the folder we're in, or the file's folder if it exists.
        String? preselect = intoFolderId;
        if (preselect == null && d.folderPath.isNotEmpty) {
          String? parent;
          for (final name in d.folderPath) {
            parent = lib
                .subfolders(parent)
                .where((f) => f.name.toLowerCase() == name.toLowerCase())
                .firstOrNull
                ?.id;
            if (parent == null) break;
          }
          preselect = parent;
        }
        final fileFolder = d.folderPath.join(' › ');
        final res = await showDeckForm(
          context,
          title: t.importTitle,
          subtitle: [
            t.importWords(d.cards.length),
            if (fileFolder.isNotEmpty && preselect == null) t.fileFolderHint(fileFolder),
          ].join('\n'),
          name: d.name,
          folderId: preselect,
          okLabel: t.importBtn,
        );
        if (res == null || !context.mounted) return;
        d.name = res.name;
        if (res.folderId != null) {
          d.targetFolderId = res.folderId;
        } else if (fileFolder.isEmpty || preselect != null) {
          d.targetRoot = true;
        }
        // else: top level chosen but file has a new folder path → create it.
      }

      final result = await lib.importDecks(incoming);
      if (context.mounted) {
        showSnack(context, t.importDone(result.added, result.updated, result.skipped));
      }
    } on FormatException {
      if (context.mounted) showSnack(context, t.invalidFile);
    } catch (e) {
      if (context.mounted) showSnack(context, t.importError(e));
    }
  }
}
