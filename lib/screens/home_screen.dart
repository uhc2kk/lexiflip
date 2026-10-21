import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/deck.dart';
import '../models/folder.dart';
import '../models/gamification.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import 'challenges_screen.dart';
import 'hub_screen.dart';
import 'settings_screen.dart';
import 'sync_actions.dart';
import 'ui_helpers.dart';

/// Start page. Also refreshes due words and the reminder on start / resume.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await context.read<LibraryProvider>().refreshDue();
    if (mounted) await syncReminder(context);
  }

  @override
  Widget build(BuildContext context) => const FolderScreen(folderId: null);
}

/// A folder page (folderId == null → the home page).
/// Shows sub-folders and decks; both can be dragged into a new order.
class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.folderId});
  final String? folderId;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  bool _selecting = false;
  final Set<String> _selected = {};

  bool get _isHome => widget.folderId == null;

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  // ---------------- create ----------------

  Future<void> _newFolder() async {
    final t = S.of(context);
    final lib = context.read<LibraryProvider>();
    final name = await showTextInput(context,
        title: _isHome ? t.newFolder : t.newSubfolder, label: t.name, okLabel: t.create);
    if (name == null || !mounted) return;
    await lib.createFolder(name, parentId: widget.folderId);
  }

  Future<void> _newDeck() async {
    final t = S.of(context);
    final lib = context.read<LibraryProvider>();
    final res = await showDeckForm(context, title: t.newDeck, folderId: widget.folderId, okLabel: t.create);
    if (res == null || !mounted) return;
    final deck = await lib.createDeck(res.name, folderId: res.folderId);
    if (mounted) _open(HubScreen(source: CardSource.deck(deck.id)));
  }

  void _addMenu(bool canAddFolder) {
    final t = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (canAddFolder)
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(_isHome ? t.newFolder : t.newSubfolder),
              onTap: () {
                Navigator.pop(ctx);
                _newFolder();
              },
            ),
          ListTile(
            leading: const Icon(Icons.style_outlined),
            title: Text(t.newDeck),
            onTap: () {
              Navigator.pop(ctx);
              _newDeck();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: Text(t.importJson),
            onTap: () {
              Navigator.pop(ctx);
              SyncActions.import(context, intoFolderId: widget.folderId);
            },
          ),
        ]),
      ),
    );
  }

  // ---------------- folder actions ----------------

  Future<void> _folderAction(Folder f, String action) async {
    final t = S.of(context);
    final lib = context.read<LibraryProvider>();
    switch (action) {
      case 'rename':
        final name = await showTextInput(context, title: t.rename, label: t.name, initial: f.name);
        if (name != null) await lib.renameFolder(f, name);
      case 'move':
        if (lib.subfolders(f.id).isNotEmpty) {
          showSnack(context, t.cantMoveFolder);
          return;
        }
        final to = await pickFolder(context,
            title: t.moveFolder, current: f.parentId, onlyRoots: true, exclude: f.id);
        if (to == null) return;
        final ok = await lib.moveFolder(f, to == kRootFolder ? null : to);
        if (!ok && mounted) showSnack(context, t.cantMoveFolder);
      case 'export':
        await SyncActions.export(context, folderId: f.id);
      case 'delete':
        final decks = lib.decksInTree(f.id).length;
        final words = lib.countsOfFolder(f.id).total;
        final ok = await confirm(context,
            title: t.deleteQ, message: t.deleteFolderMsg(f.name, decks, words), ok: t.delete, danger: true);
        if (ok) {
          await lib.deleteFolder(f.id);
          if (mounted && f.id == widget.folderId) Navigator.of(context).pop();
        }
    }
  }

  Future<void> _deckAction(Deck d, String action) async {
    final t = S.of(context);
    final lib = context.read<LibraryProvider>();
    switch (action) {
      case 'star':
        await lib.toggleDeckStar(d.id);
      case 'edit':
        final res = await showDeckForm(context, title: t.editDeck, name: d.name, folderId: d.folderId);
        if (res != null) await lib.updateDeck(d, name: res.name, folderId: res.folderId);
      case 'langs':
        await editDeckLangs(context, d);
      case 'export':
        await SyncActions.export(context, deck: d);
      case 'delete':
        final ok = await confirm(context,
            title: t.deleteQ,
            message: t.deleteDeckMsg(d.name, lib.countsOf(d.id).total),
            ok: t.delete,
            danger: true);
        if (ok) await lib.deleteDeck(d.id);
    }
  }

  List<PopupMenuEntry<String>> _folderMenuItems(S t, Folder f) => [
        PopupMenuItem(value: 'rename', child: Text(t.rename)),
        if (_lib(context).subfolders(f.id).isEmpty) PopupMenuItem(value: 'move', child: Text(t.move)),
        PopupMenuItem(value: 'export', child: Text(t.exportJson)),
        PopupMenuItem(value: 'delete', child: Text(t.delete)),
      ];

  static LibraryProvider _lib(BuildContext c) => c.read<LibraryProvider>();

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final t = S.of(context);
    final theme = Theme.of(context);
    final folder = lib.folderById(widget.folderId);

    if (!_isHome && folder == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(t.nothingFound)));
    }

    final subfolders = lib.subfolders(widget.folderId);
    final decks = lib.decksIn(widget.folderId);
    final canAddFolder = _isHome || (folder?.isRoot ?? false);

    final actions = <Widget>[
      IconButton(
        tooltip: t.select,
        isSelected: _selecting,
        icon: const Icon(Icons.checklist_rounded),
        onPressed: () => setState(() {
          _selecting = !_selecting;
          _selected.clear();
        }),
      ),
      if (_isHome) ...[
        IconButton(
          tooltip: t.challengesTooltip,
          icon: const Icon(Icons.emoji_events_outlined),
          onPressed: () => _open(const ChallengesScreen()),
        ),
        IconButton(
          tooltip: t.themeTooltip,
          icon: Icon(theme.brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          onPressed: () => context.read<SettingsProvider>().toggleTheme(theme.brightness),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'import':
                SyncActions.import(context);
              case 'export':
                SyncActions.export(context);
              case 'settings':
                _open(const SettingsScreen());
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'import', child: ListTile(leading: const Icon(Icons.download_rounded), title: Text(t.importJson))),
            PopupMenuItem(value: 'export', child: ListTile(leading: const Icon(Icons.upload_file_rounded), title: Text(t.exportAll))),
            PopupMenuItem(value: 'settings', child: ListTile(leading: const Icon(Icons.settings_outlined), title: Text(t.settings))),
          ],
        ),
      ] else
        PopupMenuButton<String>(
          onSelected: (v) => _folderAction(folder!, v),
          itemBuilder: (_) => _folderMenuItems(t, folder!),
        ),
      const SizedBox(width: 4),
    ];

    return Scaffold(
      appBar: AppBar(
        title: _isHome
            ? const Text('LexiFlip')
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(folder!.name),
                if (!folder.isRoot)
                  Text(lib.folderById(folder.parentId)?.name ?? '', style: theme.textTheme.bodySmall),
              ]),
        actions: actions,
      ),
      floatingActionButton: _selecting
          ? FloatingActionButton.extended(
              onPressed: _selected.isEmpty
                  ? null
                  : () => _open(HubScreen(source: CardSource.multi(_selected.toList()))),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(t.practiceTogether(_selected.length)),
            )
          : FloatingActionButton(
              tooltip: t.add,
              onPressed: () => _addMenu(canAddFolder),
              child: const Icon(Icons.add_rounded),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (_isHome) ...[
                const ProgressHeader(),
                const SizedBox(height: 10),
                const QuestStrip(),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _StarredTile(onTap: () => _open(const HubScreen(source: CardSource.starred())))),
                  const SizedBox(width: 10),
                  Expanded(child: _HardestTile(onTap: () => _open(const HubScreen(source: CardSource.hardest())))),
                ]),
                if (lib.starredDecks.isNotEmpty) ...[
                  _SectionTitle('⭐ ${t.favouriteDecks}'),
                  for (final d in lib.starredDecks)
                    _DeckTile(
                      deck: d,
                      handle: null,
                      selecting: _selecting,
                      selected: _selected.contains(d.id),
                      subtitle: lib.folderPathNames(d.folderId).join(' › '),
                      onTap: () {
                        if (_selecting) {
                          setState(() => _selected.contains(d.id) ? _selected.remove(d.id) : _selected.add(d.id));
                        } else {
                          _open(HubScreen(source: CardSource.deck(d.id)));
                        }
                      },
                      onAction: (a) => _deckAction(d, a),
                    ),
                ],
              ] else
                _FolderSummary(
                  folderId: widget.folderId!,
                  onPractice: () => _open(HubScreen(source: CardSource.folder(widget.folderId!))),
                ),
              if (_selecting)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(t.selectHint, style: theme.textTheme.bodySmall),
                ),
              if (subfolders.isNotEmpty) ...[
                _SectionTitle(t.folders),
                _ReorderList<Folder>(
                  items: subfolders,
                  keyOf: (f) => f.id,
                  enabled: !_selecting,
                  onReorder: lib.reorderFolders,
                  itemBuilder: (f, handle) => _FolderTile(
                    folder: f,
                    handle: handle,
                    onTap: () => _open(FolderScreen(folderId: f.id)),
                    onAction: (a) => _folderAction(f, a),
                    menu: _folderMenuItems(t, f),
                  ),
                ),
              ],
              if (decks.isNotEmpty) ...[
                _SectionTitle(t.decks),
                _ReorderList<Deck>(
                  items: decks,
                  keyOf: (d) => d.id,
                  enabled: !_selecting,
                  onReorder: lib.reorderDecks,
                  itemBuilder: (d, handle) => _DeckTile(
                    deck: d,
                    handle: handle,
                    selecting: _selecting,
                    selected: _selected.contains(d.id),
                    onTap: () {
                      if (_selecting) {
                        setState(() => _selected.contains(d.id) ? _selected.remove(d.id) : _selected.add(d.id));
                      } else {
                        _open(HubScreen(source: CardSource.deck(d.id)));
                      }
                    },
                    onAction: (a) => _deckAction(d, a),
                  ),
                ),
              ],
              if (subfolders.isEmpty && decks.isEmpty)
                _EmptyFolder(
                  isHome: _isHome,
                  onNewFolder: canAddFolder ? _newFolder : null,
                  onNewDeck: _newDeck,
                  onImport: () => SyncActions.import(context, intoFolderId: widget.folderId),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  Drag-and-drop list
// =====================================================================

/// A non-scrolling reorderable list. On a PC you can drag with the ⠿ handle
/// immediately, or press and hold anywhere on the item; on a phone press and
/// hold.
class _ReorderList<T> extends StatelessWidget {
  const _ReorderList({
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    required this.onReorder,
    required this.enabled,
  });

  final List<T> items;
  final String Function(T) keyOf;
  final Widget Function(T item, Widget? handle) itemBuilder;
  final Future<void> Function(List<T>) onReorder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final desktop = kIsWeb ||
        const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}
            .contains(defaultTargetPlatform);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      proxyDecorator: (child, _, __) => Material(
        elevation: 6,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final list = [...items];
        final moved = list.removeAt(oldIndex);
        list.insert(newIndex, moved);
        onReorder(list);
      },
      itemBuilder: (context, i) {
        final item = items[i];
        final handle = enabled && desktop
            ? ReorderableDragStartListener(
                index: i,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Icon(Icons.drag_indicator_rounded, size: 20),
                  ),
                ),
              )
            : null;
        final child = itemBuilder(item, handle);
        return KeyedSubtree(
          key: ValueKey(keyOf(item)),
          child: enabled ? ReorderableDelayedDragStartListener(index: i, child: child) : child,
        );
      },
    );
  }
}

// =====================================================================
//  Tiles
// =====================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.handle,
    required this.onTap,
    required this.onAction,
    required this.menu,
  });
  final Folder folder;
  final Widget? handle;
  final VoidCallback onTap;
  final void Function(String) onAction;
  final List<PopupMenuEntry<String>> menu;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final t = S.of(context);
    final theme = Theme.of(context);
    final c = lib.countsOfFolder(folder.id);
    final subs = lib.subfolders(folder.id).length;
    final decks = lib.decksInTree(folder.id).length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 4, 12),
          child: Row(children: [
            if (handle != null) handle!,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.folder_rounded, size: 34, color: theme.colorScheme.primary),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(folder.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(t.folderInfo(subs, decks, c.learned, c.total), style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                BucketBar(counts: c),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
            PopupMenuButton<String>(onSelected: onAction, itemBuilder: (_) => menu),
          ]),
        ),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.deck,
    required this.handle,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onAction,
    this.subtitle,
  });
  final Deck deck;
  final String? subtitle;
  final Widget? handle;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final void Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LibraryProvider>().countsOf(deck.id);
    final t = S.of(context);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 4, 12),
          child: Row(children: [
            if (selecting)
              Checkbox(value: selected, onChanged: (_) => onTap())
            else if (handle != null)
              handle!,
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(deck.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                  if (deck.starred) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF5B301)),
                  ],
                ]),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                BucketBar(counts: c),
                const SizedBox(height: 6),
                Text(t.deckCounts(c.learned, c.problem, c.review), style: theme.textTheme.bodySmall),
              ]),
            ),
            if (!selecting)
              PopupMenuButton<String>(
                onSelected: onAction,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'star', child: Text(deck.starred ? t.unfavourite : t.favouriteDeck)),
                  PopupMenuItem(value: 'edit', child: Text(t.nameAndFolder)),
                  PopupMenuItem(value: 'langs', child: Text(t.deckLanguages)),
                  PopupMenuItem(value: 'export', child: Text(t.exportJson)),
                  PopupMenuItem(value: 'delete', child: Text(t.delete)),
                ],
              ),
          ]),
        ),
      ),
    );
  }
}

class _StarredTile extends StatelessWidget {
  const _StarredTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = context.select<LibraryProvider, int>((l) => l.starredCount);
    final t = S.of(context);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Icon(Icons.star_rounded, color: Color(0xFFF5B301), size: 32),
        title: Text(t.starred),
        subtitle: Text(t.starredSub(n)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _HardestTile extends StatelessWidget {
  const _HardestTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = context.select<LibraryProvider, int>((l) => l.hardestCards.length);
    final t = S.of(context);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const Text('💀', style: TextStyle(fontSize: 28)),
        title: Text(t.hardest),
        subtitle: Text(n == 0 ? t.hardestEmptyShort : t.wordsN(n)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _FolderSummary extends StatelessWidget {
  const _FolderSummary({required this.folderId, required this.onPractice});
  final String folderId;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final t = S.of(context);
    final theme = Theme.of(context);
    final c = lib.countsOfFolder(folderId);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.deckCounts(c.learned, c.problem, c.review), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          BucketBar(counts: c, height: 8),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: c.total == 0 ? null : onPractice,
            icon: const Icon(Icons.library_books_outlined),
            label: Text(t.practiceFolder(c.total)),
          ),
        ]),
      ),
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({
    required this.isHome,
    required this.onNewFolder,
    required this.onNewDeck,
    required this.onImport,
  });
  final bool isHome;
  final VoidCallback? onNewFolder;
  final VoidCallback onNewDeck;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(Icons.folder_open_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(isHome ? t.noDecks : t.emptyFolder, style: theme.textTheme.titleMedium),
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          if (onNewFolder != null)
            OutlinedButton.icon(
              onPressed: onNewFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(isHome ? t.newFolder : t.newSubfolder),
            ),
          FilledButton.icon(onPressed: onNewDeck, icon: const Icon(Icons.add_rounded), label: Text(t.newDeck)),
          OutlinedButton.icon(onPressed: onImport, icon: const Icon(Icons.download_rounded), label: Text(t.importJson)),
        ]),
      ]),
    );
  }
}

// =====================================================================
//  Progress header & quests (home)
// =====================================================================

/// Level + XP bar + today's goal + streak.
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final goal = context.select<SettingsProvider, int>((s) => s.dailyGoal);
    final t = S.of(context);
    final theme = Theme.of(context);
    final level = stats.level;
    final rank = rankFor(level);
    final from = xpForLevel(level), to = xpForLevel(level + 1);
    final frac = ((stats.xp - from) / (to - from)).clamp(0.0, 1.0);
    final today = stats.todayCount;
    final streak = stats.streak(goal);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengesScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text(rank.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t.levelN(level)} · ${t.rankName(rank.id)}', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: frac, minHeight: 8),
                ),
                const SizedBox(height: 4),
                Text('${stats.xp - from} / ${to - from} XP', style: theme.textTheme.bodySmall),
              ]),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(fit: StackFit.expand, children: [
                CircularProgressIndicator(
                  value: (today / goal).clamp(0.0, 1.0),
                  strokeWidth: 5,
                  backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                Center(child: Text(today >= goal ? '✓' : '$today', style: theme.textTheme.titleSmall)),
              ]),
            ),
            const SizedBox(width: 12),
            Column(children: [
              Text(streak > 0 ? '🔥' : '💤', style: const TextStyle(fontSize: 24)),
              Text(t.days(streak), style: theme.textTheme.labelSmall),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Today's 3 quests in one compact card.
class QuestStrip extends StatelessWidget {
  const QuestStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final t = S.of(context);
    final theme = Theme.of(context);
    final quests = stats.dailyQuests;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengesScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('📋 ${t.dailyQuests}', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text('${stats.dailyQuestsDone} / ${quests.length}', style: theme.textTheme.labelLarge),
            ]),
            const SizedBox(height: 8),
            for (final q in quests) QuestRow(quest: q, weekly: false, dense: true),
          ]),
        ),
      ),
    );
  }
}

class QuestRow extends StatelessWidget {
  const QuestRow({super.key, required this.quest, required this.weekly, this.dense = false});
  final QuestDef quest;
  final bool weekly;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final t = S.of(context);
    final theme = Theme.of(context);
    final done = stats.questDone(quest, weekly: weekly);
    final p = stats.questProgress(quest, weekly: weekly).clamp(0, quest.target);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 3 : 6),
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: dense ? 18 : 22, color: done ? BucketColors.learned(context) : theme.colorScheme.outline),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.questTitle(quest),
                style: (dense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
                    ?.copyWith(decoration: done ? TextDecoration.lineThrough : null)),
            if (!dense) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: p / quest.target, minHeight: 5),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Text(done ? '+${quest.xp} XP' : '$p / ${quest.target}', style: theme.textTheme.labelMedium),
      ]),
    );
  }
}

// =====================================================================
//  Shared visuals
// =====================================================================

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
    Widget seg(int n, Color c) => n == 0 ? const SizedBox.shrink() : Expanded(flex: n, child: Container(color: c));
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
