import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _orange = Color(0xFFF97316);
const _pageSize = 12;

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _cuisine = '';
  String _difficulty = '';
  bool _favoritesOnly = false;

  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _recommendations = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _importing = false;
  String? _error;
  String _importMsg = '';

  static const _cuisineLabels = {
    '': 'All Cuisines',
    'asian': 'Asian',
    'western': 'Western',
    'mediterranean': 'Mediterranean',
    'middle_eastern': 'Middle Eastern',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _fetchRecipes(0, reset: true);
    _fetchRecommendations();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchRecipes(0, reset: true);
    });
  }

  Future<void> _fetchRecommendations() async {
    try {
      final data = await ApiService.getRecommendations();
      if (mounted) {
        setState(() => _recommendations =
            data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _fetchRecipes(int offset, {required bool reset}) async {
    if (reset) {
      setState(() { _loading = true; _error = null; });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final data = await ApiService.getRecipes(
        limit: _pageSize,
        offset: offset,
        search: _searchCtrl.text,
        cuisineType: _cuisine,
        difficulty: _difficulty,
        favoritesOnly: _favoritesOnly,
      );
      final incoming = (data['recipes'] as List).cast<Map<String, dynamic>>();
      final total = (data['total'] as int?) ?? 0;
      if (mounted) {
        setState(() {
          _total = total;
          _recipes = reset ? incoming : [..._recipes, ...incoming];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() { _loading = false; _loadingMore = false; });
      }
    }
  }

  Future<void> _handleImport() async {
    setState(() { _importing = true; _importMsg = ''; });
    try {
      final data = await ApiService.importRecipes();
      final imported = (data['imported'] as int?) ?? 0;
      if (mounted) {
        setState(() {
          _importMsg = imported > 0
              ? 'Added $imported new recipe${imported != 1 ? 's' : ''}!'
              : 'All fetched recipes are already in your library — try again for more.';
        });
        if (imported > 0) _fetchRecipes(0, reset: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _importMsg = 'Import failed — is the backend running?');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> recipe) async {
    final nowFav = !(recipe['is_favorited'] as bool? ?? false);
    if (_favoritesOnly && !nowFav) {
      setState(() {
        _recipes.removeWhere((r) => r['id'] == recipe['id']);
        _total = (_total - 1).clamp(0, _total);
      });
    } else {
      setState(() {
        final idx = _recipes.indexWhere((r) => r['id'] == recipe['id']);
        if (idx != -1) _recipes[idx] = {..._recipes[idx], 'is_favorited': nowFav};
      });
    }
    try {
      await ApiService.toggleFavorite((recipe['id'] as int?) ?? -1, favorite: nowFav);
    } catch (_) {
      setState(() {
        final idx = _recipes.indexWhere((r) => r['id'] == recipe['id']);
        if (idx != -1) _recipes[idx] = {..._recipes[idx], 'is_favorited': !nowFav};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Fixed header: title + subtitle + search + filters ──────────────────────

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recipes',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1917))),
          const SizedBox(height: 2),
          const Text('Personalised picks and a full recipe library.',
              style: TextStyle(fontSize: 13, color: Color(0xFF78716C))),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search recipes…',
              hintStyle: const TextStyle(color: Color(0xFFA8A29E), fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFA8A29E)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: _cuisineLabels[_cuisine]!,
                  active: _cuisine.isNotEmpty,
                  onTap: _showCuisineSheet,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _difficulty.isEmpty
                      ? 'All Difficulties'
                      : _difficulty[0].toUpperCase() + _difficulty.substring(1),
                  active: _difficulty.isNotEmpty,
                  onTap: _showDifficultySheet,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '♥ Favorites',
                  active: _favoritesOnly,
                  activeColor: Colors.red,
                  onTap: () {
                    setState(() => _favoritesOnly = !_favoritesOnly);
                    _fetchRecipes(0, reset: true);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Scrollable body ─────────────────────────────────────────────────────────

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _fetchRecipes(0, reset: true),
          _fetchRecommendations(),
        ]);
      },
      color: _orange,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          // ── Recommended for you ─────────────────────────────────────────
          if (_recommendations.isNotEmpty) ...[
            _buildRecommendationsSection(),
            const SizedBox(height: 28),
          ],

          // ── Library header: title + Discover more ──────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(children: [
                  Text(
                    _favoritesOnly ? 'Favorites' : 'All Recipes',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1917)),
                  ),
                  if (!_loading) ...[
                    const SizedBox(width: 4),
                    Text('($_total)',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  ],
                ]),
              ),
              GestureDetector(
                onTap: _importing ? null : _handleImport,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _importing ? const Color(0xFFD4D0CB) : _orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _importing ? 'Importing…' : '✦ Discover more',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),

          // ── Import feedback message ────────────────────────────────────
          if (_importMsg.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Text(_importMsg,
                  style: const TextStyle(fontSize: 13, color: _orange)),
            ),
          ],

          const SizedBox(height: 12),

          // ── Recipe list ────────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: _orange)),
            )
          else if (_error != null)
            _buildError()
          else if (_recipes.isEmpty)
            _buildEmpty()
          else ...[
            ..._recipes.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RecipeCard(
                    recipe: r,
                    onToggleFavorite: () => _toggleFavorite(r),
                  ),
                )),
            if (_recipes.length < _total)
              _LoadMoreButton(
                remaining: _total - _recipes.length,
                loading: _loadingMore,
                onTap: () => _fetchRecipes(_recipes.length, reset: false),
              ),
          ],
        ],
      ),
    );
  }

  // ── Recommendations section ────────────────────────────────────────────────

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          const Text('Recommended for you',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1917))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Text('Targets your skill gaps',
                style: TextStyle(fontSize: 10, color: _orange,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
        const SizedBox(height: 12),
        ..._recommendations.map((r) {
          final weak = (r['weak_techniques_targeted'] as List<dynamic>?)
                  ?.cast<String>() ??
              [];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RecipeCard(
              recipe: r,
              highlighted: true,
              weakTargeted: weak,
            ),
          );
        }),
      ],
    );
  }

  // ── Error + empty states ───────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
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
            onPressed: () => _fetchRecipes(0, reset: true),
            child: const Text('Retry', style: TextStyle(color: _orange)),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
        child: Text(
          _favoritesOnly
              ? 'No favorites yet — tap ♡ on a recipe to save it.'
              : _searchCtrl.text.isNotEmpty
                  ? 'No recipes found for "${_searchCtrl.text}".'
                  : 'No recipes match your filters.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF78716C)),
        ),
      ),
    );
  }

  // ── Bottom sheets ──────────────────────────────────────────────────────────

  void _showCuisineSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: _cuisineLabels.entries
            .map((e) => ListTile(
                  title: Text(e.value),
                  trailing: _cuisine == e.key
                      ? const Icon(Icons.check, color: _orange)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _cuisine = e.key);
                    _fetchRecipes(0, reset: true);
                  },
                ))
            .toList(),
      ),
    );
  }

  void _showDifficultySheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('All Difficulties'),
            trailing: _difficulty.isEmpty ? const Icon(Icons.check, color: _orange) : null,
            onTap: () {
              Navigator.pop(context);
              setState(() => _difficulty = '');
              _fetchRecipes(0, reset: true);
            },
          ),
          for (final d in ['beginner', 'intermediate', 'advanced'])
            ListTile(
              title: Text(d[0].toUpperCase() + d.substring(1)),
              trailing: _difficulty == d ? const Icon(Icons.check, color: _orange) : null,
              onTap: () {
                Navigator.pop(context);
                setState(() => _difficulty = d);
                _fetchRecipes(0, reset: true);
              },
            ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? _orange;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(color: active ? color : const Color(0xFFE7E5E4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? color : const Color(0xFF78716C),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Recipe card ───────────────────────────────────────────────────────────────

class RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback? onToggleFavorite;
  final bool highlighted;
  final List<String> weakTargeted;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onToggleFavorite,
    this.highlighted = false,
    this.weakTargeted = const [],
  });

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool _expanded = false;

  static const _cuisineLabels = {
    'asian': 'Asian',
    'western': 'Western',
    'mediterranean': 'Mediterranean',
    'middle_eastern': 'Middle Eastern',
    'other': 'Other',
  };

  List<String> _parseSteps(String instructions) {
    return instructions
        .split('\n')
        .map((s) => s.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final isFav = r['is_favorited'] as bool? ?? false;
    final techniques = (r['technique_names'] as List?)?.cast<String>() ?? [];
    final difficulty = r['difficulty'] as String? ?? '';
    final steps = _parseSteps(r['instructions'] as String? ?? '');
    final description = r['description']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.highlighted
              ? const Color(0xFFFED7AA)
              : const Color(0xFFE5E7EB),
        ),
        gradient: widget.highlighted
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
              )
            : null,
        color: widget.highlighted ? null : Colors.white,
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name + favorite + difficulty ──────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r['name'] as String? ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF111827)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.onToggleFavorite != null)
                      GestureDetector(
                        onTap: widget.onToggleFavorite,
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : const Color(0xFFD1D5DB),
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 6),
                    _DifficultyBadge(difficulty),
                  ],
                ),
                const SizedBox(height: 6),

                // ── Cuisine + time ────────────────────────────────────────
                Row(children: [
                  Text(
                    _cuisineLabels[r['cuisine_type'] as String? ?? ''] ??
                        (r['cuisine_type'] as String? ?? ''),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                  if (r['estimated_time_mins'] != null) ...[
                    const Text(' · ',
                        style: TextStyle(color: Color(0xFF9CA3AF))),
                    Text('⏱ ${r['estimated_time_mins']} min',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ]),

                // ── Description ───────────────────────────────────────────
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],

                // ── Technique tags ────────────────────────────────────────
                if (techniques.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: techniques.map((t) {
                      final isWeak = widget.weakTargeted.contains(t);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isWeak
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t,
                            style: TextStyle(
                              fontSize: 10,
                              color: isWeak
                                  ? _orange
                                  : const Color(0xFF6B7280),
                              fontWeight: isWeak
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            )),
                      );
                    }).toList(),
                  ),
                ],

                // ── "Targets X weak techniques" label ─────────────────────
                if (widget.weakTargeted.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '✦ Targets ${widget.weakTargeted.length} of your weak '
                    'technique${widget.weakTargeted.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: _orange,
                        fontWeight: FontWeight.w500),
                  ),
                ],

                // ── Show steps toggle ─────────────────────────────────────
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? '▲ Hide steps' : '▼ Show cooking steps',
                      style: const TextStyle(
                          fontSize: 12,
                          color: _orange,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Expanded cooking steps ─────────────────────────────────────
          if (_expanded && steps.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('COOKING STEPS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 10),
                  ...steps.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(right: 10, top: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${e.key + 1}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: _orange,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            Expanded(
                              child: Text(e.value,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF374151),
                                      height: 1.5)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Difficulty badge ──────────────────────────────────────────────────────────

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge(this.difficulty);

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (difficulty) {
      'beginner' => (const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
      'intermediate' => (const Color(0xFFFFFBEB), const Color(0xFFD97706)),
      'advanced' => (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF78716C)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(difficulty,
          style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Load more button ──────────────────────────────────────────────────────────

class _LoadMoreButton extends StatelessWidget {
  final int remaining;
  final bool loading;
  final VoidCallback onTap;

  const _LoadMoreButton({
    required this.remaining,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton(
          onPressed: loading ? null : onTap,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _orange))
              : Text('Load more ($remaining remaining)',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ),
      ),
    );
  }
}
