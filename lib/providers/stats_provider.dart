import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../services/storage_service.dart';
import 'library_provider.dart';

/// A badge the user can unlock.
class Achievement {
  const Achievement(this.id, this.emoji, this.title, this.description);
  final String id;
  final String emoji;
  final String title;
  final String description;
}

const kAchievements = <Achievement>[
  Achievement('first_answer', '🌱', 'Birinchi qadam', 'Birinchi so\'zga javob berdingiz'),
  Achievement('learned_10', '📗', '10 ta so\'z', '10 ta so\'z yodlandi'),
  Achievement('learned_50', '📘', '50 ta so\'z', '50 ta so\'z yodlandi'),
  Achievement('learned_100', '📚', '100 ta so\'z', '100 ta so\'z yodlandi'),
  Achievement('learned_500', '🏛️', '500 ta so\'z', '500 ta so\'z yodlandi'),
  Achievement('daily_goal', '🎯', 'Maqsadga erishdim', 'Kunlik maqsad birinchi marta bajarildi'),
  Achievement('streak_3', '🔥', '3 kun ketma-ket', 'Kunlik maqsad 3 kun ketma-ket bajarildi'),
  Achievement('streak_7', '⚡', 'Bir hafta', 'Kunlik maqsad 7 kun ketma-ket bajarildi'),
  Achievement('streak_30', '👑', 'Bir oy', 'Kunlik maqsad 30 kun ketma-ket bajarildi'),
  Achievement('blitz_20', '⏱️', 'Tezkor', 'Tezkor raundda 20+ so\'z topildi'),
  Achievement('blitz_40', '🚀', 'Chaqmoq', 'Tezkor raundda 40+ so\'z topildi'),
  Achievement('battle_win', '⚔️', 'G\'olib', 'Muammolilar jangida g\'alaba qozonildi'),
  Achievement('battle_5', '🛡️', 'Jangchi', 'Muammolilar jangida 5 marta g\'alaba'),
  Achievement('deck_master', '🏆', 'Mavzu ustasi', 'Bitta to\'plam 100% yodlandi'),
];

/// Daily goal, streak, best scores and unlocked achievements.
/// Stored in the "stats" Hive box (local to each device).
class StatsProvider extends ChangeNotifier {
  StatsProvider();

  final Box _box = StorageService.stats;

  static String dayKey(DateTime d) {
    final l = d.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  Map<String, int> get _daily =>
      Map<String, int>.from(_box.get('daily', defaultValue: <String, int>{}) as Map);
  Map<String, int> get _blitzBest =>
      Map<String, int>.from(_box.get('blitzBest', defaultValue: <String, int>{}) as Map);
  Map<String, String> get _unlocked =>
      Map<String, String>.from(_box.get('achievements', defaultValue: <String, String>{}) as Map);

  int get totalAnswers => _box.get('totalAnswers', defaultValue: 0) as int;
  int get battleWins => _box.get('battleWins', defaultValue: 0) as int;

  int get todayCount => _daily[dayKey(DateTime.now())] ?? 0;
  int countOn(DateTime day) => _daily[dayKey(day)] ?? 0;

  /// Days in a row the goal was met. Today counts only once it's met,
  /// so the streak doesn't drop to 0 in the morning.
  int streak(int goal) {
    final daily = _daily;
    var day = DateTime.now();
    if ((daily[dayKey(day)] ?? 0) < goal) {
      day = day.subtract(const Duration(days: 1));
    }
    var n = 0;
    while ((daily[dayKey(day)] ?? 0) >= goal) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  int bestBlitz(String deckId) => _blitzBest[deckId] ?? 0;
  int get bestBlitzOverall =>
      _blitzBest.values.fold(0, (a, b) => a > b ? a : b);

  bool isUnlocked(String id) => _unlocked.containsKey(id);
  DateTime? unlockedAt(String id) => DateTime.tryParse(_unlocked[id] ?? '');
  int get unlockedCount => _unlocked.length;

  // ---------------- Recording ----------------

  /// Call after each Bilaman / Bilmayman. Returns newly unlocked badges.
  Future<List<Achievement>> recordAnswer({
    required int goal,
    required LibraryProvider library,
  }) async {
    final daily = _daily;
    final key = dayKey(DateTime.now());
    daily[key] = (daily[key] ?? 0) + 1;
    await _box.put('daily', daily);
    await _box.put('totalAnswers', totalAnswers + 1);
    final unlocked = await _checkAchievements(goal: goal, library: library);
    notifyListeners();
    return unlocked;
  }

  /// Returns true if it's a new personal best for the deck.
  Future<(bool, List<Achievement>)> recordBlitz(
    String deckId,
    int score, {
    required int goal,
    required LibraryProvider library,
  }) async {
    final best = _blitzBest;
    final isRecord = score > (best[deckId] ?? 0);
    if (isRecord) {
      best[deckId] = score;
      await _box.put('blitzBest', best);
    }
    final unlocked = await _checkAchievements(goal: goal, library: library);
    notifyListeners();
    return (isRecord, unlocked);
  }

  Future<List<Achievement>> recordBattleWin({
    required int goal,
    required LibraryProvider library,
  }) async {
    await _box.put('battleWins', battleWins + 1);
    final unlocked = await _checkAchievements(goal: goal, library: library);
    notifyListeners();
    return unlocked;
  }

  Future<List<Achievement>> _checkAchievements({
    required int goal,
    required LibraryProvider library,
  }) async {
    final learned = library.totalCounts.learned;
    final s = streak(goal);
    final checks = <String, bool>{
      'first_answer': totalAnswers >= 1,
      'learned_10': learned >= 10,
      'learned_50': learned >= 50,
      'learned_100': learned >= 100,
      'learned_500': learned >= 500,
      'daily_goal': todayCount >= goal,
      'streak_3': s >= 3,
      'streak_7': s >= 7,
      'streak_30': s >= 30,
      'blitz_20': bestBlitzOverall >= 20,
      'blitz_40': bestBlitzOverall >= 40,
      'battle_win': battleWins >= 1,
      'battle_5': battleWins >= 5,
      'deck_master': library.masteredDecks >= 1,
    };
    final unlocked = _unlocked;
    final fresh = <Achievement>[];
    for (final a in kAchievements) {
      if ((checks[a.id] ?? false) && !unlocked.containsKey(a.id)) {
        unlocked[a.id] = DateTime.now().toUtc().toIso8601String();
        fresh.add(a);
      }
    }
    if (fresh.isNotEmpty) await _box.put('achievements', unlocked);
    return fresh;
  }
}
