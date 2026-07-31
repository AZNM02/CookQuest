import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class ApiService {
  static String get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken ?? '';

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  static Future<Map<String, dynamic>> getDashboard() async {
    final res = await http.get(
      Uri.parse('$apiUrl/stats/dashboard'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load dashboard');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getTechniques() async {
    final res = await http.get(
      Uri.parse('$apiUrl/techniques'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load techniques');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<List<dynamic>> getProficiency() async {
    final res = await http.get(
      Uri.parse('$apiUrl/techniques/proficiency'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load proficiency');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getRecipes({
    int limit = 12,
    int offset = 0,
    String search = '',
    String cuisineType = '',
    String difficulty = '',
    bool favoritesOnly = false,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (search.isNotEmpty) params['search'] = search;
    if (cuisineType.isNotEmpty) params['cuisine_type'] = cuisineType;
    if (difficulty.isNotEmpty) params['difficulty'] = difficulty;
    if (favoritesOnly) params['favorites_only'] = 'true';

    final uri = Uri.parse('$apiUrl/recipes').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load recipes');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> toggleFavorite(int recipeId, {required bool favorite}) async {
    final uri = Uri.parse('$apiUrl/recipes/$recipeId/favorite');
    if (favorite) {
      await http.post(uri, headers: _headers);
    } else {
      await http.delete(uri, headers: _headers);
    }
  }

  static Future<Map<String, dynamic>> logSession(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$apiUrl/sessions/log'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode != 201) {
      final decoded = jsonDecode(res.body);
      throw Exception(decoded['detail'] ?? 'Failed to log session');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(
      Uri.parse('$apiUrl/profile/me'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load profile');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getBadges() async {
    final res = await http.get(
      Uri.parse('$apiUrl/profile/badges'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load badges');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<List<dynamic>> getSessions({int limit = 20}) async {
    final uri = Uri.parse('$apiUrl/sessions')
        .replace(queryParameters: {'limit': '$limit'});
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load sessions');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getCharts() async {
    final res = await http.get(
      Uri.parse('$apiUrl/stats/charts'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load charts');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getRecommendations() async {
    final res = await http.get(
      Uri.parse('$apiUrl/recommendations'),
      headers: _headers,
    );
    if (res.statusCode != 200) return [];
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> importRecipes() async {
    final res = await http.post(
      Uri.parse('$apiUrl/recipes/import'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Import failed');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
