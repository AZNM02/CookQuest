import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _orange = Color(0xFFF97316);

const _steps = ['Dish', 'Techniques', 'Rating', 'Details'];

const _cuisines = [
  ('asian', 'Asian'),
  ('western', 'Western'),
  ('mediterranean', 'Mediterranean'),
  ('middle_eastern', 'Middle Eastern'),
  ('other', 'Other'),
];

const _catLabels = {
  'knife_skills': 'Knife Skills',
  'heat_control': 'Heat Control',
  'sauces': 'Sauces',
  'baking': 'Baking',
  'prep': 'Prep',
};

const _tierStyle = {
  'beginner': (Color(0xFFF0FDF4), Color(0xFF16A34A)),
  'intermediate': (Color(0xFFFEFCE8), Color(0xFFCA8A04)),
  'advanced': (Color(0xFFFFF1F2), Color(0xFFDC2626)),
};

const _ratingLabels = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];

class LogSessionScreen extends StatefulWidget {
  const LogSessionScreen({super.key});

  @override
  State<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends State<LogSessionScreen> {
  int _step = 0;

  // Step 0
  final _dishCtrl = TextEditingController();
  String _cuisine = '';

  // Step 1
  List<Map<String, dynamic>> _techniques = [];
  bool _loadingTech = true;
  final _searchCtrl = TextEditingController();
  String _techSearch = '';
  final Set<int> _selectedTechIds = {};

  // Step 2
  int _selfRating = 0;
  int _difficultyFelt = 0;

  // Step 3
  final _timeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadTechniques();
    _searchCtrl.addListener(
        () => setState(() => _techSearch = _searchCtrl.text));
  }

  @override
  void dispose() {
    _dishCtrl.dispose();
    _searchCtrl.dispose();
    _timeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTechniques() async {
    try {
      final data = await ApiService.getTechniques();
      if (mounted) {
        setState(() {
          _techniques = data.cast<Map<String, dynamic>>();
          _loadingTech = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTech = false);
    }
  }

  bool get _canAdvance {
    return switch (_step) {
      0 => _dishCtrl.text.trim().isNotEmpty && _cuisine.isNotEmpty,
      1 => true,
      2 => _selfRating > 0 && _difficultyFelt > 0,
      _ => true,
    };
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'dish_name': _dishCtrl.text.trim(),
        'cuisine_type': _cuisine,
        'technique_ids': _selectedTechIds.toList(),
        'self_rating': _selfRating,
        'difficulty_felt': _difficultyFelt,
      };
      if (_timeCtrl.text.isNotEmpty) {
        final mins = int.tryParse(_timeCtrl.text);
        if (mins != null) body['time_taken_mins'] = mins;
      }
      if (_notesCtrl.text.isNotEmpty) {
        body['notes'] = _notesCtrl.text.trim();
      }
      final result = await ApiService.logSession(body);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    _dishCtrl.clear();
    _searchCtrl.clear();
    _timeCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _step = 0;
      _cuisine = '';
      _techSearch = '';
      _selectedTechIds.clear();
      _selfRating = 0;
      _difficultyFelt = 0;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F4),
      body: SafeArea(
        child:
            _result != null ? _buildSuccess() : _buildWizard(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Success screen
  // ─────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    final r = _result!;
    final xpEarned = (r['xp_earned'] as int?) ?? 0;
    final leveledUp = (r['leveled_up'] as bool?) ?? false;
    final newLevel = (r['new_level'] as int?) ?? 0;
    final streakCount = (r['streak_count'] as int?) ?? 0;
    final newTotalXp = (r['new_total_xp'] as int?) ?? 0;
    final newBadges = (r['new_badges'] as List<dynamic>?) ?? [];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E5E4)),
          ),
          child: Column(
            children: [
              const Text('🎉',
                  style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              const Text('Session logged!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1917))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text('+$xpEarned XP',
                    style: const TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
              ),
              if (leveledUp) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⭐ Level up! You are now Level $newLevel',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              ],
              if (streakCount > 1) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🔥 $streakCount-day streak!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              ],
              if (newBadges.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...newBadges.map((b) {
                  final badge = b as Map<String, dynamic>;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFCE8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Text(badge['icon'] as String? ?? '🏅',
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                badge['name'] as String? ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                    fontSize: 13),
                              ),
                              if ((badge['description'] as String?)
                                      ?.isNotEmpty ==
                                  true)
                                Text(
                                  badge['description']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB45309)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 8),
              Text('Total XP: $newTotalXp',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF78716C))),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Color(0xFFE7E5E4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Log another',
                    style: TextStyle(
                        color: Color(0xFF44403C), fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Wizard
  // ─────────────────────────────────────────────────────────

  Widget _buildWizard() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Log a Session',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _StepIndicator(
                    currentStep: _step, steps: _steps),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: const Color(0xFFE7E5E4)),
                  ),
                  child: switch (_step) {
                    0 => _buildStepDish(),
                    1 => _buildStepTechniques(),
                    2 => _buildStepRating(),
                    _ => _buildStepDetails(),
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom nav
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
                top: BorderSide(color: Color(0xFFE7E5E4))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _step > 0
                  ? OutlinedButton(
                      onPressed: () => setState(() {
                        _step--;
                        _error = null;
                      }),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFE7E5E4)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: const Text('← Back',
                          style: TextStyle(
                              color: Color(0xFF44403C),
                              fontSize: 13)),
                    )
                  : const SizedBox(),
              _step < _steps.length - 1
                  ? FilledButton(
                      onPressed: _canAdvance
                          ? () => setState(() {
                                _step++;
                                _error = null;
                              })
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
                        disabledBackgroundColor:
                            _orange.withOpacity(0.45),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: const Text('Next →',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    )
                  : FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                          : const Text('Log Session ✓',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600)),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Step 0: Dish
  // ─────────────────────────────────────────────────────────

  Widget _buildStepDish() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What did you cook?',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextField(
          controller: _dishCtrl,
          autofocus: true,
          decoration: _inputDec('e.g. Chicken Stir-fry'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        const Text('Cuisine type',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cuisines.map((c) {
            final selected = _cuisine == c.$1;
            return GestureDetector(
              onTap: () =>
                  setState(() => _cuisine = c.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFF7ED)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFB923C)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Text(c.$2,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? const Color(0xFFC2410C)
                            : const Color(0xFF6B7280))),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Step 1: Techniques
  // ─────────────────────────────────────────────────────────

  Widget _buildStepTechniques() {
    final filtered = _techniques.where((t) {
      final name = t['name'];
      if (name == null) return true;
      return name.toString().toLowerCase()
          .contains(_techSearch.toLowerCase());
    }).toList();

    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final t in filtered) {
      final cat = t['category'] as String? ?? 'other';
      byCategory.putIfAbsent(cat, () => []).add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('Which techniques did you use?',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151))),
            ),
            if (_selectedTechIds.isNotEmpty)
              Text('${_selectedTechIds.length} selected',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _orange,
                      fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchCtrl,
          decoration: _inputDec('Search techniques…'),
        ),
        const SizedBox(height: 12),
        if (_loadingTech)
          const Center(
              child: CircularProgressIndicator(
                  color: _orange, strokeWidth: 2))
        else if (byCategory.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No techniques match your search.',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF9CA3AF))),
            ),
          )
        else
          SizedBox(
            height: 300,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: byCategory.entries.map((entry) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 12, bottom: 6),
                        child: Text(
                          (_catLabels[entry.key] ?? entry.key)
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 0.8),
                        ),
                      ),
                      ...entry.value.map((t) {
                        final id = (t['id'] as int?) ?? -1;
                        final selected =
                            _selectedTechIds.contains(id);
                        final tier =
                            t['difficulty_tier'] as String? ??
                                'beginner';
                        final xpReward =
                            t['xp_reward'] as int? ?? 0;
                        final tc = _tierStyle[tier] ??
                            const (
                              Color(0xFFF0FDF4),
                              Color(0xFF16A34A)
                            );

                        return GestureDetector(
                          onTap: () => setState(() {
                            selected
                                ? _selectedTechIds.remove(id)
                                : _selectedTechIds.add(id);
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(
                                bottom: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFFFF7ED)
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: selected,
                                  onChanged: (_) => setState(
                                      () {
                                    selected
                                        ? _selectedTechIds
                                            .remove(id)
                                        : _selectedTechIds
                                            .add(id);
                                  }),
                                  activeColor: _orange,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,
                                  visualDensity:
                                      VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    t['name']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color:
                                            Color(0xFF1C1917))),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2),
                                decoration: BoxDecoration(
                                  color: tc.$1,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(tier,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: tc.$2,
                                        fontWeight:
                                            FontWeight.w500)),
                              ),
                              const SizedBox(width: 8),
                              Text('+$xpReward XP',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color:
                                          Color(0xFF9CA3AF))),
                            ]),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Step 2: Rating
  // ─────────────────────────────────────────────────────────

  Widget _buildStepRating() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StarRating(
          value: _selfRating,
          label: 'How well did it turn out?',
          onChanged: (v) => setState(() => _selfRating = v),
        ),
        const SizedBox(height: 28),
        _StarRating(
          value: _difficultyFelt,
          label: 'How challenging was it?',
          onChanged: (v) =>
              setState(() => _difficultyFelt = v),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Step 3: Details
  // ─────────────────────────────────────────────────────────

  Widget _buildStepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500),
            children: [
              TextSpan(text: 'Time taken '),
              TextSpan(
                text: '(optional)',
                style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          SizedBox(
            width: 100,
            child: TextField(
              controller: _timeCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDec('45'),
            ),
          ),
          const SizedBox(width: 10),
          const Text('minutes',
              style: TextStyle(
                  fontSize: 14, color: Color(0xFF6B7280))),
        ]),
        const SizedBox(height: 20),
        RichText(
          text: const TextSpan(
            style: TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500),
            children: [
              TextSpan(text: 'Notes '),
              TextSpan(
                text: '(optional)',
                style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 4,
          decoration: _inputDec(
              'What went well? What would you do differently?'),
        ),
      ],
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF), fontSize: 13),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _orange),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

// ─────────────────────────────────────────────────────────────
// Step indicator
// ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> steps;
  const _StepIndicator(
      {required this.currentStep, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: i <= currentStep
                      ? _orange
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                  boxShadow: i == currentStep
                      ? [
                          BoxShadow(
                            color: _orange.withOpacity(0.25),
                            blurRadius: 0,
                            spreadRadius: 5,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: i < currentStep
                      ? const Text('✓',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold))
                      : Text('${i + 1}',
                          style: TextStyle(
                              color: i <= currentStep
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 4),
              Text(steps[i],
                  style: TextStyle(
                      fontSize: 11,
                      color: i == currentStep
                          ? _orange
                          : const Color(0xFF9CA3AF),
                      fontWeight: i == currentStep
                          ? FontWeight.w600
                          : FontWeight.normal)),
            ],
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < currentStep
                    ? const Color(0xFFFB923C)
                    : const Color(0xFFE5E7EB),
              ),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Star rating with hover (works on web/desktop)
// ─────────────────────────────────────────────────────────────

class _StarRating extends StatefulWidget {
  final int value;
  final String label;
  final ValueChanged<int> onChanged;
  const _StarRating(
      {required this.value,
      required this.label,
      required this.onChanged});

  @override
  State<_StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<_StarRating> {
  int _hovered = 0;

  @override
  Widget build(BuildContext context) {
    final display =
        _hovered > 0 ? _hovered : widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final star = i + 1;
            return MouseRegion(
              onEnter: (_) =>
                  setState(() => _hovered = star),
              onExit: (_) =>
                  setState(() => _hovered = 0),
              child: GestureDetector(
                onTap: () => widget.onChanged(star),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '★',
                    style: TextStyle(
                      fontSize: 32,
                      color: star <= display
                          ? const Color(0xFFFB923C)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (widget.value > 0) ...[
          const SizedBox(height: 4),
          Text(_ratingLabels[widget.value],
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF9CA3AF))),
        ],
      ],
    );
  }
}
