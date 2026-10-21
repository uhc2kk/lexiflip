import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/flashcard.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../widgets/card_faces.dart';
import '../widgets/flip_card.dart';
import 'card_editor_screen.dart';
import 'home_screen.dart' show BucketColors;
import 'ui_helpers.dart';

enum StudyMode {
  /// "Qaytarish" + "Muammoli" words, Bilaman / Bilmayman.
  practice,

  /// Only problem words; "Bilmayman" sends the word to the back of the line.
  battle,

  /// 60 / 30 seconds — how many words do you know?
  blitz60,
  blitz30,

  /// Keep going until the first "Bilmayman".
  perfect,

  /// The hardest words (most mistakes). 3 lives.
  boss,

  /// Just flip through every word (← / →), no scoring.
  browse,
}

const kBossSize = 20;
const kBossMin = 5;
const kBossLives = 3;

/// Which cards a mode starts with.
List<Flashcard> cardsForMode(LibraryProvider lib, CardSource src, StudyMode mode) {
  final all = lib.cardsFor(src);
  switch (mode) {
    case StudyMode.practice:
      return all.where((c) => c.status != CardStatus.learned).toList();
    case StudyMode.battle:
      return all.where((c) => c.status == CardStatus.problem).toList();
    case StudyMode.boss:
      final sorted = [...all]
        ..sort((a, b) {
          final w = b.wrong.compareTo(a.wrong);
          if (w != 0) return w;
          int rank(Flashcard c) => switch (c.status) {
                CardStatus.problem => 0,
                CardStatus.review => 1,
                CardStatus.learned => 2,
              };
          return rank(a).compareTo(rank(b));
        });
      return sorted.take(kBossSize).toList();
    case StudyMode.blitz60:
    case StudyMode.blitz30:
    case StudyMode.perfect:
    case StudyMode.browse:
      return all;
  }
}

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, required this.source, required this.mode, required this.cards});

  final CardSource source;
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
  bool _busy = false;

  int _known = 0;
  int _unknown = 0;
  int _xp = 0;
  final Set<String> _missedIds = {};

  // battle / boss
  late int _enemies;
  int _defeated = 0;
  int _lives = kBossLives;

  // timed
  Timer? _timer;
  late int _secondsLeft;
  bool _timerStarted = false;
  bool _newRecord = false;

  StudyMode get _mode => widget.mode;
  bool get _isBlitz => _mode == StudyMode.blitz60 || _mode == StudyMode.blitz30;
  int get _blitzSeconds => _mode == StudyMode.blitz30 ? 30 : 60;
  bool get _scored => _mode != StudyMode.browse;
  bool get _won => (_mode == StudyMode.battle || _mode == StudyMode.boss) && _queue.isEmpty && _lives > 0;
  bool get _answersVisible => _flipped || _isBlitz;

  @override
  void initState() {
    super.initState();
    final ids = widget.cards.map((c) => c.id).toList();
    if (_mode != StudyMode.browse) ids.shuffle();
    _queue = ids;
    _enemies = ids.length;
    _secondsLeft = _blitzSeconds;
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
      speakWord(context, card.word, quiet: true, lang: wordLangOf(context, card.deckId));
    }
  }

  // ---------------- Keyboard ----------------
  //  Space flip · P pronounce · S star
  //  browse: ← / → navigate
  //  scored: ← or 1 = Bilmayman, → or 2 = Bilaman

  bool get _isTyping {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null;
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
    if (key == LogicalKeyboardKey.keyS) {
      final c = _current;
      if (down && c != null) context.read<LibraryProvider>().toggleStar(c.id);
      return true;
    }

    final left = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.digit1;
    final right = key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.digit2;
    if (!left && !right) return false;
    if (!down) return true;

    if (_mode == StudyMode.browse) {
      _browse(right ? 1 : -1);
    } else if (_answersVisible) {
      _answer(known: right);
    }
    return true;
  }

  // ---------------- Actions ----------------

  void _toggleFlip() {
    if (_current == null) return;
    _startTimerIfNeeded();
    setState(() => _flipped = !_flipped);
  }

  void _speak() {
    final c = _current;
    if (c != null) speakWord(context, c.word, lang: wordLangOf(context, c.deckId));
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

  void _startTimerIfNeeded() {
    if (!_isBlitz || _timerStarted) return;
    _timerStarted = true;
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
    if (card == null || _busy) return;
    _busy = true;
    _startTimerIfNeeded();
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

      switch (_mode) {
        case StudyMode.practice:
          _pos++;
          if (_pos >= _queue.length) _finished = true;
        case StudyMode.battle:
        case StudyMode.boss:
          final id = _queue.removeAt(_pos % _queue.length);
          if (known) {
            _defeated++;
          } else {
            _queue.add(id);
            if (_mode == StudyMode.boss) _lives--;
          }
          if (_queue.isEmpty || _lives <= 0) {
            _finished = true;
          } else {
            _pos = _pos % _queue.length;
          }
        case StudyMode.perfect:
          if (!known) {
            _finished = true;
          } else {
            _pos++;
            if (_pos >= _queue.length) {
              _queue.shuffle();
              _pos = 0;
            }
          }
        case StudyMode.blitz60:
        case StudyMode.blitz30:
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

    final before = await lib.answer(card.id, known: known);
    await stats.snapshotDeck(card.deckId, lib.countsOf(card.deckId).learned);
    final reward = await stats.recordAnswer(
      known: known,
      becameLearned: known && before != CardStatus.learned,
      defeatedProblem: known && (_mode == StudyMode.battle || _mode == StudyMode.boss),
      goal: goal,
      lib: lib,
    );
    _xp += reward.xp;
    if (mounted) {
      showReward(context, reward);
      if (reward.goalReached) syncReminder(context);
    }
    _busy = false;

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
    final key = widget.source.key;

    Reward? r;
    switch (_mode) {
      case StudyMode.blitz60:
      case StudyMode.blitz30:
        r = await stats.recordSession(SessionKind.blitz,
            sourceKey: key, score: _known, seconds: _blitzSeconds, goal: goal, lib: lib);
      case StudyMode.perfect:
        r = await stats.recordSession(SessionKind.perfect, sourceKey: key, score: _known, goal: goal, lib: lib);
      case StudyMode.battle:
        if (_won) {
          r = await stats.recordSession(SessionKind.battleWin,
              sourceKey: key, enemies: _enemies, goal: goal, lib: lib);
        }
      case StudyMode.boss:
        if (_won) r = await stats.recordSession(SessionKind.bossWin, sourceKey: key, goal: goal, lib: lib);
      case StudyMode.practice:
      case StudyMode.browse:
        break;
    }
    if (!mounted || r == null) return;
    final reward = r;
    setState(() {
      _xp += reward.xp;
      _newRecord = reward.newRecord;
    });
    showReward(context, reward);
  }

  void _restart(StudyMode mode, List<Flashcard> cards) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => StudyScreen(source: widget.source, mode: mode, cards: cards),
    ));
  }

  // ---------------- UI ----------------

  String _title(S t) => switch (_mode) {
        StudyMode.practice => t.modePractice,
        StudyMode.battle => '⚔️ ${t.battleTitle}',
        StudyMode.blitz60 => '⏱️ ${t.blitzTitle}',
        StudyMode.blitz30 => '⚡ ${t.lightningTitle}',
        StudyMode.perfect => '🎯 ${t.perfectTitle}',
        StudyMode.boss => '🐉 ${t.bossTitle}',
        StudyMode.browse => t.modeBrowse,
      };

  @override
  Widget build(BuildContext context) {
    context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final t = S.of(context);
    final card = _current;
    final showKeyHints = kIsWeb || defaultTargetPlatform != TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(t)),
        actions: [
          if (card != null && !_finished) ...[
            IconButton(
              tooltip: '${t.starToggle} (S)',
              icon: Icon(card.starred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: card.starred ? const Color(0xFFF5B301) : null),
              onPressed: () => context.read<LibraryProvider>().toggleStar(card.id),
            ),
            IconButton(
              tooltip: t.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CardEditorScreen(deckId: card.deckId, cardId: card.id),
              )),
            ),
          ],
          if (_scored && !_finished && !_isBlitz) TextButton(onPressed: _finish, child: Text(t.finish)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _finished || card == null
                  ? _summary(t)
                  : Column(children: [
                      _header(theme, t),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GestureDetector(
                          onHorizontalDragEnd: _mode == StudyMode.browse
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
                                position: Tween<Offset>(begin: Offset(0.1 * _direction, 0), end: Offset.zero)
                                    .animate(anim),
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
                      _controls(t),
                      if (showKeyHints) ...[
                        const SizedBox(height: 10),
                        Text(
                          _mode == StudyMode.browse ? t.keyHintBrowse : t.keyHintScored,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(double value, {Color? color, double height = 6}) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: value.clamp(0.0, 1.0), minHeight: height, color: color),
      );

  Widget _header(ThemeData theme, S t) {
    final style = theme.textTheme.titleMedium;
    switch (_mode) {
      case StudyMode.blitz60:
      case StudyMode.blitz30:
        final frac = _secondsLeft / _blitzSeconds;
        return Column(children: [
          Row(children: [
            Text(_timerStarted ? '$_secondsLeft s' : t.tapToStart, style: style),
            const Spacer(),
            Text('✅ $_known', style: style),
          ]),
          const SizedBox(height: 6),
          _bar(frac, color: frac < 0.25 ? BucketColors.problem(context) : null),
        ]);
      case StudyMode.battle:
        return Column(children: [
          Row(children: [
            Text(t.enemiesLeft(_queue.length), style: style),
            const Spacer(),
            Text('🗡️ $_defeated / $_enemies', style: style),
          ]),
          const SizedBox(height: 6),
          _bar(_enemies == 0 ? 0 : _queue.length / _enemies, color: BucketColors.problem(context), height: 8),
        ]);
      case StudyMode.boss:
        return Column(children: [
          Row(children: [
            Text('🐉 ${_queue.length} / $_enemies', style: style),
            const Spacer(),
            Text(List.generate(kBossLives, (i) => i < _lives ? '❤️' : '🖤').join(' '), style: style),
          ]),
          const SizedBox(height: 6),
          _bar(_enemies == 0 ? 0 : _queue.length / _enemies, color: Colors.deepPurple, height: 10),
        ]);
      case StudyMode.perfect:
        final best = context.read<StatsProvider>().best('perfect:${widget.source.key}');
        return Row(children: [
          Text('🎯 $_known', style: theme.textTheme.headlineSmall),
          const Spacer(),
          if (best > 0) Text(t.record(best), style: style),
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
          _bar(total == 0 ? 0 : n / total, height: 3),
        ]);
    }
  }

  Widget _controls(S t) {
    if (_mode == StudyMode.browse) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.outlined(tooltip: t.prev, onPressed: () => _browse(-1), icon: const Icon(Icons.arrow_back_rounded)),
        const SizedBox(width: 16),
        FilledButton.tonalIcon(
          onPressed: _toggleFlip,
          icon: const Icon(Icons.flip_rounded),
          label: Text(_flipped ? t.showWord : t.showMeaning),
        ),
        const SizedBox(width: 16),
        IconButton.outlined(tooltip: t.next, onPressed: () => _browse(1), icon: const Icon(Icons.arrow_forward_rounded)),
      ]);
    }
    if (!_answersVisible) {
      return FilledButton.tonalIcon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _toggleFlip,
        icon: const Icon(Icons.flip_rounded),
        label: Text(t.showMeaning),
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
          label: Text(t.dontKnow),
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
          label: Text(t.know),
        ),
      ),
    ]);
  }

  Widget _summary(S t) {
    final theme = Theme.of(context);
    final (emoji, title, subtitle) = switch (_mode) {
      StudyMode.blitz60 || StudyMode.blitz30 => (
          _newRecord ? '🏆' : (_mode == StudyMode.blitz30 ? '⚡' : '⏱️'),
          _newRecord ? t.newRecord : t.timeUp,
          t.blitzResult(_known, _blitzSeconds),
        ),
      StudyMode.perfect => (
          _newRecord ? '🏆' : '🎯',
          _newRecord ? t.newRecord : t.perfectOver,
          t.perfectResult(_known),
        ),
      StudyMode.battle => _won
          ? ('⚔️', t.victory, t.victoryMsg(_enemies))
          : ('🛡️', t.battleStopped, t.battleProgress(_defeated, _enemies)),
      StudyMode.boss => _won
          ? ('🐉', t.bossWon, t.bossWonMsg(_lives))
          : ('💀', t.bossLost, t.battleProgress(_defeated, _enemies)),
      _ => (_unknown == 0 && _known > 0 ? '🎉' : '👍', t.practiceDone, t.practiceResult(_known, _unknown)),
    };

    final lib = context.read<LibraryProvider>();
    return Center(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          if (_xp > 0) ...[
            const SizedBox(height: 10),
            Chip(avatar: const Text('✨'), label: Text('+$_xp XP')),
          ],
          const SizedBox(height: 24),
          if (_missedIds.isNotEmpty && _mode != StudyMode.battle && _mode != StudyMode.browse) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(260, 48)),
              onPressed: () => _restart(
                StudyMode.practice,
                _missedIds.map(lib.cardById).whereType<Flashcard>().toList(),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: Text(t.repeatMissed),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(260, 48)),
            onPressed: () {
              final fresh = cardsForMode(lib, widget.source, _mode);
              if (fresh.isEmpty || (_mode == StudyMode.boss && fresh.length < kBossMin)) {
                Navigator.of(context).pop();
                showSnack(context, _mode == StudyMode.battle ? t.noProblemLeft : t.allLearnedShort);
                return;
              }
              _restart(_mode, fresh);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t.again),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.back)),
        ]),
      ),
    );
  }
}
