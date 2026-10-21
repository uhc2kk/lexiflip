import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/deck_provider.dart';
import '../providers/settings_provider.dart';
import '../services/tts_service.dart';
import '../widgets/card_faces.dart';
import '../widgets/flip_card.dart';
import 'card_editor_screen.dart';
import 'card_list_screen.dart';
import 'settings_screen.dart';
import 'sync_actions.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  bool _flipped = false;
  int _direction = 1; // +1 next, -1 previous (for the slide animation)
  int _navTick = 0; // forces a fresh card widget on every navigation

  @override
  void initState() {
    super.initState();
    // Global handler: works no matter which widget currently has focus.
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  // ---------------- Keyboard shortcuts ----------------
  //  Space  flip      ← / →  previous / next      P  pronounce
  //  Esc    leave the mnemonic field

  bool get _isTyping {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _handleKey(KeyEvent event) {
    if (!mounted) return false;
    // Ignore when another route (editor, dialog, settings) is on top.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final key = event.logicalKey;

    if (_isTyping) {
      if (key == LogicalKeyboardKey.escape) {
        FocusManager.instance.primaryFocus?.unfocus();
        return true;
      }
      return false; // let the text field receive Space / arrows
    }

    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) _toggleFlip();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _go(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.keyP && event is KeyDownEvent) {
      _speak();
      return true;
    }
    return false;
  }

  // ---------------- Actions ----------------

  void _toggleFlip() {
    if (context.read<DeckProvider>().isEmpty) return;
    setState(() => _flipped = !_flipped);
  }

  void _go(int dir) {
    final deck = context.read<DeckProvider>();
    if (deck.length < 2) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _flipped = false;
      _direction = dir;
      _navTick++;
    });
    dir > 0 ? deck.next() : deck.previous();
  }

  void _speak() {
    final card = context.read<DeckProvider>().current;
    if (card != null) context.read<TtsService>().speak(card.word);
  }

  Future<void> _openEditor({String? cardId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardEditorScreen(cardId: cardId)),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final deck = context.watch<DeckProvider>();
    final settings = context.read<SettingsProvider>();
    final theme = Theme.of(context);
    final card = deck.current;
    final showKeyHints =
        kIsWeb || defaultTargetPlatform != TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LexiFlip'),
        actions: [
          if (!deck.isEmpty)
            IconButton(
              tooltip: deck.isShuffled ? 'Original order' : 'Shuffle',
              isSelected: deck.isShuffled,
              icon: const Icon(Icons.shuffle_rounded),
              onPressed: () => setState(() {
                _flipped = false;
                _navTick++;
                deck.toggleShuffle();
              }),
            ),
          IconButton(
            tooltip: 'All cards',
            icon: const Icon(Icons.view_list_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CardListScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(theme.brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: () => settings.toggleTheme(theme.brightness),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              switch (v) {
                case 'export':
                  SyncActions.export(context);
                case 'import':
                  SyncActions.import(context);
                case 'settings':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SettingsScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file_rounded),
                  title: Text('Export to JSON'),
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download_rounded),
                  title: Text('Import from JSON'),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add word',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: card == null
            ? _EmptyState(onAdd: () => _openEditor())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
                    child: Column(
                      children: [
                        // Progress
                        Row(
                          children: [
                            Text('${deck.index + 1} / ${deck.length}',
                                style: theme.textTheme.labelLarge),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Edit card',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _openEditor(cardId: card.id),
                            ),
                          ],
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (deck.index + 1) / deck.length,
                            minHeight: 3,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Card (swipe left/right on touch screens)
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragEnd: (d) {
                              final v = d.primaryVelocity ?? 0;
                              if (v < -250) _go(1);
                              if (v > 250) _go(-1);
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) {
                                final slide = Tween<Offset>(
                                  begin: Offset(0.12 * _direction, 0),
                                  end: Offset.zero,
                                ).animate(anim);
                                return FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                      position: slide, child: child),
                                );
                              },
                              child: FlipCard(
                                key: ValueKey('${card.id}#$_navTick'),
                                flipped: _flipped,
                                onTap: _toggleFlip,
                                front: CardFront(card: card),
                                back: CardBack(card: card),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.outlined(
                              tooltip: 'Previous (←)',
                              onPressed: () => _go(-1),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 16),
                            FilledButton.tonalIcon(
                              onPressed: _toggleFlip,
                              icon: const Icon(Icons.flip_rounded),
                              label: Text(_flipped ? 'Show word' : 'Show meaning'),
                            ),
                            const SizedBox(width: 16),
                            IconButton.outlined(
                              tooltip: 'Next (→)',
                              onPressed: () => _go(1),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                          ],
                        ),
                        if (showKeyHints) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Space flip  ·  ← → navigate  ·  P pronounce',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_outlined,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No cards yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your first word, or import a deck exported from another device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add word'),
                ),
                OutlinedButton.icon(
                  onPressed: () => SyncActions.import(context),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Import JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
