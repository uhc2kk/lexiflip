import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flashcard.dart';
import '../providers/library_provider.dart';
import '../providers/stats_provider.dart';
import 'card_editor_screen.dart';
import 'home_screen.dart' show BucketBar, BucketColors;
import 'study_screen.dart';
import 'sync_actions.dart';
import 'ui_helpers.dart';

/// One deck: the 3 buckets, practice / challenge buttons and the word list.
class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key, required this.deckId});
  final String deckId;

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  CardStatus? _filter; // null = all
  String _query = '';

  void _open(StudyMode mode, {List<Flashcard>? cards}) {
    final lib = context.read<LibraryProvider>();
    final list = cards ??
        switch (mode) {
          StudyMode.practice => lib
              .cardsOf(widget.deckId)
              .where((c) => c.status != CardStatus.learned)
              .toList(),
          StudyMode.battle => lib.cardsOfStatus(widget.deckId, CardStatus.problem),
          StudyMode.blitz || StudyMode.browse => lib.cardsOf(widget.deckId),
        };
    if (list.isEmpty) {
      showSnack(
        context,
        switch (mode) {
          StudyMode.battle => 'Muammoli so\'z yo\'q — zo\'r!',
          StudyMode.practice => 'Hamma so\'zlar yodlangan! "Hammasini ko\'rish"ni sinab ko\'ring.',
          _ => 'To\'plamda so\'z yo\'q.',
        },
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudyScreen(deckId: widget.deckId, mode: mode, cards: list),
    ));
  }

  void _addCard() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CardEditorScreen(deckId: widget.deckId),
      ));

  Future<void> _deckMenu(String v) async {
    final lib = context.read<LibraryProvider>();
    final deck = lib.deckById(widget.deckId);
    if (deck == null) return;
    switch (v) {
      case 'edit':
        final res = await showDeckForm(context,
            title: 'To\'plamni tahrirlash', name: deck.name, folder: deck.folder);
        if (res != null) await lib.updateDeck(deck, name: res.name, folder: res.folder);
      case 'export':
        await SyncActions.export(context, deck: deck);
      case 'reset':
        final ok = await confirm(context,
            title: 'Natijalarni tozalash',
            message: 'Barcha so\'zlar "Qaytarilishi kerak" bo\'limiga qaytadi.',
            ok: 'Tozalash');
        if (ok) await lib.resetProgress(deck.id);
      case 'delete':
        final ok = await confirm(context,
            title: 'O\'chirilsinmi?',
            message: '"${deck.name}" va undagi barcha so\'zlar o\'chiriladi.',
            ok: 'O\'chirish',
            danger: true);
        if (ok) {
          await lib.deleteDeck(deck.id);
          if (mounted) Navigator.of(context).pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final deck = lib.deckById(widget.deckId);
    if (deck == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('To\'plam topilmadi')));
    }
    final counts = lib.countsOf(deck.id);
    final best = context.watch<StatsProvider>().bestBlitz(deck.id);
    final theme = Theme.of(context);

    final q = _query.toLowerCase();
    final cards = lib
        .cardsOf(deck.id)
        .where((c) => _filter == null || c.status == _filter)
        .where((c) =>
            q.isEmpty ||
            c.word.toLowerCase().contains(q) ||
            c.ipa.toLowerCase().contains(q) ||
            c.primaryTranslation.toLowerCase().contains(q) ||
            c.secondaryTranslation.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deck.name),
            if (deck.folder.isNotEmpty)
              Text(deck.folder, style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(tooltip: 'So\'z qo\'shish', icon: const Icon(Icons.add_rounded), onPressed: _addCard),
          PopupMenuButton<String>(
            onSelected: _deckMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Nomi / papkasi')),
              PopupMenuItem(value: 'export', child: Text('Eksport (JSON)')),
              PopupMenuItem(value: 'reset', child: Text('Natijalarni tozalash')),
              PopupMenuItem(value: 'delete', child: Text('To\'plamni o\'chirish')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList.list(children: [
                  // ---- Buckets ----
                  Row(children: [
                    _BucketTile(
                      label: 'Yodlangan',
                      count: counts.learned,
                      color: BucketColors.learned(context),
                      icon: Icons.check_circle_rounded,
                      selected: _filter == CardStatus.learned,
                      onTap: () => setState(() =>
                          _filter = _filter == CardStatus.learned ? null : CardStatus.learned),
                    ),
                    const SizedBox(width: 8),
                    _BucketTile(
                      label: 'Muammoli',
                      count: counts.problem,
                      color: BucketColors.problem(context),
                      icon: Icons.error_rounded,
                      selected: _filter == CardStatus.problem,
                      onTap: () => setState(() =>
                          _filter = _filter == CardStatus.problem ? null : CardStatus.problem),
                    ),
                    const SizedBox(width: 8),
                    _BucketTile(
                      label: 'Qaytarish',
                      count: counts.review,
                      color: BucketColors.review(context),
                      icon: Icons.replay_rounded,
                      selected: _filter == CardStatus.review,
                      onTap: () => setState(() =>
                          _filter = _filter == CardStatus.review ? null : CardStatus.review),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  BucketBar(counts: counts, height: 8),
                  const SizedBox(height: 16),

                  // ---- Practice ----
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () => _open(StudyMode.practice),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('Mashq qilish (${counts.review + counts.problem})'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => _open(StudyMode.browse),
                    icon: const Icon(Icons.style_outlined),
                    label: Text('Hammasini ko\'rish (${counts.total})'),
                  ),
                  const SizedBox(height: 12),

                  // ---- Challenges ----
                  Row(children: [
                    Expanded(
                      child: _ChallengeButton(
                        emoji: '⏱️',
                        title: 'Tezkor raund',
                        subtitle: best > 0 ? 'Rekord: $best' : '60 soniya',
                        onTap: () => _open(StudyMode.blitz),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChallengeButton(
                        emoji: '⚔️',
                        title: 'Muammolilar jangi',
                        subtitle: '${counts.problem} ta dushman',
                        onTap: () => _open(StudyMode.battle),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ---- Search ----
                  TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Qidirish',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixText: _filter == null
                          ? '${cards.length} ta'
                          : '${_bucketName(_filter!)}: ${cards.length}',
                    ),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
              if (cards.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: counts.total == 0
                          ? FilledButton.icon(
                              onPressed: _addCard,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Birinchi so\'zni qo\'shish'),
                            )
                          : const Text('Hech narsa topilmadi'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                  sliver: SliverList.separated(
                    itemCount: cards.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) => _CardRow(card: cards[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _bucketName(CardStatus s) => switch (s) {
      CardStatus.learned => 'Yodlangan',
      CardStatus.problem => 'Muammoli',
      CardStatus.review => 'Qaytarish',
    };

class _BucketTile extends StatelessWidget {
  const _BucketTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: selected ? color.withValues(alpha: 0.18) : theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 4),
                Text('$count', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeButton extends StatelessWidget {
  const _ChallengeButton({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card});
  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryProvider>();
    final color = switch (card.status) {
      CardStatus.learned => BucketColors.learned(context),
      CardStatus.problem => BucketColors.problem(context),
      CardStatus.review => Theme.of(context).colorScheme.outline,
    };
    return ListTile(
      leading: Icon(Icons.circle, size: 12, color: color),
      minLeadingWidth: 12,
      title: Text(card.word, style: const TextStyle(fontSize: 18)),
      subtitle: Text(
        [card.ipa, card.primaryTranslation].where((s) => s.isNotEmpty).join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CardEditorScreen(deckId: card.deckId, cardId: card.id),
      )),
      trailing: PopupMenuButton<CardStatus>(
        tooltip: 'Bo\'limni o\'zgartirish',
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (s) => lib.setStatus(card.id, s),
        itemBuilder: (_) => [
          for (final s in CardStatus.values)
            CheckedPopupMenuItem(
              value: s,
              checked: card.status == s,
              child: Text(_bucketName(s)),
            ),
        ],
      ),
    );
  }
}
