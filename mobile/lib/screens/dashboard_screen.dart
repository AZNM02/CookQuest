import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _orange = Color(0xFFF97316);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _orange,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _orange))
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
    final level = xpData['level'] as int;
    final currentXp = xpData['current_xp'] as int;
    final xpForLevel = xpData['xp_for_current_level'] as int;
    final xpForNext = xpData['xp_for_next_level'] as int;
    final xpInLevel = currentXp - xpForLevel;
    final xpNeeded = xpForNext - xpForLevel;
    final progress =
        xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 0.0;
    final streak =
        (_data!['profile'] as Map<String, dynamic>)['streak_count'] as int? ??
            0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'CookQuest',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1917)),
              ),
            ),
            if (streak > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🔥 $streak day streak',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _XpCard(
          level: level,
          currentXp: currentXp,
          xpInLevel: xpInLevel,
          xpNeeded: xpNeeded,
          progress: progress,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _StatCard('Sessions', '${stats['total_sessions']}',
                Icons.restaurant_outlined),
            _StatCard('Techniques', '${stats['unique_techniques']}',
                Icons.science_outlined),
            _StatCard('Cuisines', '${stats['cuisine_count']}',
                Icons.public_outlined),
            _StatCard('Best Streak', '${stats['longest_streak']} days',
                Icons.local_fire_department_outlined),
          ],
        ),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Recent Sessions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...sessions.map((s) =>
              _SessionTile(session: s as Map<String, dynamic>)),
        ],
      ],
    );
  }
}

class _XpCard extends StatelessWidget {
  final int level;
  final int currentXp;
  final int xpInLevel;
  final int xpNeeded;
  final double progress;

  const _XpCard({
    required this.level,
    required this.currentXp,
    required this.xpInLevel,
    required this.xpNeeded,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _orange.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Lv$level',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level $level',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text('$currentXp XP total',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '$xpInLevel / $xpNeeded XP',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: _orange, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1917))),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF78716C))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final rating = session['self_rating'] as int? ?? 0;
    final date = session['date'] as String? ?? '';
    final xpEarned = session['xp_earned'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['dish_name'] as String? ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(date,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF78716C))),
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
                fontSize: 11,
                color: _orange,
                fontWeight: FontWeight.w600),
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
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
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
