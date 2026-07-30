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
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

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
    _fetch(0, reset: true);
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
      _fetch(0, reset: true);
    });
  }

  Future<void> _fetch(int offset, {required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
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
      final incoming =
          (data['recipes'] as List).cast<Map<String, dynamic>>();
      final total = (data['total'] as int?) ?? 0;
      if (mounted) {
        setState(() {
          _total = total;
          _recipes =
              reset ? incoming : [..._recipes, ...incoming];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
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
        final idx =
            _recipes.indexWhere((r) => r['id'] == recipe['id']);
        if (idx != -1) {
          _recipes[idx] = {..._recipes[idx], 'is_favorited': nowFav};
        }
      });
    }
    try {
      await ApiService.toggleFavorite((recipe['id'] as int?) ?? -1,
          favorite: nowFav);
    } catch (_) {
      setState(() {
        final idx =
            _recipes.indexWhere((r) => r['id'] == recipe['id']);
        if (idx != -1) {
          _recipes[idx] = {
            ..._recipes[idx],
            'is_favorited': !nowFav
          };
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Recipes',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Text(
                _loading ? '' : '$_total recipes',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF78716C)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search recipes…',
              hintStyle: const TextStyle(
                  color: Color(0xFFA8A29E), fontSize: 13),
              prefixIcon: const Icon(Icons.search,
                  size: 18, color: Color(0xFFA8A29E)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE7E5E4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _orange),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: _cuisineLabels[_cuisine]!,
                  active: _cuisine.isNotEmpty,
                  onTap: _showCuisineSheet,
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: _difficulty.isEmpty
                      ? 'All Difficulties'
                      : _difficulty[0].toUpperCase() +
                          _difficulty.substring(1),
                  active: _difficulty.isNotEmpty,
                  onTap: _showDifficultySheet,
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: '♥ Favorites',
                  active: _favoritesOnly,
                  activeColor: Colors.red,
                  onTap: () {
                    setState(() => _favoritesOnly = !_favoritesOnly);
                    _fetch(0, reset: true);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _orange));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => _fetch(0, reset: true),
              child: const Text('Retry',
                  style: TextStyle(color: _orange)),
            ),
          ],
        ),
      );
    }
    if (_recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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
    return RefreshIndicator(
      onRefresh: () => _fetch(0, reset: true),
      color: _orange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _recipes.length + (_recipes.length < _total ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _recipes.length) {
            return _LoadMoreButton(
              remaining: _total - _recipes.length,
              loading: _loadingMore,
              onTap: () => _fetch(_recipes.length, reset: false),
            );
          }
          return RecipeCard(
            recipe: _recipes[i],
            onToggleFavorite: () => _toggleFavorite(_recipes[i]),
          );
        },
      ),
    );
  }

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
                    _fetch(0, reset: true);
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
            trailing: _difficulty.isEmpty
                ? const Icon(Icons.check, color: _orange)
                : null,
            onTap: () {
              Navigator.pop(context);
              setState(() => _difficulty = '');
              _fetch(0, reset: true);
            },
          ),
          for (final d in ['beginner', 'intermediate', 'advanced'])
            ListTile(
              title: Text(
                  d[0].toUpperCase() + d.substring(1)),
              trailing: _difficulty == d
                  ? const Icon(Icons.check, color: _orange)
                  : null,
              onTap: () {
                Navigator.pop(context);
                setState(() => _difficulty = d);
                _fetch(0, reset: true);
              },
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  const _Chip({
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
              color:
                  active ? color : const Color(0xFFE7E5E4)),
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

class RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback? onToggleFavorite;

  const RecipeCard(
      {super.key, required this.recipe, this.onToggleFavorite});

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
    final techniques =
        (r['technique_names'] as List?)?.cast<String>() ?? [];
    final difficulty = r['difficulty'] as String? ?? '';
    final steps =
        _parseSteps(r['instructions'] as String? ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r['name'] as String? ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.onToggleFavorite != null)
                      GestureDetector(
                        onTap: widget.onToggleFavorite,
                        child: Icon(
                          isFav
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isFav
                              ? Colors.red
                              : const Color(0xFFD4D0CB),
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 6),
                    _DifficultyBadge(difficulty),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _cuisineLabels[r['cuisine_type'] as String? ?? ''] ??
                          (r['cuisine_type'] as String? ?? ''),
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF78716C)),
                    ),
                    if (r['estimated_time_mins'] != null) ...[
                      const Text(' · ',
                          style: TextStyle(
                              color: Color(0xFF78716C))),
                      Text(
                        '⏱ ${r['estimated_time_mins']} min',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF78716C)),
                      ),
                    ],
                  ],
                ),
                if ((r['description'] as String?)?.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 6),
                  Text(
                    r['description']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78716C)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (techniques.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: techniques
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F4),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(t,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF78716C))),
                            ))
                        .toList(),
                  ),
                ],
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded
                          ? '▲ Hide steps'
                          : '▼ Show cooking steps',
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
          if (_expanded && steps.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: Color(0xFFE7E5E4))),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cooking Steps',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF78716C))),
                  const SizedBox(height: 8),
                  ...steps.asMap().entries.map((e) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(
                                  right: 8, top: 1),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFFFF7ED),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: _orange,
                                      fontWeight:
                                          FontWeight.bold),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(e.value,
                                  style: const TextStyle(
                                      fontSize: 12,
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

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge(this.difficulty);

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (difficulty) {
      'beginner' => (
          const Color(0xFFF0FDF4),
          const Color(0xFF16A34A)
        ),
      'intermediate' => (
          const Color(0xFFFFFBEB),
          const Color(0xFFD97706)
        ),
      'advanced' => (
          const Color(0xFFFEF2F2),
          const Color(0xFFDC2626)
        ),
      _ => (const Color(0xFFF5F5F4), const Color(0xFF78716C)),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(difficulty,
          style: TextStyle(
              fontSize: 10,
              color: fg,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final int remaining;
  final bool loading;
  final VoidCallback onTap;

  const _LoadMoreButton(
      {required this.remaining,
      required this.loading,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton(
          onPressed: loading ? null : onTap,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFE7E5E4)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 10),
          ),
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _orange))
              : Text(
                  'Load more ($remaining remaining)',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF78716C))),
        ),
      ),
    );
  }
}
