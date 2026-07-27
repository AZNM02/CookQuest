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
  Map<String, dynamic>? _profile;
  List<dynamic> _badges = [];
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
        ApiService.getProfile(),
        ApiService.getBadges(),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>;
          _badges = results[1] as List<dynamic>;
        });
      }
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
                                    style:
                                        TextStyle(color: _orange))),
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
    final p = _profile!;
    final level = p['level'] as int? ?? 1;
    final xp = p['xp'] as int? ?? 0;
    final streak = p['streak_count'] as int? ?? 0;
    final longestStreak = p['longest_streak'] as int? ?? 0;
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? '';
    final displayName = p['display_name'] as String?;
    final name =
        displayName?.isNotEmpty == true ? displayName! : email;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                      color: Colors.white,
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
                  Text(
                    displayName?.isNotEmpty == true
                        ? displayName!
                        : 'Chef',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(email,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF78716C))),
                ],
              ),
            ),
            IconButton(
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout,
                  color: Color(0xFF78716C)),
              tooltip: 'Sign out',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Level $level',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  Text('$xp XP total',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
              const Spacer(),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
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
        ),
        const SizedBox(height: 12),
        if (longestStreak > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7E5E4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: _orange, size: 18),
                const SizedBox(width: 8),
                Text('Longest streak: $longestStreak days',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const Text('Badges',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (_badges.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7E5E4)),
            ),
            child: const Center(
              child: Text(
                'No badges yet — log sessions to earn them!',
                style: TextStyle(
                    color: Color(0xFF78716C), fontSize: 13),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: _badges.length,
            itemBuilder: (_, i) {
              final b = _badges[i] as Map<String, dynamic>;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFE7E5E4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(b['icon'] as String? ?? '🏅',
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        b['name'] as String? ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

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
    final parts = name.split(RegExp(r'[\s_@]+'));
    if (parts.length >= 2 &&
        parts[0].isNotEmpty &&
        parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }
}
