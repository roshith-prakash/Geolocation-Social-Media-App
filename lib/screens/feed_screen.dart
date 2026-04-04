import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../widgets/post_card.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  final locationService = LocationService();
  final supabaseService = SupabaseService();

  List<PostModel> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  Future<void> loadPosts() async {
    setState(() => isLoading = true);
    try {
      final position = await locationService.getCurrentPosition();
      final result = await supabaseService.getNearbyPosts(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: AppConstants.defaultRadiusMeters,
      );
      setState(() {
        posts = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadPosts),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.explore_off, size: 64),
                      const SizedBox(height: 16),
                      const Text('No posts nearby', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('Be the first to post something here!'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: loadPosts,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return PostCard(
                        post: post,
                        onAuthorTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => UserProfileScreen(userId: post.userId),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
