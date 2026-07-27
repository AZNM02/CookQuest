import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

const _orange = Color(0xFFF97316);

class LogSessionScreen extends StatefulWidget {
  const LogSessionScreen({super.key});

  @override
  State<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends State<LogSessionScreen> {
  final _dishCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  String _cuisine = 'asian';
  DateTime _date = DateTime.now();
  int _selfRating = 3;
  int _difficultyFelt = 3;
  final Set<int> _selectedTechIds = {};

  List<Map<String, dynamic>> _techniques = [];
  bool _loadingTech = true;
  bool _submitting = false;
  String? _error;

  static const _cuisines = [
    ('asian', 'Asian'),
    ('western', 'Western'),
    ('mediterranean', 'Mediterranean'),
    ('middle_eastern', 'Middle Eastern'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTechniques();
  }

  @override
  void dispose() {
    _dishCtrl.dispose();
    _notesCtrl.dispose();
    _timeCtrl.dispose();
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

  Future<void> _submit() async {
    if (_dishCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a dish name');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'dish_name': _dishCtrl.text.trim(),
        'cuisine_type': _cuisine,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'self_rating': _selfRating,
        'difficulty_felt': _difficultyFelt,
        'technique_ids': _selectedTechIds.toList(),
      };
      if (_timeCtrl.text.isNotEmpty) {
        final mins = int.tryParse(_timeCtrl.text);
        if (mins != null) body['time_taken_mins'] = mins;
      }
      if (_notesCtrl.text.isNotEmpty) {
        body['notes'] = _notesCtrl.text.trim();
      }
      final result = await ApiService.logSession(body);
      if (mounted) _showResult(result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showResult(Map<String, dynamic> result) {
    final xp = result['xp_earned'] as int;
    final leveledUp = result['leveled_up'] as bool;
    final badges = result['new_badges'] as List<dynamic>;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'Session logged!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+$xp XP',
                style: const TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
            if (leveledUp) ...[
              const SizedBox(height: 8),
              const Text('⬆️ Level Up!',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green)),
            ],
            ...badges.map((b) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${(b as Map)['icon']} ${b['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _reset();
            },
            child:
                const Text('Done', style: TextStyle(color: _orange)),
          ),
        ],
      ),
    );
  }

  void _reset() {
    _dishCtrl.clear();
    _notesCtrl.clear();
    _timeCtrl.clear();
    setState(() {
      _cuisine = 'asian';
      _date = DateTime.now();
      _selfRating = 3;
      _difficultyFelt = 3;
      _selectedTechIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Log Session',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _label('Dish Name'),
              TextField(
                controller: _dishCtrl,
                decoration: _inputDec('e.g. Chicken Stir-fry'),
              ),
              const SizedBox(height: 16),
              _label('Cuisine'),
              DropdownButtonFormField<String>(
                value: _cuisine,
                decoration: _inputDec(''),
                items: _cuisines
                    .map((c) => DropdownMenuItem(
                        value: c.$1, child: Text(c.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _cuisine = v!),
              ),
              const SizedBox(height: 16),
              _label('Date'),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE7E5E4)),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Color(0xFF78716C)),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, yyyy').format(_date),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _label('Self Rating'),
              _StarRow(
                  value: _selfRating,
                  onChanged: (v) => setState(() => _selfRating = v)),
              const SizedBox(height: 16),
              _label('Difficulty Felt'),
              _StarRow(
                  value: _difficultyFelt,
                  onChanged: (v) => setState(() => _difficultyFelt = v)),
              const SizedBox(height: 16),
              _label('Techniques Used'),
              if (_loadingTech)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: _orange, strokeWidth: 2)),
                )
              else
                _buildTechChips(),
              const SizedBox(height: 16),
              _label('Time Taken (minutes, optional)'),
              TextField(
                controller: _timeCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDec('e.g. 45'),
              ),
              const SizedBox(height: 16),
              _label('Notes (optional)'),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: _inputDec('How did it go?'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFDC2626), fontSize: 13)),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Log Session',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: _orange),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _buildTechChips() {
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final t in _techniques) {
      final cat = t['category'] as String? ?? 'Other';
      byCategory.putIfAbsent(cat, () => []).add(t);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: byCategory.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                entry.key,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78716C)),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.value.map((t) {
                final id = t['id'] as int;
                final selected = _selectedTechIds.contains(id);
                return FilterChip(
                  label: Text(
                    t['name'] as String,
                    style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF44403C)),
                  ),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedTechIds.add(id);
                    } else {
                      _selectedTechIds.remove(id);
                    }
                  }),
                  backgroundColor: Colors.white,
                  selectedColor: _orange,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                      color: selected
                          ? _orange
                          : const Color(0xFFE7E5E4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF44403C)),
        ),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFA8A29E), fontSize: 13),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E5E4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _orange),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

class _StarRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _StarRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (i) => GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              i < value ? Icons.star : Icons.star_border,
              color: _orange,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
