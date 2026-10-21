import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/deck.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import 'challenges_screen.dart';
import 'deck_screen.dart';
import 'settings_screen.dart';
import 'sync_actions.dart';
import 'ui_helpers.dart';

/// Start page: daily goal + folders with their decks.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _newDeck(BuildContext context, {String folder = ''}) async {
    final t = S.of(context);
    final res = await showDeckForm(context, title: t.newDeck, folder: folder, okLabel: t.create);
    if (res == null || !context.mounted) return;
    final deck = await context.read<LibraryProvider>().createDeck(res.name, folder: res.folder);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeckScreen(deckId: deck.id)));
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final settings = context.read<SettingsProvider>();
    final t = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LexiFlip'),
        actions: [
          IconButton(
            tooltip: t.challengesTooltip,
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ChallengesScreen())),
          ),
          IconButton(
            tooltip: t.themeTooltip,
            icon: Icon(theme.brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: () => settings.toggleTheme(theme.brightness),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'import':
                  SyncActions.import(context);
                case 'export':
                  SyncActions.export(context);
                case 'settings':
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'import',
                child: ListTile(leading: const Icon(Icons.download_rounded), title: Text(t.importJson)),
              ),
              PopupMenuItem(
                value: 'export',
                child: ListTile(leading: const Icon(Icons.upload_file_rounded), title: Text(t.exportAll)),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(leading: const Icon(Icons.settings_outlined), title: Text(t.settings)),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newDeck(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(t.deckFab),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const DailyGoalCard(),
              const SizedBox(height: 16),
              if (lib.isEmpty)
                _EmptyLibrary(onNew: () => _newDeck(context))
              else
                for (final folder in lib.folders)
                  _FolderSection(
                    folder: folder,
                    onNewDeck: () => _newDeck(context, folder: folder),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's progress toward the daily goal + streak.
class DailyGoalCard extends StatelessWidget {
  const DailyGoalCard({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final goal = context.select<SettingsProvider, int>((s) => s.dailyGoal);
    final theme = Theme.of(context);
    final t = S.of(context);
    final today = stats.todayCount;
    final done = today >= goal;
    final streak = stats.streak(goal);

    return Card(
      elevation: 0,
      color: done ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: (today / goal).clamp(0.0, 1.0),
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  Center(child: Text(done ? '✓' : '$today', style: theme.textTheme.titleMedium)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(done ? t.goalDone : t.goalToday,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(t.goalProgress(today, goal), style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            Column(
              children: [
                Text(streak > 0 ? '🔥' : '🌑', style: const TextStyle(fontSize: 26)),
                Text(t.days(streak), style: theme.textTheme.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderSection extends StatelessWidget {
  const _FolderSection({required this.folder, required this.onNewDeck});
  final String folder;
  final VoidCallback onNewDeck;

  Future<void> _rename(BuildContext context) async {
    final t = S.of(context);
    final name = await showTextInput(context, title: t.folderName, label: t.name, initial: folder);
    if (name == null || name.isEmpty || !context.mounted) return;
    await context.read<LibraryProvider>().renameFolder(folder, name);
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final decks = lib.decksIn(folder);
    final counts = lib.countsOfFolder(folder);
    final theme = Theme.of(context);
    final t = S.of(context);
    final isRoot = folder.isEmpty;

    final tiles = [for (final d in decks) _DeckTile(deck: d)];
    if (isRoot) {
      return Column(children: [
        if (lib.folders.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(t.noFolder, style: theme.textTheme.titleSmall),
            ),
          ),
        ...tiles,
      ]);
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.folder_rounded),
        title: Text(folder, style: theme.textTheme.titleMedium),
        subtitle: Text(t.folderSubtitle(decks.length, counts.learned, counts.total)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'new') onNewDeck();
            if (v == 'rename') _rename(context);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'new', child: Text(t.addDeckToFolder)),
            PopupMenuItem(value: 'rename', child: Text(t.renameFolder)),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: tiles,
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.deck});
  final Deck deck;

  Future<void> _menu(BuildContext context, String action) async {
    final lib = context.read<LibraryProvider>();
    final t = S.of(context);
    switch (action) {
      case 'edit':
        final res = await showDeckForm(context,
            title: t.editDeck, name: deck.name, folder: deck.folder);
        if (res != null) await lib.updateDeck(deck, name: res.name, folder: res.folder);
      case 'export':
        await SyncActions.export(context, deck: deck);
      case 'delete':
        final ok = await confirm(context,
            title: t.deleteQ,
            message: t.deleteDeckMsg(deck.name, lib.countsOf(deck.id).total),
            ok: t.delete,
            danger: true);
        if (ok) await lib.deleteDeck(deck.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LibraryProvider>().countsOf(deck.id);
    final theme = Theme.of(context);
    final t = S.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => DeckScreen(deckId: deck.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    BucketBar(counts: c),
                    const SizedBox(height: 6),
                    Text(
                      t.deckCounts(c.learned, c.problem, c.review),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => _menu(context, v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t.nameAndFolder)),
                  PopupMenuItem(value: 'export', child: Text(t.exportJson)),
                  PopupMenuItem(value: 'delete', child: Text(t.delete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin 3-colour bar: learned / problem / review.
class BucketBar extends StatelessWidget {
  const BucketBar({super.key, required this.counts, this.height = 6});
  final DeckCounts counts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (counts.total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(height),
        ),
      );
    }
    Widget seg(int n, Color c) =>
        n == 0 ? const SizedBox.shrink() : Expanded(flex: n, child: Container(color: c));
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(children: [
          seg(counts.learned, BucketColors.learned(context)),
          seg(counts.problem, BucketColors.problem(context)),
          seg(counts.review, scheme.outlineVariant.withValues(alpha: 0.6)),
        ]),
      ),
    );
  }
}

class BucketColors {
  static Color learned(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF6FCF97) : const Color(0xFF2E9D5B);
  static Color problem(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFFFF8A80) : const Color(0xFFD64545);
  static Color review(BuildContext c) => Theme.of(c).colorScheme.primary;
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.style_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(t.noDecks, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(t.noDecksHint, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded),
                label: Text(t.newDeck),
              ),
              OutlinedButton.icon(
                onPressed: () => SyncActions.import(context),
                icon: const Icon(Icons.download_rounded),
                label: Text(t.importJson),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
