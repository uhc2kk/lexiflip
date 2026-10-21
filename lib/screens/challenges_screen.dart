import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import 'home_screen.dart' show DailyGoalCard;
import 'ui_helpers.dart';

/// Daily goal, last 7 days, speed-round records and achievements.
class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final lib = context.watch<LibraryProvider>();
    final goal = context.select<SettingsProvider, int>((s) => s.dailyGoal);
    final theme = Theme.of(context);
    final total = lib.totalCounts;

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
          child: Text(t, style: theme.textTheme.titleMedium),
        );

    final records = [
      for (final d in lib.decks)
        if (stats.bestBlitz(d.id) > 0) (deckTitle(d), stats.bestBlitz(d.id)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return Scaffold(
      appBar: AppBar(title: const Text('Challenge va yutuqlar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const DailyGoalCard(),
              header('Oxirgi 7 kun'),
              _WeekChart(stats: stats, goal: goal),
              header('Umumiy'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip('📚', '${total.learned}', 'yodlangan'),
                  _StatChip('🔴', '${total.problem}', 'muammoli'),
                  _StatChip('🗂️', '${total.total}', 'jami so\'z'),
                  _StatChip('✍️', '${stats.totalAnswers}', 'javob'),
                  _StatChip('⚔️', '${stats.battleWins}', 'jang g\'alabasi'),
                ],
              ),
              header('Tezkor raund rekordlari'),
              if (records.isEmpty)
                const Text('Hali rekord yo\'q. To\'plamni ochib "Tezkor raund"ni boshlang!')
              else
                for (final (i, r) in records.take(10).indexed)
                  ListTile(
                    dense: true,
                    leading: Text(['🥇', '🥈', '🥉'].elementAtOrNull(i) ?? '  ${i + 1}.',
                        style: const TextStyle(fontSize: 20)),
                    title: Text(r.$1),
                    trailing: Text('${r.$2} ta', style: theme.textTheme.titleMedium),
                  ),
              header('Yutuqlar (${stats.unlockedCount} / ${kAchievements.length})'),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
                children: [
                  for (final a in kAchievements)
                    _Badge(achievement: a, unlocked: stats.isUnlocked(a.id)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.stats, required this.goal});
  final StatsProvider stats;
  final int goal;

  static const _days = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    final counts = days.map(stats.countOn).toList();
    final maxV = [goal, ...counts].reduce((a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${counts[i]}', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Container(
                      height: maxV == 0 ? 2 : (90 * counts[i] / maxV).clamp(2, 90).toDouble(),
                      decoration: BoxDecoration(
                        color: counts[i] >= goal
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_days[days[i].weekday - 1],
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: i == 6 ? FontWeight.w700 : null,
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.achievement, required this.unlocked});
  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: achievement.description,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: unlocked
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Opacity(
          opacity: unlocked ? 1 : 0.4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(unlocked ? achievement.emoji : '🔒', style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 6),
              Text(achievement.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(achievement.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
