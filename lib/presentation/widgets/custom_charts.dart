import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';

/// Progress Ring Widget for Stats
class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String value;
  final String label;
  final Color color;
  final double size;
  final IconData? icon;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.value,
    required this.label,
    required this.color,
    this.size = 120,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: size,
      height: size + 50,
      child: Column(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                CustomPaint(
                  size: Size(size, size),
                  painter: _RingPainter(
                    progress: 1.0,
                    color: color.withOpacity(0.1),
                    strokeWidth: 10,
                  ),
                ),
                // Progress ring
                CustomPaint(
                  size: Size(size, size),
                  painter: _RingPainter(
                    progress: progress,
                    color: color,
                    strokeWidth: 10,
                  ),
                ),
                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null)
                      Icon(icon, color: color, size: size * 0.25),
                    if (icon != null) SizedBox(height: size * 0.05),
                    Text(
                      value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Mood Streak Calendar Heatmap
class MoodStreakCalendar extends StatelessWidget {
  final List<DateTime> moodDates;
  final int days;

  const MoodStreakCalendar({
    super.key,
    required this.moodDates,
    this.days = 30,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    
    // Create a Set for quick lookup
    final moodDateSet = moodDates.map((d) => DateUtils.dateOnly(d)).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$days-Day Streak',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: days,
            itemBuilder: (context, index) {
              final date = startDate.add(Duration(days: index));
              final hasLog = moodDateSet.contains(DateUtils.dateOnly(date));
              final isToday = DateUtils.isSameDay(date, now);

              return Container(
                decoration: BoxDecoration(
                  color: hasLog
                      ? theme.colorScheme.tertiary.withOpacity(0.7)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: isToday
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                child: hasLog
                    ? Center(
                        child: Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CalendarLegend(
              color: theme.colorScheme.surfaceContainerHighest,
              label: 'No log',
            ),
            _CalendarLegend(
              color: theme.colorScheme.tertiary.withOpacity(0.7),
              label: 'Logged',
            ),
          ],
        ),
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
      ],
    );
  }
}

/// Mood Trend Line Chart
class MoodTrendChart extends StatelessWidget {
  final List<MoodDataPoint> dataPoints;
  final String period;

  const MoodTrendChart({
    super.key,
    required this.dataPoints,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mood Trend',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                period,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: dataPoints.isEmpty
              ? Center(
                  child: Text(
                    'No data yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                )
              : CustomPaint(
                  painter: _ChartPainter(
                    dataPoints: dataPoints,
                    color: theme.colorScheme.primary,
                  ),
                  child: Container(),
                ),
        ),
      ],
    );
  }
}

class MoodDataPoint {
  final DateTime date;
  final double moodScore; // 1-5

  MoodDataPoint({required this.date, required this.moodScore});
}

class _ChartPainter extends CustomPainter {
  final List<MoodDataPoint> dataPoints;
  final Color color;

  _ChartPainter({required this.dataPoints, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Calculate scaling
    final maxY = 5.0;
    final minY = 1.0;
    final xSpacing = size.width / (dataPoints.length - 1).clamp(1, double.infinity);

    // Build path
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * xSpacing;
      final normalizedY = (dataPoints[i].moodScore - minY) / (maxY - minY);
      final y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw point
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    // Complete fill path
    fillPath.lineTo(dataPoints.length * xSpacing, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints;
}

/// Mood Distribution Donut Chart
class MoodDistributionChart extends StatelessWidget {
  final Map<int, int> distribution; // mood score -> count

  const MoodDistributionChart({
    super.key,
    required this.distribution,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = distribution.values.fold<int>(0, (sum, count) => sum + count);

    final moodColors = {
      5: const Color(0xFF7AC29A), // Great
      4: const Color(0xFF8BC48A), // Good
      3: const Color(0xFFF9C86D), // Okay
      2: const Color(0xFFF4A574), // Bad
      1: const Color(0xFFE07A7A), // Very Bad
    };

    final moodLabels = {
      5: '😊 Great',
      4: '🙂 Good',
      3: '😐 Okay',
      2: '😕 Bad',
      1: '😢 Very Bad',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mood Distribution',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Donut chart
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  distribution: distribution,
                  colors: moodColors,
                  total: total,
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Legend
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: distribution.entries.map((entry) {
                  final score = entry.key;
                  final count = entry.value;
                  final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: moodColors[score],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            moodLabels[score] ?? '',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '$percentage%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: moodColors[score],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<int, int> distribution;
  final Map<int, Color> colors;
  final int total;

  _DonutChartPainter({
    required this.distribution,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.6;

    double startAngle = -math.pi / 2;

    distribution.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    for (final entry in distribution.entries) {
      final score = entry.key;
      final count = entry.value;
      final sweepAngle = (count / total) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[score] ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = (radius - innerRadius);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (radius + innerRadius) / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) => true;
}
