import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _orange = Color(0xFFF97316);

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToLog;
  const DashboardScreen({super.key, this.onNavigateToLog});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
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
      final data = await ApiService.getDashboard();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceAll('Exception: ', ''));
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
                  ? _ErrorView(error: _error!, onRetry: _load)
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final xpData = _data!['xp_progress'] as Map<String, dynamic>;
    final stats = _data!['stats'] as Map<String, dynamic>;
    final sessions = _data!['recent_sessions'] as List<dynamic>;
    final profile = _data!['profile'] as Map<String, dynamic>;

    final level = (xpData['level'] as int?) ?? 1;
    final currentXp = (xpData['current_xp'] as int?) ?? 0;
    final xpForLevel = (xpData['xp_for_current_level'] as int?) ?? 0;
    final xpForNext = (xpData['xp_for_next_level'] as int?) ?? 100;
    final xpInLevel = currentXp - xpForLevel;
    final xpNeeded = xpForNext - xpForLevel;
    final progress =
        xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 0.0;
    final streak = profile['streak_count'] as int? ?? 0;
    final longestStreak = (profile['longest_streak'] as int?) ??
        (stats['longest_streak'] as int?) ??
        0;
    final totalSessions = stats['total_sessions'] as int? ?? 0;
    final uniqueTechniques = stats['unique_techniques'] as int? ?? 0;
    final cuisineCount = stats['cuisine_count'] as int? ?? 0;
    final displayName = profile['display_name'] as String?;
    final name =
        displayName?.isNotEmpty == true ? displayName! : 'Chef';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Welcome header ──────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $name! 👋',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1917),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$totalSessions session${totalSessions != 1 ? 's' : ''} logged so far.',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF78716C)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: widget.onNavigateToLog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Log Session',
                  style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── XP / Level card ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7E5E4)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                      border: Border.all(color: _orange, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '$level',
                        style: const TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Level $level',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1917)),
                    ),
                  ),
                  Text(
                    '$currentXp / $xpForNext XP',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1917)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFFF5F5F4),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_orange),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${xpForNext - currentXp} XP to Level ${level + 1}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF78716C)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Stat cards (horizontal scroll) ───────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StatCard('🔥', '$streak', 'Day Streak',
                  'Best: $longestStreak'),
              const SizedBox(width: 10),
              _StatCard(
                  '🍽️', '$totalSessions', 'Sessions', 'all time'),
              const SizedBox(width: 10),
              _StatCard(
                  '🥄', '$uniqueTechniques', 'Techniques', 'used'),
              const SizedBox(width: 10),
              _StatCard('🌍', '$cuisineCount', 'Cuisines', 'explored'),
            ],
          ),
        ),

        // ── Recent Sessions ──────────────────────────────────
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Recent Sessions',
            style:
                TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ...sessions.map((s) =>
              _SessionTile(session: s as Map<String, dynamic>)),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final String sublabel;

  const _StatCard(this.emoji, this.value, this.label, this.sublabel);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF44403C)),
            textAlign: TextAlign.center,
          ),
          Text(
            sublabel,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF78716C)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionTile({required this.session});

  static const _cuisineEmoji = {
    'asian': '🍜',
    'western': '🥩',
    'mediterranean': '🫒',
    'middle_eastern': '🧆',
    'other': '🍽️',
  };

  String _formatCuisine(String raw) {
    return raw
        .split('_')
        .map((w) =>
            w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final rating = session['self_rating'] as int? ?? 0;
    final date = session['date'] as String? ?? '';
    final xpEarned = session['xp_earned'] as int? ?? 0;
    final cuisineRaw =
        session['cuisine_type'] as String? ?? 'other';
    final cuisineLabel = _formatCuisine(cuisineRaw);
    final emoji = _cuisineEmoji[cuisineRaw] ?? '🍽️';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(emoji,
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['dish_name'] as String? ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '$cuisineLabel · $date',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF78716C)),
                ),
              ],
            ),
          ),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star : Icons.star_border,
                size: 14,
                color: _orange,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+$xpEarned XP',
            style: const TextStyle(
              fontSize: 12,
              color: _orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32),
                child: Text(error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 12),
              TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry',
                      style: TextStyle(color: _orange))),
            ],
          ),
        ),
      ],
    );
  }
}
