import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../utils/theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/post_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _supabaseService = SupabaseService();

  UserModel? _user;
  List<PostModel> _posts = [];
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      final user =
          await _supabaseService.getUserByFirebaseUid(firebaseUser.uid);
      if (user == null) return;

      final posts = await _supabaseService.getPostsByUser(user.id);
      final followers = await _supabaseService.getFollowerCount(user.id);
      final following = await _supabaseService.getFollowingCount(user.id);

      setState(() {
        _user = user;
        _posts = posts;
        _followerCount = followers;
        _followingCount = following;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    // AuthWrapper will detect the auth state change and show LoginScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.accentPink),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surfaceDark,
                  title: const Text('Sign Out',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  content: const Text('Are you sure you want to sign out?',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _signOut();
                      },
                      child: const Text('Sign Out',
                          style: TextStyle(color: AppTheme.accentPink)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : _user == null
              ? const Center(
                  child: Text('Profile not found',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : RefreshIndicator(
                  color: AppTheme.accentCyan,
                  backgroundColor: AppTheme.surfaceDark,
                  onRefresh: _loadProfile,
                  child: ListView(
                    children: [
                      const SizedBox(height: 24),
                      // Avatar
                      Center(
                        child: UserAvatar(
                          imageUrl: _user!.profileImage,
                          username: _user!.username,
                          radius: 50,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Username
                      Center(
                        child: Text(
                          _user!.username,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          _user!.email,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStat('Posts', _posts.length.toString()),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppTheme.borderDark,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          _buildStat('Followers', _followerCount.toString()),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppTheme.borderDark,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          _buildStat('Following', _followingCount.toString()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Icon(Icons.grid_view,
                                color: AppTheme.accentCyan, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'My Posts',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: AppTheme.borderDark),

                      // Posts list
                      if (_posts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.pin_drop,
                                    size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                const Text(
                                  'No posts yet',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._posts.map((post) => PostCard(post: post)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
