import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/flashcard.dart';
import '../providers/library_provider.dart';
import '../providers/stats_provider.dart';
import '../widgets/word_style.dart';
import 'card_editor_screen.dart';
import 'home_screen.dart' show BucketBar, BucketColors;
import 'quick_add_screen.dart';
import 'study_screen.dart';
import '../widgets/progress_chart.dart';
import 'sync_actions.dart';
import 'ui_helpers.dart';

/// The study hub for any set of cards: one deck, a whole folder,
/// ⭐ starred words, or several selected decks.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key, required this.source});
  final CardSource source;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  CardStatus? _filter;
  String _query = '';

  CardSource get _src => widget.source;
  bool get _isDeck => _src.kind == SourceKind.deck;

  void _start(StudyMode mode) {
    final t = S.of(context);
    final list = cardsForMode(context.read<LibraryProvider>(), _src, mode);
    final tooFew = mode == StudyMode.boss && list.length < kBossMin;
    if (list.isEmpty || tooFew) {
      showSnack(
        context,
        tooFew
            ? t.bossNeeds(kBossMin)
            : switch (mode) {
                StudyMode.battle => t.noProblemWords,
                StudyMode.practice => t.allLearned,
                _ => t.deckEmpty,
              },
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudyScreen(source: _src, mode: mode, cards: list),
    ));
  }

  void _addCard() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CardEditorScreen(deckId: _src.id),
      ));

  Future<void> _menu(String v) async {
    final t = S.of(context);
    final lib = context.read<LibraryProvider>();
    switch (v) {
      case 'edit':
        final deck = lib.deckById(_src.id);
        if (deck == null) return;
        final res = await showDeckForm(context, title: t.editDeck, name: deck.name, folderId: deck.folderId);
        if (res != null) await lib.updateDeck(deck, name: res.name, folderId: res.folderId);
      case 'export':
        if (_isDeck) {
          final deck = lib.deckById(_src.id);
          if (deck != null) await SyncActions.export(context, deck: deck);
        } else if (_src.kind == SourceKind.folder) {
          await SyncActions.export(context, folderId: _src.id);
        }
      case 'reset':
        final ok = await confirm(context, title: t.resetProgress, message: t.resetProgressMsg, ok: t.reset);
        if (ok) await lib.resetProgress(_src);
      case 'delete':
        final deck = lib.deckById(_src.id);
        if (deck == null) return;
        final ok = await confirm(context,
            title: t.deleteQ, message: t.deleteDeckAllMsg(deck.name), ok: t.delete, danger: true);
        if (ok) {
          await lib.deleteDeck(deck.id);
          if (mounted) Navigator.of(context).pop();
        }
    }
  }

  (String, String?) _titles(S t, LibraryProvider lib) {
    switch (_src.kind) {
      case SourceKind.deck:
        final d = lib.deckById(_src.id);
        if (d == null) return ('', null);
        final path = lib.deckFolderPath(d).join(' › ');
        return (d.name, path.isEmpty ? null : path);
      case SourceKind.folder:
        return (lib.folderById(_src.id)?.name ?? '', t.wholeFolder);
      case SourceKind.starred:
        return ('⭐ ${t.starred}', null);
      case SourceKind.multi:
        return (t.selectedDecks(_src.deckIds.length),
            _src.deckIds.map((id) => lib.deckById(id)?.name).whereType<String>().join(', '));
      case SourceKind.hardest:
        return ('💀 ${t.hardest}', t.hardestSub(kHardestSize));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final stats = context.watch<StatsProvider>();
    final t = S.of(context);
    final theme = Theme.of(context);

    if (_isDeck && lib.deckById(_src.id) == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(t.deckNotFound)));
    }

    final (title, subtitle) = _titles(t, lib);
    final all = lib.cardsFor(_src);
    final counts = lib.count(all);
    final key = _src.key;

    final q = _query.toLowerCase();
    final cards = all
        .where((c) => _filter == null || c.status == _filter)
        .where((c) =>
            q.isEmpty ||
            c.word.toLowerCase().contains(q) ||
            c.ipa.toLowerCase().contains(q) ||
            c.primaryTranslation.toLowerCase().contains(q) ||
            c.secondaryTranslation.toLowerCase().contains(q))
        .toList();

    Widget bucket(CardStatus s, String label, IconData icon, Color color, int n) => _BucketTile(
          label: label,
          count: n,
          color: color,
          icon: icon,
          selected: _filter == s,
          onTap: () => setState(() => _filter = _filter == s ? null : s),
        );

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, overflow: TextOverflow.ellipsis),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(subtitle, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          if (_isDeck) ...[
            IconButton(
              tooltip: t.favouriteDeck,
              icon: Icon(lib.deckById(_src.id)!.starred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: lib.deckById(_src.id)!.starred ? const Color(0xFFF5B301) : null),
              onPressed: () => lib.toggleDeckStar(_src.id),
            ),
            IconButton(
              tooltip: t.quickAdd,
              icon: const Icon(Icons.playlist_add_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => QuickAddScreen(deckId: _src.id),
              )),
            ),
            IconButton(tooltip: t.addWord, icon: const Icon(Icons.add_rounded), onPressed: _addCard),
          ],
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              if (_isDeck) PopupMenuItem(value: 'edit', child: Text(t.nameAndFolder)),
              if (_isDeck || _src.kind == SourceKind.folder)
                PopupMenuItem(value: 'export', child: Text(t.exportJson)),
              PopupMenuItem(value: 'reset', child: Text(t.resetProgress)),
              if (_isDeck) PopupMenuItem(value: 'delete', child: Text(t.deleteDeck)),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList.list(children: [
                Row(children: [
                  bucket(CardStatus.learned, t.learned, Icons.check_circle_rounded, BucketColors.learned(context), counts.learned),
                  const SizedBox(width: 8),
                  bucket(CardStatus.problem, t.problem, Icons.error_rounded, BucketColors.problem(context), counts.problem),
                  const SizedBox(width: 8),
                  bucket(CardStatus.review, t.review, Icons.replay_rounded, BucketColors.review(context), counts.review),
                ]),
                const SizedBox(height: 10),
                BucketBar(counts: counts, height: 8),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _start(StudyMode.practice),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(t.practiceBtn(counts.review + counts.problem)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: () => _start(StudyMode.browse),
                  icon: const Icon(Icons.style_outlined),
                  label: Text(t.browseAllBtn(counts.total)),
                ),
                const SizedBox(height: 14),
                Text(t.challenges, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 560 ? 3 : 2;
                  final w = (c.maxWidth - 8 * (cols - 1)) / cols;
                  Widget tile(String emoji, String title, String sub, StudyMode m) =>
                      SizedBox(width: w, child: _ChallengeButton(emoji: emoji, title: title, subtitle: sub, onTap: () => _start(m)));
                  String rec(String k, String fallback) {
                    final b = stats.best('$k:$key');
                    return b > 0 ? t.record(b) : fallback;
                  }

                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    tile('⏱️', t.blitzTitle, rec('blitz60', t.secondsN(60)), StudyMode.blitz60),
                    tile('⚡', t.lightningTitle, rec('blitz30', t.secondsN(30)), StudyMode.blitz30),
                    tile('⚔️', t.battleTitle, t.enemies(counts.problem), StudyMode.battle),
                    tile('🎯', t.perfectTitle, rec('perfect', t.perfectSub), StudyMode.perfect),
                    tile('🐉', t.bossTitle, t.bossSub, StudyMode.boss),
                  ]);
                }),
                if (_src.kind != SourceKind.hardest && _src.kind != SourceKind.starred) ...[
                  const SizedBox(height: 16),
                  ProgressChartCard(
                    deckIds: switch (_src.kind) {
                      SourceKind.deck => [_src.id],
                      SourceKind.folder => lib.decksInTree(_src.id).map((d) => d.id).toList(),
                      SourceKind.multi => _src.deckIds,
                      _ => lib.decks.map((d) => d.id).toList(),
                    },
                    learnedNow: counts.learned,
                    total: counts.total,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: t.search,
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixText: t.countSuffix(cards.length),
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
                    child: counts.total == 0 && _isDeck
                        ? FilledButton.icon(
                            onPressed: _addCard,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(t.firstWord),
                          )
                        : Text(_src.kind == SourceKind.starred && counts.total == 0 ? t.starredEmpty : t.nothingFound,
                            textAlign: TextAlign.center),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                sliver: SliverList.separated(
                  itemCount: cards.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) => CardRow(card: cards[i], showDeck: !_isDeck),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

String bucketName(S t, CardStatus s) => switch (s) {
      CardStatus.learned => t.learned,
      CardStatus.problem => t.problem,
      CardStatus.review => t.review,
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
            child: Column(children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text('$count', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(label, style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ChallengeButton extends StatelessWidget {
  const _ChallengeButton({required this.emoji, required this.title, required this.subtitle, required this.onTap});
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
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One word in a list: status dot, star, bucket menu; tap to edit.
class CardRow extends StatelessWidget {
  const CardRow({super.key, required this.card, this.showDeck = false});
  final Flashcard card;
  final bool showDeck;

  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryProvider>();
    final t = S.of(context);
    final color = switch (card.status) {
      CardStatus.learned => BucketColors.learned(context),
      CardStatus.problem => BucketColors.problem(context),
      CardStatus.review => Theme.of(context).colorScheme.outline,
    };
    final deckName = showDeck ? lib.deckById(card.deckId)?.name : null;
    final due = card.status == CardStatus.learned && card.dueAt != null
        ? card.dueAt!.difference(DateTime.now().toUtc()).inDays + 1
        : null;
    return ListTile(
      leading: Icon(Icons.circle, size: 12, color: color),
      minLeadingWidth: 12,
      title: Text(card.word, style: wordStyle(context, card.word, const TextStyle(fontSize: 18))),
      subtitle: Text(
        [card.ipa, card.primaryTranslation, if (due != null) '⏳ ${t.inDays(due)}', if (deckName != null) '📁 $deckName']
            .where((s) => s.isNotEmpty)
            .join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CardEditorScreen(deckId: card.deckId, cardId: card.id),
      )),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: t.starToggle,
          icon: Icon(card.starred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: card.starred ? const Color(0xFFF5B301) : null),
          onPressed: () => lib.toggleStar(card.id),
        ),
        PopupMenuButton<CardStatus>(
          tooltip: t.changeBucket,
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (s) => lib.setStatus(card.id, s),
          itemBuilder: (_) => [
            for (final s in CardStatus.values)
              CheckedPopupMenuItem(value: s, checked: card.status == s, child: Text(bucketName(t, s))),
          ],
        ),
      ]),
    );
  }
}
