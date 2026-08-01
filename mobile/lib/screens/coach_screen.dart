import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

const _orange = Color(0xFFF97316);

String get _token =>
    Supabase.instance.client.auth.currentSession?.accessToken ?? '';

// ── SSE streaming helper ──────────────────────────────────────────────────────

Future<void> _streamPost(
  String path,
  Map<String, dynamic> body,
  void Function(String) onChunk,
) async {
  final client = http.Client();
  try {
    final request = http.Request('POST', Uri.parse('$apiUrl$path'));
    request.headers['Authorization'] = 'Bearer $_token';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(body);

    final response = await client.send(request);
    if (response.statusCode != 200) {
      final raw = await response.stream.bytesToString();
      Map<String, dynamic>? decoded;
      try { decoded = jsonDecode(raw) as Map<String, dynamic>?; } catch (_) {}
      throw Exception(decoded?['detail'] ?? 'Request failed (${response.statusCode})');
    }

    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final parts = buffer.split('\n');
      buffer = parts.removeLast();
      for (final line in parts) {
        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload == '[DONE]') return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final text = data['text'] as String? ?? '';
          if (text.isNotEmpty) onChunk(text);
        } catch (_) {}
      }
    }
  } finally {
    client.close();
  }
}

// ── Recipe picker ─────────────────────────────────────────────────────────────

class _RecipePicker extends StatefulWidget {
  final Map<String, dynamic>? value;
  final void Function(Map<String, dynamic>?) onChange;
  final String placeholder;
  final bool allowNone;

  const _RecipePicker({
    required this.value,
    required this.onChange,
    this.placeholder = 'Search for a recipe…',
    this.allowNone = false,
  });

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _open = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) _ctrl.text = widget.value!['name'] as String? ?? '';
    _focus.addListener(() {
      if (_focus.hasFocus && !_open) {
        setState(() => _open = true);
        _search(_ctrl.text);
      }
    });
  }

  @override
  void didUpdateWidget(_RecipePicker old) {
    super.didUpdateWidget(old);
    if (widget.value == null && old.value != null) _ctrl.text = '';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    try {
      final params = <String, String>{'limit': '20'};
      if (query.trim().isNotEmpty) params['search'] = query.trim();
      final uri = Uri.parse('$apiUrl/recipes').replace(queryParameters: params);
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $_token'});
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _results = (data['recipes'] as List).cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  void _select(Map<String, dynamic>? recipe) {
    widget.onChange(recipe);
    _ctrl.text = recipe?['name'] as String? ?? '';
    _focus.unfocus();
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final showDropdown = _open && (_results.isNotEmpty || widget.allowNone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: (v) {
            if (widget.value != null) widget.onChange(null);
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () => _search(v));
          },
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: const TextStyle(color: Color(0xFFA8A29E), fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFA8A29E)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _orange),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        if (showDropdown)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(color: Color(0x18000000), blurRadius: 8, offset: Offset(0, 4))
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                if (widget.allowNone)
                  InkWell(
                    onTap: () => _select(null),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text(
                        'No specific recipe (general Q&A)',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ..._results.map((r) {
                  final isSelected = widget.value?['id'] == r['id'];
                  return InkWell(
                    onTap: () => _select(r),
                    child: Container(
                      color: isSelected ? const Color(0xFFFFF7ED) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text(
                        r['name'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? _orange : const Color(0xFF374151),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Pre-Cook tab ──────────────────────────────────────────────────────────────

class _PreCookTab extends StatefulWidget {
  const _PreCookTab();
  @override
  State<_PreCookTab> createState() => _PreCookTabState();
}

class _PreCookTabState extends State<_PreCookTab> {
  Map<String, dynamic>? _selected;
  String _response = '';
  bool _loading = false;
  String _error = '';

  Future<void> _handleStart() async {
    if (_selected == null) return;
    setState(() { _response = ''; _error = ''; _loading = true; });
    try {
      await _streamPost(
        '/ai/precook',
        {
          'recipe_name': _selected!['name'],
          'recipe_description': _selected!['description'],
          'recipe_instructions': _selected!['instructions'],
        },
        (chunk) { if (mounted) setState(() => _response += chunk); },
      );
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose a recipe',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151))),
          const SizedBox(height: 6),
          _RecipePicker(
            value: _selected,
            onChange: (r) => setState(() { _selected = r; _response = ''; }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected == null || _loading ? null : _handleStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                disabledBackgroundColor: _orange.withOpacity(0.5),
                disabledForegroundColor: Colors.white,
              ),
              child: Text(
                _loading ? 'Generating walkthrough…' : 'Get Pre-Cook Walkthrough',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFDC2626))),
            ),
          ],
          if (_response.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(_response,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1C1917),
                            height: 1.6)),
                  ),
                  if (_loading)
                    Container(
                      width: 8,
                      height: 16,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Mid-Cook chat tab ─────────────────────────────────────────────────────────

class _ChatTab extends StatefulWidget {
  const _ChatTab();
  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  Map<String, dynamic>? _selectedRecipe;
  final List<Map<String, String>> _messages = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    _inputCtrl.clear();
    setState(() {
      _error = '';
      _messages.add({'role': 'user', 'content': text});
      _messages.add({'role': 'assistant', 'content': ''});
      _loading = true;
    });
    _scrollToBottom();

    try {
      await _streamPost(
        '/ai/chat',
        {
          'messages': _messages
              .sublist(0, _messages.length - 1)
              .map((m) => {'role': m['role'], 'content': m['content']})
              .toList(),
          'recipe_name': _selectedRecipe?['name'],
        },
        (chunk) {
          if (!mounted) return;
          setState(() {
            _messages[_messages.length - 1] = {
              'role': 'assistant',
              'content': (_messages.last['content'] ?? '') + chunk,
            };
          });
          _scrollToBottom();
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Recipe picker + chat area in a flex column
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: _RecipePicker(
            value: _selectedRecipe,
            onChange: (r) => setState(() => _selectedRecipe = r),
            placeholder: 'Search for a recipe (or leave blank for general Q&A)…',
            allowNone: true,
          ),
        ),
        const SizedBox(height: 12),

        // Message list
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ask anything while you cook —\nheat levels, substitutions, technique tips…',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isUser = msg['role'] == 'user';
                      final content = msg['content'] ?? '';
                      final isTyping = !isUser &&
                          i == _messages.length - 1 &&
                          _loading &&
                          content.isEmpty;

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? _orange
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18).copyWith(
                              bottomRight: isUser
                                  ? const Radius.circular(4)
                                  : const Radius.circular(18),
                              bottomLeft: !isUser
                                  ? const Radius.circular(4)
                                  : const Radius.circular(18),
                            ),
                            border: isUser
                                ? null
                                : Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: isTyping
                              ? _TypingIndicator()
                              : Text(
                                  content,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isUser
                                        ? Colors.white
                                        : const Color(0xFF1F2937),
                                    height: 1.5,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ),

        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFDC2626))),
            ),
          ),

        // Input row
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  onSubmitted: (_) => _handleSend(),
                  enabled: !_loading,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Ask a cooking question…',
                    hintStyle: const TextStyle(
                        color: Color(0xFFA8A29E), fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _orange),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : _handleSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  disabledBackgroundColor: _orange.withOpacity(0.5),
                  disabledForegroundColor: Colors.white,
                ),
                child: const Text('Send',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final phase = (_ctrl.value - i * 0.167).clamp(0.0, 1.0);
            final bounce = (phase < 0.5 ? phase : 1.0 - phase) * 2;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 3),
              transform: Matrix4.translationValues(0, -4 * bounce, 0),
              decoration: const BoxDecoration(
                color: Color(0xFF9CA3AF),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

// ── Post-Cook debrief tab ─────────────────────────────────────────────────────

class _DebriefTab extends StatefulWidget {
  const _DebriefTab();
  @override
  State<_DebriefTab> createState() => _DebriefTabState();
}

class _DebriefTabState extends State<_DebriefTab> {
  final _dishCtrl = TextEditingController();
  final _techniquesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _cuisine = 'asian';
  int _rating = 3;
  int _difficulty = 3;
  String _response = '';
  bool _loading = false;
  String _error = '';

  static const _cuisines = [
    ('asian', 'Asian'),
    ('western', 'Western'),
    ('mediterranean', 'Mediterranean'),
    ('middle_eastern', 'Middle Eastern'),
    ('other', 'Other'),
  ];

  static const _ratingLabels = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];
  static const _difficultyLabels = ['', 'Very easy', 'Easy', 'Moderate', 'Hard', 'Very hard'];

  @override
  void dispose() {
    _dishCtrl.dispose();
    _techniquesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDebrief() async {
    if (_dishCtrl.text.trim().isEmpty) return;
    setState(() { _response = ''; _error = ''; _loading = true; });
    try {
      final techniques = _techniquesCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await _streamPost(
        '/ai/debrief',
        {
          'dish_name': _dishCtrl.text.trim(),
          'cuisine_type': _cuisine,
          'self_rating': _rating,
          'difficulty_felt': _difficulty,
          'technique_names': techniques,
          'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        },
        (chunk) { if (mounted) setState(() => _response += chunk); },
      );
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dish + Cuisine row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dish cooked',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    _inputField(
                      controller: _dishCtrl,
                      placeholder: 'e.g. Chicken Stir-fry',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cuisine',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _cuisine,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF1F2937)),
                          onChanged: (v) => setState(() => _cuisine = v!),
                          items: _cuisines
                              .map((c) => DropdownMenuItem(
                                    value: c.$1,
                                    child: Text(c.$2),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sliders row
          Row(
            children: [
              Expanded(child: _buildSlider(
                label: 'Self-rating (1–5)',
                value: _rating,
                sublabel: _ratingLabels[_rating],
                onChanged: (v) => setState(() => _rating = v),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildSlider(
                label: 'Difficulty felt (1–5)',
                value: _difficulty,
                sublabel: _difficultyLabels[_difficulty],
                onChanged: (v) => setState(() => _difficulty = v),
              )),
            ],
          ),
          const SizedBox(height: 16),

          // Techniques
          _label('Techniques used', note: 'comma-separated'),
          const SizedBox(height: 6),
          _inputField(
            controller: _techniquesCtrl,
            placeholder: 'e.g. Stir-fry, Dice, Deglaze',
          ),
          const SizedBox(height: 16),

          // Notes
          _label('Notes', note: 'optional'),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'What went well? What would you do differently?',
              hintStyle: const TextStyle(color: Color(0xFFA8A29E), fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _orange),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _dishCtrl.text.trim().isEmpty || _loading
                  ? null
                  : _handleDebrief,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                disabledBackgroundColor: _orange.withOpacity(0.5),
                disabledForegroundColor: Colors.white,
              ),
              child: Text(
                _loading ? 'Generating debrief…' : 'Get AI Debrief',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFDC2626))),
            ),
          ],
          if (_response.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(_response,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1C1917),
                            height: 1.6)),
                  ),
                  if (_loading)
                    Container(
                      width: 8,
                      height: 16,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _label(String text, {String? note}) {
    return Row(children: [
      Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151))),
      if (note != null) ...[
        const SizedBox(width: 4),
        Text('($note)',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ],
    ]);
  }

  Widget _inputField({
    required TextEditingController controller,
    required String placeholder,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle:
            const TextStyle(color: Color(0xFFA8A29E), fontSize: 13),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _orange),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required int value,
    required String sublabel,
    required void Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: _orange,
          inactiveColor: const Color(0xFFE5E7EB),
          onChanged: (v) => onChanged(v.round()),
        ),
        Text(sublabel,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}

// ── Main Coach screen ─────────────────────────────────────────────────────────

enum _CoachTab { precook, chat, debrief }

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  _CoachTab _tab = _CoachTab.precook;

  static const _tabs = [
    (_CoachTab.precook, '📋', 'Pre-Cook'),
    (_CoachTab.chat,    '💬', 'Mid-Cook'),
    (_CoachTab.debrief, '📝', 'Post-Cook'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Coach',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1917))),
                  const SizedBox(height: 2),
                  const Text(
                    'Personalised advice calibrated to your skill level.',
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFF78716C)),
                  ),
                  const SizedBox(height: 16),

                  // ── Tab switcher ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: _tabs.map((t) {
                        final active = _tab == t.$1;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _tab = t.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: active ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: active
                                    ? [
                                        const BoxShadow(
                                            color: Color(0x15000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1))
                                      ]
                                    : null,
                              ),
                              child: Text(
                                '${t.$2} ${t.$3}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: active
                                      ? _orange
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab content ────────────────────────────────────────────────
            Expanded(
              child: Container(
                color: Colors.white,
                child: switch (_tab) {
                  _CoachTab.precook => const _PreCookTab(),
                  _CoachTab.chat    => const _ChatTab(),
                  _CoachTab.debrief => const _DebriefTab(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
