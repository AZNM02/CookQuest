import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _orange = Color(0xFFF97316);

const _catColors = <String, Color>{
  'knife_skills': Color(0xFFF97316),
  'heat_control': Color(0xFFEF4444),
  'sauces': Color(0xFF8B5CF6),
  'baking': Color(0xFFF59E0B),
  'prep': Color(0xFF10B981),
};

const _catLabels = <String, String>{
  'knife_skills': 'Knife Skills',
  'heat_control': 'Heat Control',
  'sauces': 'Sauces',
  'baking': 'Baking',
  'prep': 'Prep',
};

const _cuisineLabels = <String, String>{
  'asian': 'Asian',
  'western': 'Western',
  'mediterranean': 'Mediterranean',
  'middle_eastern': 'Middle Eastern',
  'other': 'Other',
};

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// ── Screen ──────────────────────────────────────────────────────────────────

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  List<dynamic> _techniques = [];
  Map<String, dynamic>? _charts;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ApiService.getProficiency(),
        ApiService.getCharts(),
      ]);
      if (mounted) {
        final charts = results[1] as Map<String, dynamic>;
        // Debug: shows what the API actually returns so we can spot type/key issues.
        debugPrint('[Skills] charts keys: ${charts.keys.toList()}');
        debugPrint('[Skills] cuisine_radar: ${charts['cuisine_radar']}');
        final hm = charts['heatmap'] as List?;
        debugPrint('[Skills] heatmap length: ${hm?.length}, '
            'first entry: ${hm?.isNotEmpty == true ? hm!.first : "empty"}');
        setState(() {
          _techniques = results[0] as List<dynamic>;
          _charts = charts;
        });
      }
    } catch (e) {
      debugPrint('[Skills] load error: $e');
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F4),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _orange,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _orange))
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return ListView(children: [
      const SizedBox(height: 100),
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ),
          TextButton(
              onPressed: _load,
              child: const Text('Retry', style: TextStyle(color: _orange))),
        ]),
      ),
    ]);
  }

  Widget _buildContent() {
    final tried =
        _techniques.where((t) => ((t as Map)['times_used'] as int? ?? 0) > 0).length;
    final total = _techniques.length;

    // Top 15 practiced techniques, strongest first
    final practiced = _techniques
        .where((t) => ((t as Map)['times_used'] as int? ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final sa = ((a as Map)['proficiency_score'] as num? ?? 0).toDouble();
        final sb = ((b as Map)['proficiency_score'] as num? ?? 0).toDouble();
        return sb.compareTo(sa);
      });
    final top15 = practiced.take(15).toList();

    // All techniques, weakest first
    final allSorted = [..._techniques]
      ..sort((a, b) {
        final sa = ((a as Map)['proficiency_score'] as num? ?? 0).toDouble();
        final sb = ((b as Map)['proficiency_score'] as num? ?? 0).toDouble();
        return sa.compareTo(sb);
      });

    final cuisineRadar = (_charts?['cuisine_radar'] as List<dynamic>?) ?? [];
    final heatmap = (_charts?['heatmap'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        const Text('Skills',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('$tried of $total techniques tried',
            style: const TextStyle(color: Color(0xFF78716C), fontSize: 13)),
        const SizedBox(height: 20),

        // ── Proficiency by Technique ─────────────────────────────────────────
        _SectionCard(
          title: 'Proficiency by Technique',
          child: top15.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Log sessions to see your proficiency chart.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...top15.map(
                        (t) => _ProficiencyRow(technique: t as Map<String, dynamic>)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: _catColors.entries.map((e) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: e.value,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(_catLabels[e.key] ?? e.key,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF6B7280))),
                        ],
                      )).toList(),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),

        // ── Cuisine Diversity ────────────────────────────────────────────────
        _SectionCard(
          title: 'Cuisine Diversity',
          child: cuisineRadar.isEmpty ||
                  cuisineRadar.every(
                      (d) => ((d as Map)['count'] as num? ?? 0).toInt() == 0)
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Cook different cuisines to see this chart.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        textAlign: TextAlign.center),
                  ),
                )
              : _RadarChart(data: cuisineRadar),
        ),
        const SizedBox(height: 16),

        // ── Cooking Activity ─────────────────────────────────────────────────
        _SectionCard(
          title: 'Cooking Activity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CookingHeatmap(data: heatmap),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Less',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                const SizedBox(width: 4),
                ...[
                  const Color(0xFFF3F4F6),
                  const Color(0xFFFED7AA),
                  const Color(0xFFFB923C),
                  const Color(0xFFEA580C),
                ].map((c) => Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                          color: c, borderRadius: BorderRadius.circular(2)),
                    )),
                const Text('More',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── All Techniques ───────────────────────────────────────────────────
        _SectionCard(
          title: 'All Techniques',
          subtitle: '— weakest first',
          child: Column(
            children: allSorted
                .map((t) => _TechniqueRow(technique: t as Map<String, dynamic>))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937))),
            if (subtitle != null) ...[
              const SizedBox(width: 6),
              Text(subtitle!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            ],
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Proficiency bar chart row ─────────────────────────────────────────────────

class _ProficiencyRow extends StatelessWidget {
  final Map<String, dynamic> technique;
  const _ProficiencyRow({required this.technique});

  @override
  Widget build(BuildContext context) {
    final name = technique['name']?.toString() ?? '';
    final score = (technique['proficiency_score'] as num?)?.toDouble() ?? 0.0;
    final cat = technique['category'] as String? ?? '';
    final color = _catColors[cat] ?? const Color(0xFF94A3B8);
    final displayName = name.length > 14 ? '${name.substring(0, 13)}…' : name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(displayName,
                style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (score / 100).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(score.toStringAsFixed(0),
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ── Cuisine radar chart ───────────────────────────────────────────────────────

class _RadarChart extends StatelessWidget {
  final List<dynamic> data;
  const _RadarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final points = data.map((d) {
      final map = d as Map<String, dynamic>;
      return {
        'label': _cuisineLabels[map['cuisine'] as String? ?? ''] ??
            (map['cuisine']?.toString() ?? ''),
        'value': ((map['count'] as num?) ?? 0).toDouble(),
      };
    }).toList();

    return SizedBox(
      height: 220,
      child: CustomPaint(
        painter: _RadarPainter(points: points),
        size: Size.infinite,
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  _RadarPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final n = points.length;
    if (n == 0) return;

    final maxVal = points
        .map((p) => p['value'] as double)
        .fold(0.0, (a, b) => a > b ? a : b);
    final radius = min(cx - 44, cy - 28);

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), radius * i / 4, gridPaint);
    }
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + 2 * pi * i / n;
      canvas.drawLine(Offset(cx, cy),
          Offset(cx + radius * cos(angle), cy + radius * sin(angle)), gridPaint);
    }

    if (maxVal > 0) {
      final fillPaint = Paint()
        ..color = _orange.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = _orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final path = Path();
      for (int i = 0; i < n; i++) {
        final angle = -pi / 2 + 2 * pi * i / n;
        final v = (points[i]['value'] as double) / maxVal;
        final x = cx + radius * v * cos(angle);
        final y = cy + radius * v * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }

    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + 2 * pi * i / n;
      final lx = cx + (radius + 26) * cos(angle);
      final ly = cy + (radius + 26) * sin(angle);
      final tp = TextPainter(
        text: TextSpan(
          text: points[i]['label'] as String,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.points != points;
}

// ── Cooking activity heatmap ──────────────────────────────────────────────────

Color _heatColor(int count) {
  if (count == 0) return const Color(0xFFF3F4F6);
  if (count == 1) return const Color(0xFFFED7AA);
  if (count == 2) return const Color(0xFFFB923C);
  return const Color(0xFFEA580C);
}

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

class _CookingHeatmap extends StatelessWidget {
  final List<dynamic> data;
  const _CookingHeatmap({required this.data});

  @override
  Widget build(BuildContext context) {
    final countMap = <String, int>{};
    for (final d in data) {
      final map = d as Map<String, dynamic>;
      // Supabase may return dates as full timestamps ("2026-07-25T00:00:00+00:00");
      // take only the first 10 chars so the key always matches "YYYY-MM-DD".
      final raw = map['date']?.toString() ?? '';
      final dateKey = raw.length >= 10 ? raw.substring(0, 10) : raw;
      countMap[dateKey] = (map['count'] as num?)?.toInt() ?? 0;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Dart weekday: Mon=1…Sun=7. weekday%7 → Sun=0, Mon=1…Sat=6 (same as JS).
    // Snap rangeStart to the preceding Sunday.
    var rangeStart = today.subtract(const Duration(days: 364));
    rangeStart = rangeStart.subtract(Duration(days: rangeStart.weekday % 7));

    // Pad rangeEnd to Saturday of today's week.
    final daysToSat = (6 - today.weekday % 7 + 7) % 7;
    final rangeEnd = today.add(Duration(days: daysToSat));

    final cells = <Map<String, dynamic>>[];
    var cursor = rangeStart;
    while (!cursor.isAfter(rangeEnd)) {
      final iso =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      cells.add({
        'date': iso,
        'count': countMap[iso] ?? 0,
        'isFuture': cursor.isAfter(today),
        'day': cursor.day,
        'month': cursor.month,
        'year': cursor.year,
      });
      cursor = cursor.add(const Duration(days: 1));
    }

    // Split into 7-day week columns.
    final weeks = <List<Map<String, dynamic>>>[];
    for (int i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, min(i + 7, cells.length)));
    }

    // Month labels: skip partial first month, enforce ≥3 column gap.
    final monthLabels = <Map<String, dynamic>>[];
    int prevMonth = -1;
    int prevLabelCol = -100;

    for (int wi = 0; wi < weeks.length; wi++) {
      final week = weeks[wi];
      final firstReal = week.where((c) => !(c['isFuture'] as bool));
      if (firstReal.isEmpty) continue;
      final first = firstReal.first;
      final month = (first['month'] as int) - 1;
      final dom = first['day'] as int;
      if (month == prevMonth) continue;

      if (wi == 0 && dom > 1) {
        prevMonth = month;
      } else if (wi - prevLabelCol >= 3) {
        monthLabels.add({'label': _monthsShort[month], 'col': wi});
        prevMonth = month;
        prevLabelCol = wi;
      } else {
        prevMonth = month;
      }
    }

    const cellSize = 12.0;
    const gap = 2.0;
    const stride = cellSize + gap;
    const dayLabels = <String?>[null, 'Mon', null, 'Wed', null, 'Fri', null];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed Mon/Wed/Fri labels
        Padding(
          padding: const EdgeInsets.only(top: 16, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: dayLabels
                .map((label) => SizedBox(
                      height: cellSize + gap,
                      child: label != null
                          ? Text(label,
                              style: const TextStyle(
                                  fontSize: 9, color: Color(0xFF9CA3AF)))
                          : null,
                    ))
                .toList(),
          ),
        ),
        // Scrollable month row + grid
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month label row
                SizedBox(
                  height: 14,
                  width: weeks.length * stride,
                  child: Stack(
                    children: monthLabels
                        .map((ml) => Positioned(
                              left: (ml['col'] as int) * stride,
                              child: Text(
                                ml['label'] as String,
                                style: const TextStyle(
                                    fontSize: 9, color: Color(0xFF9CA3AF)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 2),
                // Grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: weeks.map((week) {
                    return Column(
                      children: week.map((cell) {
                        final isFuture = cell['isFuture'] as bool;
                        final count = cell['count'] as int;
                        final day = cell['day'] as int;
                        final month = cell['month'] as int;
                        final year = cell['year'] as int;

                        final box = Container(
                          width: cellSize,
                          height: cellSize,
                          margin: const EdgeInsets.only(bottom: gap, right: gap),
                          decoration: BoxDecoration(
                            color: isFuture ? Colors.transparent : _heatColor(count),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );

                        if (isFuture) return box;

                        final tipText = count == 0
                            ? 'No sessions on ${_monthsLong[month - 1]} ${_ordinal(day)}, $year'
                            : '$count session${count != 1 ? 's' : ''} on ${_monthsLong[month - 1]} ${_ordinal(day)}, $year';

                        return Tooltip(
                          message: tipText,
                          preferBelow: false,
                          child: box,
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Technique list row ────────────────────────────────────────────────────────

class _TechniqueRow extends StatelessWidget {
  final Map<String, dynamic> technique;
  const _TechniqueRow({required this.technique});

  @override
  Widget build(BuildContext context) {
    final name = technique['name']?.toString() ?? '';
    final score = (technique['proficiency_score'] as num?)?.toDouble() ?? 0.0;
    final timesUsed = technique['times_used'] as int? ?? 0;
    final cat = technique['category'] as String? ?? '';
    final color = _catColors[cat] ?? const Color(0xFF94A3B8);

    final (Color badgeBg, Color badgeFg) = switch (true) {
      _ when score == 0 => (const Color(0xFFF3F4F6), const Color(0xFF9CA3AF)),
      _ when score < 30 => (const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
      _ when score < 60 => (const Color(0xFFFEF9C3), const Color(0xFFCA8A04)),
      _ => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937))),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat.replaceAll('_', ' '),
                      style: TextStyle(fontSize: 10, color: color),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (score / 100).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFFFB923C)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      score > 0 ? score.toStringAsFixed(0) : '—',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              timesUsed == 0 ? 'New' : '×$timesUsed',
              style: TextStyle(
                  fontSize: 11, color: badgeFg, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
