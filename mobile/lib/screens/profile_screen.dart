import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

const _orange = Color(0xFFF97316);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _dashboard;
  List<dynamic> _badges = [];
  List<dynamic> _sessions = [];
  List<Map<String, dynamic>> _xpOverTime = [];
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
      final results = await Future.wait([
        ApiService.getDashboard(),
        ApiService.getCharts(),
        ApiService.getBadges(),
        ApiService.getSessions(limit: 100),
      ]);
      if (mounted) {
        setState(() {
          _dashboard = results[0] as Map<String, dynamic>;
          final charts = results[1] as Map<String, dynamic>;
          _xpOverTime = (charts['xp_over_time'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          _badges = results[2] as List<dynamic>;
          _sessions = results[3] as List<dynamic>;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceAll('Exception: ', ''));
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
              ? const Center(
                  child: CircularProgressIndicator(color: _orange))
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 12),
            TextButton(
                onPressed: _load,
                child: const Text('Retry',
                    style: TextStyle(color: _orange))),
          ],
        ),
      ),
    ]);
  }

  Widget _buildContent() {
    final dash = _dashboard!;
    final profile = dash['profile'] as Map<String, dynamic>;
    final stats = dash['stats'] as Map<String, dynamic>;
    final xpProgress = dash['xp_progress'] as Map<String, dynamic>;

    final level = xpProgress['level'] as int;
    final currentXp = xpProgress['current_xp'] as int;
    final xpForLevel = xpProgress['xp_for_current_level'] as int;
    final xpForNext = xpProgress['xp_for_next_level'] as int;
    final xpInLevel = currentXp - xpForLevel;
    final xpNeeded = xpForNext - xpForLevel;
    final progress =
        xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 0.0;

    final streak = profile['streak_count'] as int? ?? 0;
    final longestStreak = (profile['longest_streak'] as int?) ??
        (stats['longest_streak'] as int?) ??
        0;
    final displayName = profile['display_name'] as String?;
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? '';
    final username =
        profile['username'] as String? ?? email.split('@').first;
    final createdAt = profile['created_at'] as String? ?? '';
    final joined = _fmtJoined(createdAt);
    final name =
        displayName?.isNotEmpty == true ? displayName! : username;

    final totalSessions = stats['total_sessions'] as int? ?? 0;
    final uniqueTechniques = stats['unique_techniques'] as int? ?? 0;
    final cuisineCount = stats['cuisine_count'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Page title
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text('Your cooking journey at a glance.',
                style:
                    TextStyle(fontSize: 13, color: Color(0xFF78716C))),
          ],
        ),
        const SizedBox(height: 16),

        // ── Header card ─────────────────────────────────────
        _card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1C1917))),
                    const SizedBox(height: 2),
                    Text(
                      '@$username${joined.isNotEmpty ? ' · Joined $joined' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF78716C)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Level $level',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF44403C))),
                        Text(
                          '$xpInLevel / $xpNeeded XP to next level',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF78716C)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFF5F5F4),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                _orange),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$currentXp total XP',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF78716C))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _confirmSignOut,
                    child: const Icon(Icons.logout,
                        color: Color(0xFF78716C), size: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '🔥 $streak',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _orange),
                  ),
                  const Text('day streak',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF78716C))),
                  const SizedBox(height: 4),
                  Text('Best: $longestStreak days',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF78716C))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Stats row (4 columns, matches web) ──────────────
        Row(
          children: [
            Expanded(child: _StatCard('🍳', '$totalSessions', 'Sessions\nCooked')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard('🔪', '$uniqueTechniques', 'Techniques\nUsed')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard('🌍', '$cuisineCount', 'Cuisines\nExplored')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard('🏆', '${longestStreak}d', 'Longest\nStreak')),
          ],
        ),
        const SizedBox(height: 12),

        // ── XP Over Time chart ──────────────────────────────
        if (_xpOverTime.length > 1) ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('XP Over Time',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: _XpChart(points: _xpOverTime),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Badges ──────────────────────────────────────────
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('Badges',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (_badges.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFDBA74)),
                    ),
                    child: Text('${_badges.length} earned',
                        style: const TextStyle(
                            fontSize: 11,
                            color: _orange,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
              if (_badges.isEmpty)
                const Text(
                  'No badges yet — keep cooking to unlock them!',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF78716C)),
                )
              else
                Column(
                  children: _badges
                      .map((b) => _BadgeTile(
                          badge: b as Map<String, dynamic>))
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Session History ──────────────────────────────────
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('Session History',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('${_sessions.length} sessions',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF78716C))),
              ]),
              const SizedBox(height: 12),
              if (_sessions.isEmpty)
                const Text(
                  'No sessions yet — log your first cook!',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF78716C)),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < _sessions.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 1, color: Color(0xFFF5F5F4)),
                      _SessionRow(
                          session:
                              _sessions[i] as Map<String, dynamic>),
                    ],
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E5E4)),
        ),
        child: child,
      );

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Supabase.instance.client.auth.signOut();
            },
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(RegExp(r'[\s_@.]+'));
    if (parts.length >= 2 &&
        parts[0].isNotEmpty &&
        parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }

  String _fmtJoined(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _StatCard(this.emoji, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1917))),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF78716C))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Badge tile
// ─────────────────────────────────────────────────────────────

class _BadgeTile extends StatelessWidget {
  final Map<String, dynamic> badge;
  const _BadgeTile({required this.badge});

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso.split('T')[0]);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = badge['name'] as String? ?? '';
    final icon = badge['icon'] as String? ?? '🏅';
    final description = badge['description'] as String? ?? '';
    final earnedAt = badge['earned_at'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1917))),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF78716C))),
                ],
                if (earnedAt.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_fmtDate(earnedAt),
                      style: const TextStyle(
                          fontSize: 11, color: _orange)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Session row
// ─────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionRow({required this.session});

  static const _cuisineLabels = {
    'asian': 'Asian',
    'western': 'Western',
    'mediterranean': 'Mediterranean',
    'middle_eastern': 'Middle Eastern',
    'other': 'Other',
  };

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dishName = session['dish_name'] as String? ?? '';
    final cuisineRaw = session['cuisine_type'] as String? ?? '';
    final cuisineLabel = _cuisineLabels[cuisineRaw] ?? cuisineRaw;
    final date = _fmtDate(session['date'] as String?);
    final rating = session['self_rating'] as int? ?? 0;
    final xpEarned = session['xp_earned'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dishName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1C1917))),
                const SizedBox(height: 2),
                Text('$cuisineLabel · $date',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF78716C))),
              ],
            ),
          ),
          Row(children: [
            Text(
              '${'★' * rating}${'☆' * (5 - rating)}',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFFEAB308)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Text('+$xpEarned XP',
                  style: const TextStyle(
                      fontSize: 11,
                      color: _orange,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// XP chart (custom painter — no extra package)
// ─────────────────────────────────────────────────────────────

class _XpChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  const _XpChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _XpChartPainter(points: points),
      child: const SizedBox.expand(),
    );
  }
}

class _XpChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  _XpChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final xpValues =
        points.map((p) => (p['xp'] as num).toDouble()).toList();
    final minXp = xpValues.reduce(min);
    final maxXp = xpValues.reduce(max);
    final xpRange = (maxXp - minXp).clamp(1.0, double.infinity);

    const leftPad = 44.0;
    const bottomPad = 24.0;
    final w = size.width - leftPad;
    final h = size.height - bottomPad;

    double tx(int i) => leftPad + (i / (points.length - 1)) * w;
    double ty(double xp) =>
        h * 0.92 - ((xp - minXp) / xpRange) * h * 0.82;

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = h * i / 3;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
    }

    // Area fill
    final areaPath = Path()
      ..moveTo(tx(0), ty(xpValues[0]));
    for (int i = 1; i < points.length; i++) {
      areaPath.lineTo(tx(i), ty(xpValues[i]));
    }
    areaPath
      ..lineTo(tx(points.length - 1), h)
      ..lineTo(tx(0), h)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF97316).withOpacity(0.22),
            const Color(0xFFF97316).withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final linePath = Path()..moveTo(tx(0), ty(xpValues[0]));
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(tx(i), ty(xpValues[i]));
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = _orange
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final labelStyle =
        TextStyle(fontSize: 10, color: Colors.grey.shade400);

    // Y-axis labels
    for (int i = 0; i <= 2; i++) {
      final xp = minXp + xpRange * i / 2;
      final y = ty(xp);
      final tp = TextPainter(
        text: TextSpan(
            text: xp >= 1000
                ? '${(xp / 1000).toStringAsFixed(1)}k'
                : xp.toStringAsFixed(0),
            style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // X-axis date labels
    for (final i in _sampleIndices(points.length, 4)) {
      final label =
          _fmtShort(points[i]['date'] as String? ?? '');
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(tx(i) - tp.width / 2, size.height - tp.height));
    }
  }

  List<int> _sampleIndices(int len, int maxLabels) {
    if (len <= maxLabels) return List.generate(len, (i) => i);
    return List.generate(maxLabels,
        (i) => (i * (len - 1) / (maxLabels - 1)).round());
  }

  String _fmtShort(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  bool shouldRepaint(_XpChartPainter old) => old.points != points;
}
