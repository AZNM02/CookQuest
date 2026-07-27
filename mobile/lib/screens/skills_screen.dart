import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _orange = Color(0xFFF97316);

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  List<dynamic> _techniques = [];
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
      final data = await ApiService.getProficiency();
      if (mounted) setState(() => _techniques = data);
    } catch (e) {
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
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _orange,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _orange))
              : _error != null
                  ? ListView(children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 40),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32),
                              child: Text(_error!,
                                  textAlign: TextAlign.center,
                                  style:
                                      const TextStyle(color: Colors.red)),
                            ),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Retry',
                                    style: TextStyle(color: _orange))),
                          ],
                        ),
                      ),
                    ])
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final t in _techniques) {
      final tech = t as Map<String, dynamic>;
      final cat = tech['category'] as String? ?? 'Other';
      byCategory.putIfAbsent(cat, () => []).add(tech);
    }

    final practiced = _techniques
        .where((t) => ((t as Map)['times_used'] as int? ?? 0) > 0)
        .length;
    final total = _techniques.length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Skills',
            style:
                TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          '$practiced / $total techniques practised',
          style: const TextStyle(
              color: Color(0xFF78716C), fontSize: 13),
        ),
        const SizedBox(height: 20),
        ...byCategory.entries.expand((entry) => [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 10),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF44403C)),
                ),
              ),
              ...entry.value
                  .map((t) => _TechniqueBar(technique: t)),
            ]),
      ],
    );
  }
}

class _TechniqueBar extends StatelessWidget {
  final Map<String, dynamic> technique;
  const _TechniqueBar({required this.technique});

  @override
  Widget build(BuildContext context) {
    final score =
        (technique['proficiency_score'] as num?)?.toDouble() ?? 0.0;
    final timesUsed = technique['times_used'] as int? ?? 0;
    final avgRating =
        (technique['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final clamped = score.clamp(0.0, 1.0);

    final (Color barColor, String levelLabel) = switch (true) {
      _ when score == 0 => (const Color(0xFFE7E5E4), 'Not tried'),
      _ when score < 0.3 => (const Color(0xFFFCA5A5), 'Beginner'),
      _ when score < 0.6 => (const Color(0xFFFBBF24), 'Developing'),
      _ when score < 0.8 => (_orange, 'Proficient'),
      _ => (const Color(0xFF22C55E), 'Expert'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  technique['name'] as String,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  levelLabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: barColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clamped,
              backgroundColor: const Color(0xFFF5F5F4),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
          if (timesUsed > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$timesUsed use${timesUsed != 1 ? 's' : ''} · avg ${avgRating.toStringAsFixed(1)} ★',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF78716C)),
            ),
          ],
        ],
      ),
    );
  }
}
