import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/gamification.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import 'home_screen.dart' show QuestRow;

/// Level, quests, last 7 days, records and tiered achievements.
class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final lib = context.watch<LibraryProvider>();
    final goal = context.select<SettingsProvider, int>((s) => s.dailyGoal);
    final t = S.of(context);
    final theme = Theme.of(context);
    final total = lib.totalCounts;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
          child: Text(text, style: theme.textTheme.titleMedium),
        );

    String sourceName(String key) {
      if (key == 'starred') return '⭐ ${t.starred}';
      if (key.startsWith('multi:')) return t.selectedDecks(key.substring(6).split(',').length);
      if (key.startsWith('folder:')) return '📁 ${lib.folderById(key.substring(7))?.name ?? '—'}';
      final d = lib.deckById(key);
      return d == null ? '—' : lib.deckTitle(d);
    }

    List<(String, int)> records(String prefix) {
      final list = [
        for (final e in stats.allBests.entries)
          if (e.key.startsWith(prefix)) (sourceName(e.key.substring(prefix.length)), e.value),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      return list.take(5).toList();
    }

    Widget recordList(String emoji, String title, String prefix) {
      final list = records(prefix);
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$emoji $title', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            if (list.isEmpty)
              Text(t.noRecords, style: theme.textTheme.bodySmall)
            else
              for (final (i, r) in list.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    SizedBox(width: 28, child: Text(['🥇', '🥈', '🥉'].elementAtOrNull(i) ?? '${i + 1}.')),
                    Expanded(child: Text(r.$1, overflow: TextOverflow.ellipsis)),
                    Text('${r.$2}', style: theme.textTheme.titleSmall),
                  ]),
                ),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.challengesTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _LevelCard(stats: stats),
              header('📋 ${t.dailyQuests}'),
              for (final q in stats.dailyQuests) QuestRow(quest: q, weekly: false),
              header('🗓️ ${t.weeklyQuests}'),
              for (final q in stats.weeklyQuests) QuestRow(quest: q, weekly: true),
              header(t.last7Days),
              _WeekChart(stats: stats, goal: goal),
              header(t.overall),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _StatChip('✨', '${stats.xp}', 'XP'),
                _StatChip('🔥', '${stats.streak(goal)}', t.statStreak),
                _StatChip('📚', '${total.learned}', t.statLearned),
                _StatChip('🔴', '${total.problem}', t.statProblem),
                _StatChip('🗂️', '${total.total}', t.statTotal),
                _StatChip('✍️', '${stats.totalAnswers}', t.statAnswers),
                _StatChip('⚔️', '${stats.battleWins}', t.statBattles),
                _StatChip('🐉', '${stats.bossWins}', t.statBosses),
                _StatChip('📋', '${stats.questsDone}', t.statQuests),
              ]),
              header(t.records),
              recordList('⏱️', t.blitzTitle, 'blitz60:'),
              recordList('⚡', t.lightningTitle, 'blitz30:'),
              recordList('🎯', t.perfectTitle, 'perfect:'),
              header(t.achievementsTitle(
                kAchievements.fold(0, (s, a) => s + stats.tierOf(a.metric)),
                kAchievements.length * 5,
              )),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 600 ? 3 : 2;
                final w = (c.maxWidth - 8 * (cols - 1)) / cols;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final a in kAchievements)
                    SizedBox(
                      width: w,
                      child: _AchievementTile(
                        achievement: a,
                        value: stats.metricValue(a.metric, goal: goal, lib: lib),
                      ),
                    ),
                ]);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.stats});
  final StatsProvider stats;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final level = stats.level;
    final rank = rankFor(level);
    final next = nextRank(level);
    final from = xpForLevel(level), to = xpForLevel(level + 1);
    final frac = ((stats.xp - from) / (to - from)).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(rank.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.levelN(level), style: theme.textTheme.headlineSmall),
                Text(t.rankName(rank.id), style: theme.textTheme.titleMedium),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: frac, minHeight: 10),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('${stats.xp - from} / ${to - from} XP', style: theme.textTheme.bodySmall),
            const Spacer(),
            if (next != null)
              Text(t.nextRank(next.emoji, t.rankName(next.id), next.minLevel), style: theme.textTheme.bodySmall),
          ]),
        ]),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.value});
  final TieredAchievement achievement;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final tier = achievement.tierFor(value);
    final next = achievement.nextTarget(value);
    final prev = tier == 0 ? 0 : achievement.thresholds[tier - 1];
    final frac = next == null ? 1.0 : ((value - prev) / (next - prev)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tier > 0 ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(achievement.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t.achievementName(achievement.metric),
                style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 1; i <= 5; i++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Opacity(opacity: i <= tier ? 1 : 0.25, child: Text(kTierEmojis[i], style: const TextStyle(fontSize: 18))),
            ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: frac, minHeight: 6),
        ),
        const SizedBox(height: 4),
        Text(next == null ? t.maxTier : '$value / $next', style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.stats, required this.goal});
  final StatsProvider stats;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdays = S.of(context).weekdays;
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    final counts = days.map(stats.countOn).toList();
    final maxV = [goal, ...counts].reduce((a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: 140,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${counts[i]}', style: theme.textTheme.labelSmall),
                const SizedBox(height: 4),
                Container(
                  height: maxV == 0 ? 2 : (90 * counts[i] / maxV).clamp(2, 90).toDouble(),
                  decoration: BoxDecoration(
                    color: counts[i] >= goal ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(weekdays[days[i].weekday - 1],
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: i == 6 ? FontWeight.w700 : null)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.emoji, this.value, this.label);
  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}
