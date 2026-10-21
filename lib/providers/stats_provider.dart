import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../models/gamification.dart';
import '../services/storage_service.dart';
import 'library_provider.dart';

/// What happened as a result of an answer or a finished session —
/// shown to the user as a small celebration.
class Reward {
  int xp = 0;
  int levelBefore = 1;
  int levelAfter = 1;
  bool goalReached = false;
  bool newRecord = false;
  final List<(TieredAchievement, int)> tiers = [];
  final List<QuestDef> quests = [];

  bool get leveledUp => levelAfter > levelBefore;
  bool get notable => leveledUp || goalReached || tiers.isNotEmpty || quests.isNotEmpty;
}

/// End-of-session results.
enum SessionKind { blitz, battleWin, bossWin, perfect }

/// XP, levels, streak, records, tiered achievements and quests.
/// Stored in the "stats" Hive box (local to each device).
class StatsProvider extends ChangeNotifier {
  final Box _box = StorageService.stats;

  // ---------------- raw storage helpers ----------------

  int _int(String k) => (_box.get(k, defaultValue: 0) as num).toInt();
  Map<String, int> _map(String k) => Map<String, int>.from(
      (_box.get(k, defaultValue: const <String, int>{}) as Map)
          .map((key, v) => MapEntry(key.toString(), (v as num).toInt())));
  List<String> _list(String k) =>
      List<String>.from(_box.get(k, defaultValue: const <String>[]) as List);

  // ---------------- read API ----------------

  int get xp => _int('xp');
  int get level => levelForXp(xp);
  int get totalAnswers => _int('totalAnswers');
  int get battleWins => _int('battleWins');
  int get bossWins => _int('bossWins');
  int get questsDone => _int('questsDone');

  int get todayCount => _map('daily')[dayKey(DateTime.now())] ?? 0;
  int countOn(DateTime day) => _map('daily')[dayKey(day)] ?? 0;

  /// Days in a row the goal was met. Today counts once it's met.
  int streak(int goal) {
    final daily = _map('daily');
    var day = DateTime.now();
    if ((daily[dayKey(day)] ?? 0) < goal) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while ((daily[dayKey(day)] ?? 0) >= goal) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  int best(String recordKey) => _map('best')[recordKey] ?? 0;
  Map<String, int> get allBests => _map('best');

  int _bestOf(String prefix) =>
      _map('best').entries.where((e) => e.key.startsWith(prefix)).fold(0, (m, e) => e.value > m ? e.value : m);

  int tierOf(Metric m) => _map('tiers')[m.name] ?? 0;

  int metricValue(Metric m, {required int goal, required LibraryProvider lib}) => switch (m) {
        Metric.learnedWords => lib.totalCounts.learned,
        Metric.streakDays => streak(goal),
        Metric.totalAnswers => totalAnswers,
        Metric.blitzBest => _bestOf('blitz60:'),
        Metric.battleWins => battleWins,
        Metric.bossWins => bossWins,
        Metric.decksMastered => lib.masteredDecks,
        Metric.perfectBest => _bestOf('perfect:'),
        Metric.questsDone => questsDone,
        Metric.level => level,
      };

  // ---------------- quests ----------------

  String get _todayKey => dayKey(DateTime.now());
  String get _weekKey => weekKey(DateTime.now());

  List<QuestDef> get dailyQuests => pickQuests(kDailyQuestPool, seedOf(_todayKey), 3);
  List<QuestDef> get weeklyQuests => pickQuests(kWeeklyQuestPool, seedOf(_weekKey), 3);

  int questProgress(QuestDef q, {required bool weekly}) =>
      _map('q:${weekly ? _weekKey : _todayKey}')[q.type.name] ?? 0;

  bool questDone(QuestDef q, {required bool weekly}) =>
      _list('qdone:${weekly ? _weekKey : _todayKey}').contains(q.id);

  int get dailyQuestsDone => dailyQuests.where((q) => questDone(q, weekly: false)).length;

  Future<void> _bump(QuestType t, int by, {bool asMax = false}) async {
    for (final period in [_todayKey, _weekKey]) {
      final m = _map('q:$period');
      final cur = m[t.name] ?? 0;
      m[t.name] = asMax ? (by > cur ? by : cur) : cur + by;
      await _box.put('q:$period', m);
    }
  }

  Future<void> _checkQuests(Reward r) async {
    for (final weekly in [false, true]) {
      final period = weekly ? _weekKey : _todayKey;
      final done = _list('qdone:$period');
      for (final q in weekly ? weeklyQuests : dailyQuests) {
        if (done.contains(q.id)) continue;
        if (questProgress(q, weekly: weekly) >= q.target) {
          done.add(q.id);
          r.quests.add(q);
          r.xp += q.xp;
          await _box.put('questsDone', questsDone + 1);
        }
      }
      await _box.put('qdone:$period', done);
    }
  }

  // ---------------- achievements ----------------

  Future<void> _checkTiers(Reward r, int goal, LibraryProvider lib) async {
    final tiers = _map('tiers');
    for (final a in kAchievements) {
      final reached = a.tierFor(metricValue(a.metric, goal: goal, lib: lib));
      final had = tiers[a.metric.name] ?? 0;
      if (reached > had) {
        tiers[a.metric.name] = reached;
        for (var t = had + 1; t <= reached; t++) {
          r.tiers.add((a, t));
          r.xp += Xp.tierUnlock * t;
        }
      }
    }
    await _box.put('tiers', tiers);
  }

  Future<Reward> _finish(Reward r, int goal, LibraryProvider lib) async {
    r.levelBefore = level;
    await _checkQuests(r);
    await _box.put('xp', xp + r.xp);
    // Unlocks can give XP that unlocks more (e.g. the level achievement).
    for (var pass = 0; pass < 2; pass++) {
      final before = r.xp;
      await _checkTiers(r, goal, lib);
      if (r.xp > before) await _box.put('xp', xp + (r.xp - before));
    }
    r.levelAfter = level;
    notifyListeners();
    return r;
  }

  // ---------------- recording ----------------

  /// After each Bilaman / Bilmayman.
  Future<Reward> recordAnswer({
    required bool known,
    required bool becameLearned,
    required bool defeatedProblem,
    required int goal,
    required LibraryProvider lib,
  }) async {
    final r = Reward()..xp = known ? Xp.known : Xp.unknown;

    final daily = _map('daily');
    final today = (daily[_todayKey] ?? 0) + 1;
    daily[_todayKey] = today;
    await _box.put('daily', daily);
    await _box.put('totalAnswers', totalAnswers + 1);

    await _bump(QuestType.answers, 1);
    if (known) await _bump(QuestType.known, 1);
    if (becameLearned) await _bump(QuestType.learnedNew, 1);
    if (defeatedProblem) await _bump(QuestType.defeated, 1);

    if (today == goal) {
      r.goalReached = true;
      r.xp += Xp.dailyGoal;
      await _bump(QuestType.goalDays, 1);
    }
    return _finish(r, goal, lib);
  }

  /// After a speed round / battle / boss / no-mistake run.
  Future<Reward> recordSession(
    SessionKind kind, {
    required String sourceKey,
    int score = 0,
    int seconds = 60,
    int enemies = 0,
    required int goal,
    required LibraryProvider lib,
  }) async {
    final r = Reward();
    Future<void> saveBest(String key) async {
      final bests = _map('best');
      if (score > (bests[key] ?? 0)) {
        bests[key] = score;
        r.newRecord = true;
        await _box.put('best', bests);
      }
    }

    switch (kind) {
      case SessionKind.blitz:
        r.xp += score * Xp.perBlitz;
        await saveBest('blitz$seconds:$sourceKey');
        await _bump(QuestType.blitzRounds, 1);
      case SessionKind.battleWin:
        r.xp += Xp.battleWinBase + enemies * Xp.battleWinPerEnemy;
        await _box.put('battleWins', battleWins + 1);
        await _bump(QuestType.battleWins, 1);
      case SessionKind.bossWin:
        r.xp += Xp.bossWin;
        await _box.put('bossWins', bossWins + 1);
        await _bump(QuestType.bossWins, 1);
      case SessionKind.perfect:
        r.xp += score * Xp.perPerfect;
        await saveBest('perfect:$sourceKey');
        await _bump(QuestType.perfectRun, score, asMax: true);
    }
    return _finish(r, goal, lib);
  }
}
