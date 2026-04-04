import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/supabase_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/post_card.dart';
import 'user_list_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => UserProfileScreenState();
}

class UserProfileScreenState extends State<UserProfileScreen> {
  final supabaseService = SupabaseService();

  UserModel? user;
  List<PostModel> posts = [];
  int followerCount = 0;
  int followingCount = 0;
  bool isFollowing = false;
  bool isLoading = true;
  bool isFollowLoading = false;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() => isLoading = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final currentUser =
            await supabaseService.getUserByFirebaseUid(firebaseUser.uid);
        currentUserId = currentUser?.id;
      }

      final loadedUser = await supabaseService.getUserById(widget.userId);
      if (loadedUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final loadedPosts = await supabaseService.getPostsByUser(widget.userId);
      final followers = await supabaseService.getFollowerCount(widget.userId);
      final following = await supabaseService.getFollowingCount(widget.userId);

      bool currentlyFollowing = false;
      if (currentUserId != null && currentUserId != widget.userId) {
        currentlyFollowing = await supabaseService.isFollowing(
          followerId: currentUserId!,
          followingId: widget.userId,
        );
      }

      setState(() {
        user = loadedUser;
        posts = loadedPosts;
        followerCount = followers;
        followingCount = following;
        isFollowing = currentlyFollowing;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> toggleFollow() async {
    if (currentUserId == null || currentUserId == widget.userId) return;

    setState(() => isFollowLoading = true);
    try {
      if (isFollowing) {
        await supabaseService.unfollowUser(
          followerId: currentUserId!,
          followingId: widget.userId,
        );
        setState(() {
          isFollowing = false;
          followerCount--;
        });
      } else {
        await supabaseService.followUser(
          followerId: currentUserId!,
          followingId: widget.userId,
        );
        setState(() {
          isFollowing = true;
          followerCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => isFollowLoading = false);
    }
  }

  Widget buildStat(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = currentUserId == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.username ?? 'Profile'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('User not found'))
              : ListView(
                  children: [
                    const SizedBox(height: 24),

                    // Avatar
                    Center(
                      child: UserAvatar(
                        imageUrl: user!.profileImage,
                        username: user!.username,
                        radius: 50,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Username
                    Center(
                      child: Text(
                        user!.username,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildStat('Posts', posts.length.toString()),
                        const SizedBox(width: 8),
                        buildStat('Followers', followerCount.toString(), onTap: () {
                          if (user != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserListScreen(
                                  title: 'Followers',
                                  userId: user!.id,
                                  isFollowers: true,
                                ),
                              ),
                            );
                          }
                        }),
                        const SizedBox(width: 8),
                        buildStat('Following', followingCount.toString(), onTap: () {
                          if (user != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserListScreen(
                                  title: 'Following',
                                  userId: user!.id,
                                  isFollowers: false,
                                ),
                              ),
                            );
                          }
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Follow button
                    if (!isOwnProfile)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: ElevatedButton(
                          onPressed: isFollowLoading ? null : toggleFollow,
                          child: isFollowLoading
                              ? const CircularProgressIndicator()
                              : Text(isFollowing ? 'Unfollow' : 'Follow'),
                        ),
                      ),
                    const SizedBox(height: 20),

                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Posts',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),

                    // Posts
                    if (posts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('No posts yet')),
                      )
                    else
                      ...posts.map((post) => PostCard(post: post)),
                  ],
                ),
    );
  }
}
