import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/post_card.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _locationService = LocationService();
  final _supabaseService = SupabaseService();

  List<PostModel> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final position = await _locationService.getCurrentPosition();

      final posts = await _supabaseService.getNearbyPosts(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: AppConstants.defaultRadiusMeters,
      );

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Posts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentCyan),
            onPressed: _loadPosts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            )
          : _posts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.accentCyan,
                  backgroundColor: AppTheme.surfaceDark,
                  onRefresh: _loadPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return PostCard(
                        post: post,
                        onAuthorTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserProfileScreen(userId: post.userId),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: const Icon(Icons.explore_off, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'No posts nearby',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to post something here!',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPosts,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
