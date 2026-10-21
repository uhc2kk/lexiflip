import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/stats_provider.dart';

/// "📈 Progress" — learned words over the last 30 days, with the total
/// number of words as a dashed ceiling.
class ProgressChartCard extends StatelessWidget {
  const ProgressChartCard({
    super.key,
    required this.deckIds,
    required this.learnedNow,
    required this.total,
  });

  final List<String> deckIds;
  final int learnedNow;
  final int total;

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>();
    final t = S.of(context);
    final theme = Theme.of(context);
    final series = stats.learnedSeries(deckIds, days: 30, today: learnedNow);
    final weekAgo = series[series.length - 8];
    final delta = learnedNow - weekAgo;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('📈 ${t.progress30}', style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(t.thisWeek(delta), style: theme.textTheme.labelMedium),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _LinePainter(
                values: series,
                ceiling: total,
                line: theme.colorScheme.primary,
                fill: theme.colorScheme.primary.withValues(alpha: 0.12),
                grid: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text(t.daysAgo(29), style: theme.textTheme.labelSmall),
            const Spacer(),
            Text('$learnedNow / $total', style: theme.textTheme.labelMedium),
          ]),
        ]),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.ceiling,
    required this.line,
    required this.fill,
    required this.grid,
  });

  final List<int> values;
  final int ceiling;
  final Color line;
  final Color fill;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = [ceiling, ...values].reduce((a, b) => a > b ? a : b).toDouble();
    final top = maxV <= 0 ? 1.0 : maxV;
    double x(int i) => values.length == 1 ? size.width : size.width * i / (values.length - 1);
    double y(num v) => size.height - (v / top) * (size.height - 4) - 2;

    // dashed ceiling (total words)
    final dash = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var dx = 0.0; dx < size.width; dx += 8) {
      canvas.drawLine(Offset(dx, y(ceiling)), Offset((dx + 4).clamp(0, size.width), y(ceiling)), dash);
    }

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    final area = Path.from(path)
      ..lineTo(x(values.length - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(x(values.length - 1), y(values.last)), 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.ceiling != ceiling || old.line != line;
}
