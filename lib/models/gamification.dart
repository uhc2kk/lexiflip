import 'dart:math' as math;

// =====================================================================
//  XP & LEVELS
// =====================================================================

/// XP rewards.
class Xp {
  static const known = 10;
  static const unknown = 4;
  static const dailyGoal = 50;
  static const battleWinBase = 30;
  static const battleWinPerEnemy = 3;
  static const bossWin = 150;
  static const perPerfect = 2; // per word in a no-mistake run
  static const perBlitz = 1; // bonus per word at the end of a speed round
  static const tierUnlock = 100; // × tier number
}

/// Total XP needed to reach [level] (level 1 = 0 XP).
/// 2 → 50, 10 → 2 250, 50 → 61 250, 100 → 247 500, 150 → 558 750.
int xpForLevel(int level) => 25 * (level - 1) * level;

int levelForXp(int xp) => ((1 + math.sqrt(1 + 4 * xp / 25)) / 2).floor().clamp(1, 9999);

/// Ranks unlocked at certain levels.
class Rank {
  const Rank(this.minLevel, this.emoji, this.id);
  final int minLevel;
  final String emoji;
  final String id;
}

const kRanks = <Rank>[
  Rank(1, '🌱', 'beginner'),
  Rank(5, '📖', 'amateur'),
  Rank(10, '🎒', 'student'),
  Rank(20, '🧠', 'expert'),
  Rank(30, '📜', 'seeker'),
  Rank(40, '🔬', 'scholar'),
  Rank(50, '🎓', 'master'),
  Rank(65, '🏛️', 'sage'),
  Rank(80, '🦉', 'wise'),
  Rank(100, '🌟', 'legend'),
  Rank(150, '👑', 'eternal'),
];

Rank rankFor(int level) => kRanks.lastWhere((r) => level >= r.minLevel);
Rank? nextRank(int level) => kRanks.where((r) => r.minLevel > level).firstOrNull;

// =====================================================================
//  TIERED ACHIEVEMENTS
// =====================================================================

/// What an achievement measures.
enum Metric {
  learnedWords,
  streakDays,
  totalAnswers,
  blitzBest,
  battleWins,
  decksMastered,
  perfectBest,
  questsDone,
  level,
  bossWins,
}

/// One achievement with 5 tiers: 🥉 bronze, 🥈 silver, 🥇 gold, 💎 diamond, 👑 legend.
class TieredAchievement {
  const TieredAchievement(this.metric, this.emoji, this.thresholds);
  final Metric metric;
  final String emoji;
  final List<int> thresholds; // length 5

  /// Number of tiers reached (0–5) for [value].
  int tierFor(int value) => thresholds.where((t) => value >= t).length;
  int? nextTarget(int value) => thresholds.where((t) => value < t).firstOrNull;
}

const kTierEmojis = ['🔒', '🥉', '🥈', '🥇', '💎', '👑'];

const kAchievements = <TieredAchievement>[
  TieredAchievement(Metric.learnedWords, '📚', [10, 100, 1000, 5000, 10000]),
  TieredAchievement(Metric.streakDays, '🔥', [3, 7, 30, 100, 365]),
  TieredAchievement(Metric.totalAnswers, '✍️', [100, 1000, 10000, 50000, 100000]),
  TieredAchievement(Metric.blitzBest, '⏱️', [15, 25, 40, 60, 80]),
  TieredAchievement(Metric.battleWins, '⚔️', [1, 10, 50, 200, 1000]),
  TieredAchievement(Metric.bossWins, '🐉', [1, 5, 25, 100, 300]),
  TieredAchievement(Metric.perfectBest, '🎯', [10, 25, 50, 100, 250]),
  TieredAchievement(Metric.decksMastered, '🏆', [1, 5, 20, 50, 100]),
  TieredAchievement(Metric.questsDone, '📋', [5, 50, 200, 1000, 3000]),
  TieredAchievement(Metric.level, '⭐', [5, 20, 50, 100, 150]),
];

// =====================================================================
//  QUESTS
// =====================================================================

/// Counters that quests track.
enum QuestType {
  answers, // any answer
  known, // "Bilaman" answers
  learnedNew, // a word moved into "Yodlangan"
  blitzRounds, // speed rounds finished (60s or 30s)
  battleWins, // problem battles won
  defeated, // problem words defeated in battles / boss
  perfectRun, // best no-mistake run (max, not sum)
  bossWins,
  goalDays, // days the daily goal was met (weekly only)
}

class QuestDef {
  const QuestDef(this.type, this.target, this.xp);
  final QuestType type;
  final int target;
  final int xp;
  String get id => '${type.name}:$target';
}

const kDailyQuestPool = <QuestDef>[
  QuestDef(QuestType.answers, 30, 40),
  QuestDef(QuestType.answers, 60, 70),
  QuestDef(QuestType.answers, 100, 110),
  QuestDef(QuestType.known, 20, 40),
  QuestDef(QuestType.known, 50, 80),
  QuestDef(QuestType.learnedNew, 10, 60),
  QuestDef(QuestType.learnedNew, 25, 120),
  QuestDef(QuestType.blitzRounds, 1, 30),
  QuestDef(QuestType.blitzRounds, 3, 80),
  QuestDef(QuestType.battleWins, 1, 60),
  QuestDef(QuestType.defeated, 10, 60),
  QuestDef(QuestType.perfectRun, 10, 60),
  QuestDef(QuestType.perfectRun, 20, 110),
];

const kWeeklyQuestPool = <QuestDef>[
  QuestDef(QuestType.answers, 300, 300),
  QuestDef(QuestType.answers, 600, 550),
  QuestDef(QuestType.learnedNew, 100, 450),
  QuestDef(QuestType.blitzRounds, 10, 300),
  QuestDef(QuestType.battleWins, 5, 350),
  QuestDef(QuestType.bossWins, 2, 400),
  QuestDef(QuestType.perfectRun, 40, 400),
  QuestDef(QuestType.goalDays, 5, 500),
];

/// Picks [n] quests with different types, the same for everyone on a given
/// day / week (seeded), so they don't change when the app restarts.
List<QuestDef> pickQuests(List<QuestDef> pool, int seed, int n) {
  final rnd = math.Random(seed);
  final shuffled = [...pool]..shuffle(rnd);
  final out = <QuestDef>[];
  for (final q in shuffled) {
    if (out.any((o) => o.type == q.type)) continue;
    out.add(q);
    if (out.length == n) break;
  }
  return out;
}

String dayKey(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-'
      '${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// Monday of the week, e.g. "w2026-10-19".
String weekKey(DateTime d) {
  final l = d.toLocal();
  final monday = DateTime(l.year, l.month, l.day).subtract(Duration(days: l.weekday - 1));
  return 'w${dayKey(monday)}';
}

int seedOf(String key) => key.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);
