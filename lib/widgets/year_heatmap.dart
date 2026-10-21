import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/gamification.dart';

/// GitHub-style calendar: one square per day for the last 53 weeks,
/// darker = more words answered (full colour = daily goal reached).
class YearHeatmap extends StatelessWidget {
  const YearHeatmap({super.key, required this.daily, required this.goal});
  final Map<String, int> daily;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final theme = Theme.of(context);
    final base = theme.colorScheme.primary;
    final empty = theme.colorScheme.outlineVariant.withValues(alpha: 0.35);

    Color colorFor(int n) {
      if (n <= 0) return empty;
      final r = n / goal;
      if (r >= 1) return base;
      if (r >= 0.5) return base.withValues(alpha: 0.65);
      if (r >= 0.25) return base.withValues(alpha: 0.42);
      return base.withValues(alpha: 0.22);
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    // Start on the Monday 52 weeks before this week's Monday.
    final thisMonday = todayDate.subtract(Duration(days: todayDate.weekday - 1));
    final start = thisMonday.subtract(const Duration(days: 52 * 7));
    const cell = 12.0, gap = 3.0;

    var activeDays = 0, total = 0;
    for (final e in daily.entries) {
      if (e.value > 0) {
        activeDays++;
        total += e.value;
      }
    }

    final weeks = <Widget>[];
    for (var w = 0; w < 53; w++) {
      final days = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = start.add(Duration(days: w * 7 + d));
        if (day.isAfter(todayDate)) {
          days.add(const SizedBox(width: cell, height: cell + gap));
          continue;
        }
        final n = daily[dayKey(day)] ?? 0;
        days.add(Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: Tooltip(
            message: '${dayKey(day)}: $n',
            child: Container(
              width: cell,
              height: cell,
              decoration: BoxDecoration(
                color: colorFor(n),
                borderRadius: BorderRadius.circular(3),
                border: day == todayDate ? Border.all(color: theme.colorScheme.onSurface, width: 1) : null,
              ),
            ),
          ),
        ));
      }
      weeks.add(Padding(padding: const EdgeInsets.only(right: gap), child: Column(children: days)));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // newest weeks visible first
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: weeks),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Text(t.yearSummary(activeDays, total), style: theme.textTheme.bodySmall),
        const Spacer(),
        Text(t.less, style: theme.textTheme.labelSmall),
        const SizedBox(width: 4),
        for (final n in [0, 1, (goal * 0.3).ceil(), (goal * 0.6).ceil(), goal])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: colorFor(n), borderRadius: BorderRadius.circular(2)),
            ),
          ),
        const SizedBox(width: 4),
        Text(t.more, style: theme.textTheme.labelSmall),
      ]),
    ]);
  }
}
