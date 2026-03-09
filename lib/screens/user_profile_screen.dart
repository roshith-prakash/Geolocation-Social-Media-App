import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/supabase_service.dart';
import '../utils/theme.dart';
import '../widgets/user_avatar.dart';
import '../widgets/post_card.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabaseService = SupabaseService();

  UserModel? _user;
  List<PostModel> _posts = [];
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  bool _isLoading = true;
  bool _isFollowLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      // Get current user ID
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final currentUser =
            await _supabaseService.getUserByFirebaseUid(firebaseUser.uid);
        _currentUserId = currentUser?.id;
      }

      final user = await _supabaseService.getUserById(widget.userId);
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final posts = await _supabaseService.getPostsByUser(widget.userId);
      final followers =
          await _supabaseService.getFollowerCount(widget.userId);
      final following =
          await _supabaseService.getFollowingCount(widget.userId);

      bool isFollowing = false;
      if (_currentUserId != null && _currentUserId != widget.userId) {
        isFollowing = await _supabaseService.isFollowing(
          followerId: _currentUserId!,
          followingId: widget.userId,
        );
      }

      setState(() {
        _user = user;
        _posts = posts;
        _followerCount = followers;
        _followingCount = following;
        _isFollowing = isFollowing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _currentUserId == widget.userId) return;

    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        await _supabaseService.unfollowUser(
          followerId: _currentUserId!,
          followingId: widget.userId,
        );
        setState(() {
          _isFollowing = false;
          _followerCount--;
        });
      } else {
        await _supabaseService.followUser(
          followerId: _currentUserId!,
          followingId: widget.userId,
        );
        setState(() {
          _isFollowing = true;
          _followerCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isFollowLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = _currentUserId == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_user?.username ?? 'Profile'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : _user == null
              ? const Center(
                  child: Text('User not found',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : ListView(
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
                    const SizedBox(height: 20),

                    // Stats
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
                    const SizedBox(height: 20),

                    // Follow button
                    if (!isOwnProfile)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: _isFollowing
                            ? OutlinedButton(
                                onPressed:
                                    _isFollowLoading ? null : _toggleFollow,
                                child: _isFollowLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Unfollow'),
                              )
                            : ElevatedButton(
                                onPressed:
                                    _isFollowLoading ? null : _toggleFollow,
                                child: _isFollowLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.primaryDark),
                                      )
                                    : const Text('Follow'),
                              ),
                      ),
                    const SizedBox(height: 20),

                    // Posts header
                    const Divider(color: AppTheme.borderDark),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.grid_view,
                              color: AppTheme.accentCyan, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Posts',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Posts
                    if (_posts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No posts yet',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 16),
                          ),
                        ),
                      )
                    else
                      ..._posts.map((post) => PostCard(post: post)),
                  ],
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
