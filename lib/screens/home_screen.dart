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
import 'app_shell.dart';
import 'hub_screen.dart';
import 'pdf_import_screen.dart';
import 'sync_actions.dart';
import 'ui_helpers.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// Narrow = phone portrait.
bool _narrow(BuildContext context) => MediaQuery.sizeOf(context).width < 600;

// =====================================================================
//  Shared actions
// =====================================================================

Future<void> _newBook(BuildContext context, {String? languageId, bool thenPdf = false}) async {
  final t = S.of(context);
  final lib = context.read<LibraryProvider>();
  final res = await showDeckForm(context, title: t.newDeck, folderId: languageId, okLabel: t.create);
  if (res == null || !context.mounted) return;
  final deck = await lib.createDeck(res.name, folderId: res.folderId);
  if (!context.mounted) return;
  _push(context, thenPdf ? PdfImportScreen(deckId: deck.id) : HubScreen(source: CardSource.deck(deck.id)));
}

Future<void> _newLanguage(BuildContext context) async {
  final t = S.of(context);
  final name = await showTextInput(context, title: t.newFolder, label: t.languageName, okLabel: t.create);
  if (name == null || !context.mounted) return;
  await context.read<LibraryProvider>().ensureLanguage(name);
}

Future<void> _bookAction(BuildContext context, Deck d, String action) async {
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
    case 'pdf':
      _push(context, PdfImportScreen(deckId: d.id));
    case 'json':
      await SyncActions.importIntoBook(context, d.id);
    case 'export':
      await SyncActions.export(context, deck: d);
    case 'delete':
      final ok = await confirm(context,
          title: t.deleteQ, message: t.deleteDeckMsg(d.name, lib.countsOf(d.id).total), ok: t.delete, danger: true);
      if (ok) await lib.deleteDeck(d.id);
  }
}

List<PopupMenuEntry<String>> _bookMenu(S t, Deck d) => [
      PopupMenuItem(value: 'star', child: Text(d.starred ? t.unfavourite : t.favouriteDeck)),
      PopupMenuItem(value: 'edit', child: Text(t.nameAndFolder)),
      PopupMenuItem(value: 'langs', child: Text(t.deckLanguages)),
      PopupMenuItem(value: 'pdf', child: Text(t.pdfImport)),
      PopupMenuItem(value: 'json', child: Text(t.importIntoBook)),
      PopupMenuItem(value: 'export', child: Text(t.exportJson)),
      PopupMenuItem(value: 'delete', child: Text(t.delete)),
    ];

/// Bottom sheet behind the + button.
void _addSheet(BuildContext context, {String? languageId}) {
  final t = S.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      Widget item(IconData icon, String title, String? sub, VoidCallback onTap) => ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: sub == null ? null : Text(sub),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          item(Icons.menu_book_rounded, t.newDeck, null, () => _newBook(context, languageId: languageId)),
          item(Icons.picture_as_pdf_rounded, t.newBookFromPdf, t.newBookFromPdfSub,
              () => _newBook(context, languageId: languageId, thenPdf: true)),
          item(Icons.download_rounded, t.importJson, null,
              () => SyncActions.import(context, intoFolderId: languageId)),
          if (languageId == null) item(Icons.translate_rounded, t.newFolder, null, () => _newLanguage(context)),
        ]),
      );
    },
  );
}

// =====================================================================
//  Home: languages
// =====================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _selecting = false;
  final Set<String> _selected = {};

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _languageAction(Folder f, String action) async {
    final t = S.of(context);
    final lib = context.read<LibraryProvider>();
    switch (action) {
      case 'rename':
        final name = await showTextInput(context, title: t.rename, label: t.languageName, initial: f.name);
        if (name != null) await lib.renameFolder(f, name);
      case 'export':
        await SyncActions.export(context, folderId: f.id);
      case 'delete':
        final ok = await confirm(context,
            title: t.deleteQ,
            message: t.deleteFolderMsg(f.name, lib.decksInTree(f.id).length, lib.countsOfFolder(f.id).total),
            ok: t.delete,
            danger: true);
        if (ok) await lib.deleteFolder(f.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final t = S.of(context);
    final languages = lib.subfolders(null);
    final loose = lib.decksIn(null);
    final favourites = lib.starredDecks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LexiFlip'),
        actions: [
          IconButton(
            tooltip: t.select,
            isSelected: _selecting,
            icon: const Icon(Icons.checklist_rounded),
            onPressed: () => setState(() {
              _selecting = !_selecting;
              _selected.clear();
            }),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'import') SyncActions.import(context);
              if (v == 'export') SyncActions.export(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'import', child: ListTile(leading: const Icon(Icons.download_rounded), title: Text(t.importJson))),
              PopupMenuItem(value: 'export', child: ListTile(leading: const Icon(Icons.upload_file_rounded), title: Text(t.exportAll))),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _selecting
          ? FloatingActionButton.extended(
              onPressed: _selected.isEmpty
                  ? null
                  : () => _push(context, HubScreen(source: CardSource.multi(_selected.toList()))),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(t.practiceTogether(_selected.length)),
            )
          : FloatingActionButton(
              tooltip: t.add,
              onPressed: () => _addSheet(context),
              child: const Icon(Icons.add_rounded),
            ),
      body: _Page(children: [
        const ProgressHeader(),
        const SizedBox(height: 12),
        const QuestStrip(),
        const SizedBox(height: 12),
        _CollectionsRow(
          onStarred: () => _push(context, const HubScreen(source: CardSource.starred())),
          onHardest: () => _push(context, const HubScreen(source: CardSource.hardest())),
        ),
        if (favourites.isNotEmpty) ...[
          _SectionTitle('⭐ ${t.favouriteDecks}'),
          for (final d in favourites)
            BookTile(
              deck: d,
              subtitle: lib.folderById(d.folderId)?.name,
              selecting: _selecting,
              selected: _selected.contains(d.id),
              onTap: () => _selecting ? _toggle(d.id) : _push(context, HubScreen(source: CardSource.deck(d.id))),
            ),
        ],
        _SectionTitle(t.folders),
        if (languages.isEmpty && loose.isEmpty)
          _EmptyState(
            icon: Icons.translate_rounded,
            title: t.noDecks,
            hint: t.noDecksHint,
            actions: [
              FilledButton.icon(
                onPressed: () => _newLanguage(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(t.newFolder),
              ),
              OutlinedButton.icon(
                onPressed: () => SyncActions.import(context),
                icon: const Icon(Icons.download_rounded),
                label: Text(t.importJson),
              ),
            ],
          )
        else
          _ReorderList<Folder>(
            items: languages,
            keyOf: (f) => f.id,
            enabled: !_selecting,
            onReorder: lib.reorderFolders,
            itemBuilder: (f, handle) => _LanguageTile(
              folder: f,
              handle: handle,
              onTap: () => _push(context, LanguageScreen(folderId: f.id)),
              onAction: (a) => _languageAction(f, a),
            ),
          ),
        if (loose.isNotEmpty) ...[
          _SectionTitle(t.noFolder),
          for (final d in loose)
            BookTile(
              deck: d,
              selecting: _selecting,
              selected: _selected.contains(d.id),
              onTap: () => _selecting ? _toggle(d.id) : _push(context, HubScreen(source: CardSource.deck(d.id))),
            ),
        ],
      ]),
    );
  }
}

// =====================================================================
//  Language page: books
// =====================================================================

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, required this.folderId});
  final String folderId;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool _selecting = false;
  final Set<String> _selected = {};

  Future<void> _menu(Folder f, String action) async {
    final t = S.of(context);
    final lib = context.read<LibraryProvider>();
    switch (action) {
      case 'rename':
        final name = await showTextInput(context, title: t.rename, label: t.languageName, initial: f.name);
        if (name != null) await lib.renameFolder(f, name);
      case 'export':
        await SyncActions.export(context, folderId: f.id);
      case 'delete':
        final ok = await confirm(context,
            title: t.deleteQ,
            message: t.deleteFolderMsg(f.name, lib.decksInTree(f.id).length, lib.countsOfFolder(f.id).total),
            ok: t.delete,
            danger: true);
        if (ok) {
          await lib.deleteFolder(f.id);
          if (mounted) Navigator.of(context).pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final t = S.of(context);
    final folder = lib.folderById(widget.folderId);
    if (folder == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(t.nothingFound)));
    final books = lib.decksIn(folder.id);
    final c = lib.countsOfFolder(folder.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
            tooltip: t.select,
            isSelected: _selecting,
            icon: const Icon(Icons.checklist_rounded),
            onPressed: () => setState(() {
              _selecting = !_selecting;
              _selected.clear();
            }),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _menu(folder, v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(t.rename)),
              PopupMenuItem(value: 'export', child: Text(t.exportJson)),
              PopupMenuItem(value: 'delete', child: Text(t.delete)),
            ],
          ),
        ],
      ),
      floatingActionButton: _selecting
          ? FloatingActionButton.extended(
              onPressed: _selected.isEmpty
                  ? null
                  : () => _push(context, HubScreen(source: CardSource.multi(_selected.toList()))),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(t.practiceTogether(_selected.length)),
            )
          : FloatingActionButton(
              tooltip: t.add,
              onPressed: () => _addSheet(context, languageId: folder.id),
              child: const Icon(Icons.add_rounded),
            ),
      body: _Page(children: [
        if (c.total > 0)
          _SummaryCard(
            counts: c,
            label: t.practiceFolder(c.total),
            onPractice: () => _push(context, HubScreen(source: CardSource.folder(folder.id))),
          ),
        if (_selecting)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(t.selectHint, style: Theme.of(context).textTheme.bodySmall),
          ),
        _SectionTitle(t.decks),
        if (books.isEmpty)
          _EmptyState(
            icon: Icons.menu_book_rounded,
            title: t.emptyFolder,
            actions: [
              FilledButton.icon(
                onPressed: () => _newBook(context, languageId: folder.id),
                icon: const Icon(Icons.add_rounded),
                label: Text(t.newDeck),
              ),
              OutlinedButton.icon(
                onPressed: () => _newBook(context, languageId: folder.id, thenPdf: true),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(t.newBookFromPdf),
              ),
            ],
          )
        else
          _ReorderList<Deck>(
            items: books,
            keyOf: (d) => d.id,
            enabled: !_selecting,
            onReorder: lib.reorderDecks,
            itemBuilder: (d, handle) => BookTile(
              deck: d,
              handle: handle,
              selecting: _selecting,
              selected: _selected.contains(d.id),
              onTap: () {
                if (_selecting) {
                  setState(() => _selected.contains(d.id) ? _selected.remove(d.id) : _selected.add(d.id));
                } else {
                  _push(context, HubScreen(source: CardSource.deck(d.id)));
                }
              },
            ),
          ),
      ]),
    );
  }
}

// =====================================================================
//  Layout pieces
// =====================================================================

/// Centred, width-limited scrolling page with room for the FAB.
class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pad = _narrow(context) ? 12.0 : 16.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: EdgeInsets.fromLTRB(pad, 4, pad, 96), children: children),
      ),
    );
  }
}

/// Non-scrolling reorderable list. PC: drag the ⠿ handle (or press & hold);
/// phone: press and hold the item.
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
        const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}.contains(defaultTargetPlatform);
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      );
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.folder, required this.handle, required this.onTap, required this.onAction});
  final Folder folder;
  final Widget? handle;
  final VoidCallback onTap;
  final void Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final t = S.of(context);
    final theme = Theme.of(context);
    final c = lib.countsOfFolder(folder.id);
    final books = lib.decksIn(folder.id).length;
    final initial = folder.name.isEmpty ? '?' : folder.name.characters.first.toUpperCase();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 14, 0, 14),
          child: Row(children: [
            if (handle != null) handle!,
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(initial,
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(folder.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(t.languageInfo(books, c.learned, c.total), style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                BucketBar(counts: c),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: onAction,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(t.rename)),
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

/// A book in a list.
class BookTile extends StatelessWidget {
  const BookTile({
    super.key,
    required this.deck,
    required this.onTap,
    this.handle,
    this.subtitle,
    this.selecting = false,
    this.selected = false,
  });
  final Deck deck;
  final VoidCallback onTap;
  final Widget? handle;
  final String? subtitle;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LibraryProvider>().countsOf(deck.id);
    final t = S.of(context);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 14, 0, 14),
          child: Row(children: [
            if (selecting)
              Checkbox(value: selected, onChanged: (_) => onTap())
            else if (handle != null)
              handle!,
            const SizedBox(width: 8),
            Icon(Icons.menu_book_rounded, size: 30, color: theme.colorScheme.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(deck.name,
                        style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  if (deck.starred) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF5B301)),
                  ],
                ]),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                BucketBar(counts: c),
                const SizedBox(height: 6),
                Text(t.bookCounts(c.total, c.learned, c.problem), style: theme.textTheme.bodySmall),
              ]),
            ),
            if (!selecting)
              PopupMenuButton<String>(
                onSelected: (a) => _bookAction(context, deck, a),
                itemBuilder: (_) => _bookMenu(t, deck),
              )
            else
              const SizedBox(width: 12),
          ]),
        ),
      ),
    );
  }
}

/// ⭐ Starred words + 💀 hardest words. Side by side on wide screens,
/// stacked on phones (so the text never gets squeezed).
class _CollectionsRow extends StatelessWidget {
  const _CollectionsRow({required this.onStarred, required this.onHardest});
  final VoidCallback onStarred;
  final VoidCallback onHardest;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final t = S.of(context);
    final starred = _CollectionTile(
      leading: const Icon(Icons.star_rounded, color: Color(0xFFF5B301), size: 28),
      title: t.starred,
      subtitle: lib.starredCount == 0 ? t.starredHintShort : t.wordsN(lib.starredCount),
      onTap: onStarred,
    );
    final n = lib.hardestCards.length;
    final hardest = _CollectionTile(
      leading: const Text('💀', style: TextStyle(fontSize: 24)),
      title: t.hardest,
      subtitle: n == 0 ? t.hardestEmptyShort : t.wordsN(n),
      onTap: onHardest,
    );
    if (_narrow(context)) {
      return Column(children: [starred, const SizedBox(height: 8), hardest]);
    }
    return Row(children: [
      Expanded(child: starred),
      const SizedBox(width: 10),
      Expanded(child: hardest),
    ]);
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.leading, required this.title, required this.subtitle, required this.onTap});
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            SizedBox(width: 32, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.counts, required this.label, required this.onPractice});
  final DeckCounts counts;
  final String label;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 4),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.bookCounts(counts.total, counts.learned, counts.problem), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          BucketBar(counts: counts, height: 8),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: onPractice,
            icon: const Icon(Icons.library_books_outlined),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, this.hint, required this.actions});
  final IconData icon;
  final String title;
  final String? hint;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(children: [
        Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: actions),
      ]),
    );
  }
}

// =====================================================================
//  Progress header & quests
// =====================================================================

/// Level + XP bar + today's goal + streak. Tap → Challenge tab.
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
        onTap: () => AppShell.goTo(context, 1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Text(rank.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.levelN(level), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(t.rankName(rank.id), style: theme.textTheme.bodyMedium),
                ]),
              ),
              _Pill(icon: streak > 0 ? '🔥' : '💤', text: t.days(streak)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                width: 46,
                height: 46,
                child: Stack(fit: StackFit.expand, children: [
                  CircularProgressIndicator(
                    value: (today / goal).clamp(0.0, 1.0),
                    strokeWidth: 5,
                    backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  Center(child: Text(today >= goal ? '✓' : '$today', style: theme.textTheme.labelLarge)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(t.goalShort(goal), style: theme.textTheme.bodySmall),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(text, style: theme.textTheme.labelLarge),
      ]),
    );
  }
}

/// Today's 3 quests in one compact card. Tap → Challenge tab.
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
        onTap: () => AppShell.goTo(context, 1),
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
      padding: EdgeInsets.symmetric(vertical: dense ? 4 : 6),
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
