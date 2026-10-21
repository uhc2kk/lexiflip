import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/deck_provider.dart';
import 'card_editor_screen.dart';
import 'sync_actions.dart';

/// Searchable list of all cards. Tap = edit, ▶ = study from this card.
class CardListScreen extends StatefulWidget {
  const CardListScreen({super.key});

  @override
  State<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends State<CardListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final deck = context.watch<DeckProvider>();
    final q = _query.toLowerCase();
    final cards = deck.cards
        .where((c) =>
            q.isEmpty ||
            c.word.toLowerCase().contains(q) ||
            c.primaryTranslation.toLowerCase().contains(q) ||
            c.secondaryTranslation.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Cards (${deck.length})'),
        actions: [
          IconButton(
            tooltip: 'Import JSON',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => SyncActions.import(context),
          ),
          IconButton(
            tooltip: 'Export JSON',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => SyncActions.export(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Search words or translations',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: cards.isEmpty
                    ? const Center(child: Text('No cards'))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: cards.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, i) {
                          final c = cards[i];
                          return ListTile(
                            title: Text(c.word),
                            subtitle: Text(
                              [c.ipa, c.primaryTranslation]
                                  .where((s) => s.isNotEmpty)
                                  .join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CardEditorScreen(cardId: c.id),
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Study from here',
                              icon: const Icon(Icons.play_arrow_rounded),
                              onPressed: () {
                                deck.goToId(c.id);
                                Navigator.of(context).pop();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
