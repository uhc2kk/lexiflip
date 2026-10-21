import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/flashcard.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../services/tts_service.dart';
import '../widgets/card_faces.dart';
import '../widgets/flip_card.dart';
import 'card_editor_screen.dart';
import 'home_screen.dart' show BucketColors;
import 'ui_helpers.dart';

enum StudyMode {
  /// "Qaytarish" + "Muammoli" words, Bilaman / Bilmayman.
  practice,

  /// Only problem words; "Bilmayman" sends the word to the back of the line
  /// until every enemy is defeated.
  battle,

  /// 60 seconds — how many words do you know?
  blitz,

  /// Just flip through every word (← / →), no scoring.
  browse,
}

const _blitzSeconds = 60;

class StudyScreen extends StatefulWidget {
  const StudyScreen({
    super.key,
    required this.deckId,
    required this.mode,
    required this.cards,
  });

  final String deckId;
  final StudyMode mode;
  final List<Flashcard> cards;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late List<String> _queue;
  int _pos = 0;
  bool _flipped = false;
  int _direction = 1;
  int _tick = 0;
  bool _finished = false;

  // session results
  int _known = 0;
  int _unknown = 0;
  final Set<String> _missedIds = {};

  // battle
  late int _enemies;
  int _defeated = 0;

  // blitz
  Timer? _timer;
  int _secondsLeft = _blitzSeconds;
  bool _blitzStarted = false;
  bool _newRecord = false;

  bool get _scored => widget.mode != StudyMode.browse;

  @override
  void initState() {
    super.initState();
    final ids = widget.cards.map((c) => c.id).toList();
    if (widget.mode != StudyMode.browse) ids.shuffle();
    _queue = ids;
    _enemies = ids.length;
    HardwareKeyboard.instance.addHandler(_handleKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCardShown());
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  Flashcard? get _current {
    if (_queue.isEmpty || _finished) return null;
    return context.read<LibraryProvider>().cardById(_queue[_pos % _queue.length]);
  }

  void _onCardShown() {
    if (!mounted) return;
    final card = _current;
    if (card != null && context.read<SettingsProvider>().autoSpeak) {
      context.read<TtsService>().speak(card.word);
    }
  }

  // ---------------- Keyboard ----------------
  //  Space flip · P pronounce
  //  browse: ← / → navigate
  //  scored: ← or 1 = Bilmayman, → or 2 = Bilaman (after flipping)

  bool get _isTyping {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _handleKey(KeyEvent event) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;

    if (_isTyping) {
      if (key == LogicalKeyboardKey.escape) {
        FocusManager.instance.primaryFocus?.unfocus();
        return true;
      }
      return false;
    }
    if (_finished) return false;
    final down = event is KeyDownEvent;

    if (key == LogicalKeyboardKey.space) {
      if (down) _toggleFlip();
      return true;
    }
    if (key == LogicalKeyboardKey.keyP) {
      if (down) _speak();
      return true;
    }

    final left = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.digit1;
    final right = key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.digit2;
    if (!left && !right) return false;
    if (!down) return true;

    if (widget.mode == StudyMode.browse) {
      _browse(right ? 1 : -1);
    } else if (_flipped || widget.mode == StudyMode.blitz) {
      _answer(known: right);
    }
    return true;
  }

  // ---------------- Actions ----------------

  void _toggleFlip() {
    if (_current == null) return;
    _startBlitzIfNeeded();
    setState(() => _flipped = !_flipped);
  }

  void _speak() {
    final c = _current;
    if (c != null) context.read<TtsService>().speak(c.word);
  }

  void _browse(int dir) {
    if (_queue.length < 2) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _pos = (_pos + dir + _queue.length) % _queue.length;
      _flipped = false;
      _direction = dir;
      _tick++;
    });
    _onCardShown();
  }

  void _startBlitzIfNeeded() {
    if (widget.mode != StudyMode.blitz || _blitzStarted) return;
    _blitzStarted = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _finish();
      }
    });
  }

  Future<void> _answer({required bool known}) async {
    final card = _current;
    if (card == null) return;
    _startBlitzIfNeeded();
    FocusManager.instance.primaryFocus?.unfocus();

    final lib = context.read<LibraryProvider>();
    final stats = context.read<StatsProvider>();
    final goal = context.read<SettingsProvider>().dailyGoal;

    setState(() {
      if (known) {
        _known++;
      } else {
        _unknown++;
        _missedIds.add(card.id);
      }

      switch (widget.mode) {
        case StudyMode.practice:
          _pos++;
          if (_pos >= _queue.length) _finished = true;
        case StudyMode.battle:
          final id = _queue.removeAt(_pos);
          if (known) {
            _defeated++;
          } else {
            _queue.add(id); // comes back later
          }
          if (_queue.isEmpty) {
            _finished = true;
          } else {
            _pos = _pos % _queue.length;
          }
        case StudyMode.blitz:
          _pos++;
          if (_pos >= _queue.length) {
            _queue.shuffle();
            _pos = 0;
          }
        case StudyMode.browse:
          break;
      }
      _flipped = false;
      _direction = 1;
      _tick++;
    });

    await lib.answer(card.id, known: known);
    final unlocked = await stats.recordAnswer(goal: goal, library: lib);
    if (mounted) showAchievements(context, unlocked);

    if (_finished) {
      await _onFinished();
    } else {
      _onCardShown();
    }
  }

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
    _onFinished();
  }

  Future<void> _onFinished() async {
    _timer?.cancel();
    final lib = context.read<LibraryProvider>();
    final stats = context.read<StatsProvider>();
    final goal = context.read<SettingsProvider>().dailyGoal;
    List<Achievement> unlocked = const [];

    if (widget.mode == StudyMode.blitz) {
      final (record, u) =
          await stats.recordBlitz(widget.deckId, _known, goal: goal, library: lib);
      unlocked = u;
      if (mounted) setState(() => _newRecord = record);
    } else if (widget.mode == StudyMode.battle && _queue.isEmpty) {
      unlocked = await stats.recordBattleWin(goal: goal, library: lib);
    }
    if (mounted) showAchievements(context, unlocked);
  }

  void _restart(StudyMode mode, List<Flashcard> cards) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => StudyScreen(deckId: widget.deckId, mode: mode, cards: cards),
    ));
  }

  // ---------------- UI ----------------

  String get _title => switch (widget.mode) {
        StudyMode.practice => 'Mashq',
        StudyMode.battle => '⚔️ Muammolilar jangi',
        StudyMode.blitz => '⏱️ Tezkor raund',
        StudyMode.browse => 'Ko\'rib chiqish',
      };

  @override
  Widget build(BuildContext context) {
    context.watch<LibraryProvider>(); // live mnemonic / edits
    final theme = Theme.of(context);
    final card = _current;
    final showKeyHints = kIsWeb || defaultTargetPlatform != TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (card != null && !_finished)
            IconButton(
              tooltip: 'Tahrirlash',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CardEditorScreen(deckId: card.deckId, cardId: card.id),
              )),
            ),
          if (_scored && !_finished && widget.mode != StudyMode.blitz)
            TextButton(onPressed: _finish, child: const Text('Tugatish')),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _finished || card == null
                  ? _Summary(
                      mode: widget.mode,
                      known: _known,
                      unknown: _unknown,
                      defeated: _defeated,
                      enemies: _enemies,
                      won: widget.mode == StudyMode.battle && _queue.isEmpty,
                      newRecord: _newRecord,
                      onRepeatMissed: _missedIds.isEmpty
                          ? null
                          : () {
                              final lib = context.read<LibraryProvider>();
                              final missed = _missedIds
                                  .map(lib.cardById)
                                  .whereType<Flashcard>()
                                  .toList();
                              _restart(StudyMode.practice, missed);
                            },
                      onAgain: () {
                        final lib = context.read<LibraryProvider>();
                        final fresh = switch (widget.mode) {
                          StudyMode.battle =>
                            lib.cardsOfStatus(widget.deckId, CardStatus.problem),
                          StudyMode.practice => lib
                              .cardsOf(widget.deckId)
                              .where((c) => c.status != CardStatus.learned)
                              .toList(),
                          _ => lib.cardsOf(widget.deckId),
                        };
                        if (fresh.isEmpty) {
                          Navigator.of(context).pop();
                          showSnack(context, widget.mode == StudyMode.battle
                              ? 'Muammoli so\'z qolmadi — zo\'r!'
                              : 'Hamma so\'zlar yodlangan!');
                          return;
                        }
                        _restart(widget.mode, fresh);
                      },
                    )
                  : Column(
                      children: [
                        _header(theme),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragEnd: widget.mode == StudyMode.browse
                                ? (d) {
                                    final v = d.primaryVelocity ?? 0;
                                    if (v < -250) _browse(1);
                                    if (v > 250) _browse(-1);
                                  }
                                : null,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: Offset(0.1 * _direction, 0),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: child,
                                ),
                              ),
                              child: FlipCard(
                                key: ValueKey('${card.id}#$_tick'),
                                flipped: _flipped,
                                onTap: _toggleFlip,
                                front: CardFront(card: card),
                                back: CardBack(card: card),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _controls(theme),
                        if (showKeyHints) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.mode == StudyMode.browse
                                ? 'Space aylantirish · ← → o\'tish · P talaffuz'
                                : 'Space aylantirish · ← / 1 bilmayman · → / 2 bilaman · P talaffuz',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

  Widget _header(ThemeData theme) {
    switch (widget.mode) {
      case StudyMode.blitz:
        final frac = _secondsLeft / _blitzSeconds;
        return Column(children: [
          Row(children: [
            Text(_blitzStarted ? '$_secondsLeft s' : 'Boshlash uchun kartani bosing',
                style: theme.textTheme.titleMedium),
            const Spacer(),
            Text('✅ $_known', style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              color: frac < 0.25 ? BucketColors.problem(context) : null,
            ),
          ),
        ]);
      case StudyMode.battle:
        final left = _queue.length;
        return Column(children: [
          Row(children: [
            Text('Dushmanlar: $left', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text('🗡️ $_defeated / $_enemies', style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _enemies == 0 ? 0 : left / _enemies,
              minHeight: 8,
              color: BucketColors.problem(context),
            ),
          ),
        ]);
      case StudyMode.practice:
      case StudyMode.browse:
        final total = _queue.length;
        final n = (_pos % (total == 0 ? 1 : total)) + 1;
        return Column(children: [
          Row(children: [
            Text('$n / $total', style: theme.textTheme.labelLarge),
            const Spacer(),
            if (_scored) Text('✅ $_known   ❌ $_unknown', style: theme.textTheme.labelLarge),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: total == 0 ? 0 : n / total, minHeight: 3),
          ),
        ]);
    }
  }

  Widget _controls(ThemeData theme) {
    if (widget.mode == StudyMode.browse) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            tooltip: 'Oldingi (←)',
            onPressed: () => _browse(-1),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            onPressed: _toggleFlip,
            icon: const Icon(Icons.flip_rounded),
            label: Text(_flipped ? 'So\'zni ko\'rish' : 'Tarjimani ko\'rish'),
          ),
          const SizedBox(width: 16),
          IconButton.outlined(
            tooltip: 'Keyingi (→)',
            onPressed: () => _browse(1),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      );
    }

    final showAnswers = _flipped || widget.mode == StudyMode.blitz;
    if (!showAnswers) {
      return FilledButton.tonalIcon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _toggleFlip,
        icon: const Icon(Icons.flip_rounded),
        label: const Text('Tarjimani ko\'rish'),
      );
    }
    return Row(children: [
      Expanded(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: BucketColors.problem(context),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _answer(known: false),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Bilmayman'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: BucketColors.learned(context),
            foregroundColor: Colors.white,
          ),
          onPressed: () => _answer(known: true),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Bilaman'),
        ),
      ),
    ]);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.mode,
    required this.known,
    required this.unknown,
    required this.defeated,
    required this.enemies,
    required this.won,
    required this.newRecord,
    required this.onRepeatMissed,
    required this.onAgain,
  });

  final StudyMode mode;
  final int known;
  final int unknown;
  final int defeated;
  final int enemies;
  final bool won;
  final bool newRecord;
  final VoidCallback? onRepeatMissed;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (emoji, title, subtitle) = switch (mode) {
      StudyMode.blitz => (
          newRecord ? '🏆' : '⏱️',
          newRecord ? 'Yangi rekord!' : 'Vaqt tugadi',
          '60 soniyada $known ta so\'z topdingiz',
        ),
      StudyMode.battle => won
          ? ('⚔️', 'G\'alaba!', 'Barcha $enemies ta muammoli so\'z yengildi')
          : ('🛡️', 'Jang to\'xtatildi', '$defeated / $enemies ta dushman yengildi'),
      _ => (
          unknown == 0 && known > 0 ? '🎉' : '👍',
          'Mashq tugadi',
          '$known ta bildingiz · $unknown ta muammoli',
        ),
    };

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 28),
            if (onRepeatMissed != null && mode != StudyMode.battle) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(260, 48)),
                onPressed: onRepeatMissed,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Bilmaganlarimni takrorlash'),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(260, 48)),
              onPressed: onAgain,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yana bir bor'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Orqaga'),
            ),
          ],
        ),
      ),
    );
  }
}
