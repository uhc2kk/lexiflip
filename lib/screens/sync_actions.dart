import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/deck_provider.dart';
import '../services/json_sync_service.dart';

/// UI glue for one-click JSON export / import (used from several screens).
class SyncActions {
  SyncActions._();

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  static Future<void> export(BuildContext context) async {
    final deck = context.read<DeckProvider>();
    if (deck.isEmpty) {
      _snack(context, 'Nothing to export yet.');
      return;
    }
    try {
      final saved = await JsonSyncService.exportToFile(deck.cards);
      if (!context.mounted || saved == null) return;
      _snack(context, 'Exported ${deck.length} cards → $saved');
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e');
    }
  }

  static Future<void> import(BuildContext context) async {
    final deck = context.read<DeckProvider>();
    try {
      final incoming = await JsonSyncService.pickAndDecode();
      if (!context.mounted || incoming == null) return;
      if (incoming.isEmpty) {
        _snack(context, 'The file has no cards.');
        return;
      }

      // Empty deck: just merge. Otherwise ask merge vs replace.
      var replace = false;
      if (!deck.isEmpty) {
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Import ${incoming.length} cards'),
            content: const Text(
              'Merge keeps your cards and adds/updates from the file '
              '(newest edit wins).\n\nReplace deletes your current deck first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'replace'),
                child: const Text('Replace'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'merge'),
                child: const Text('Merge'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        replace = choice == 'replace';
      }

      if (replace) {
        await deck.replaceAll(incoming);
        if (context.mounted) {
          _snack(context, 'Deck replaced with ${incoming.length} cards.');
        }
      } else {
        final result = await deck.mergeImport(incoming);
        if (context.mounted) _snack(context, 'Import done: $result');
      }
    } on FormatException catch (e) {
      if (context.mounted) _snack(context, 'Invalid file: ${e.message}');
    } catch (e) {
      if (context.mounted) _snack(context, 'Import failed: $e');
    }
  }
}
