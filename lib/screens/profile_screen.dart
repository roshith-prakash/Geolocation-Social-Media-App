import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/post_card.dart';
import 'user_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final authService = AuthService();
  final supabaseService = SupabaseService();

  UserModel? user;
  List<PostModel> posts = [];
  int followerCount = 0;
  int followingCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() => isLoading = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      final loadedUser = await supabaseService.getUserByFirebaseUid(firebaseUser.uid);
      if (loadedUser == null) return;

      final loadedPosts = await supabaseService.getPostsByUser(loadedUser.id);
      final followers = await supabaseService.getFollowerCount(loadedUser.id);
      final following = await supabaseService.getFollowingCount(loadedUser.id);

      setState(() {
        user = loadedUser;
        posts = loadedPosts;
        followerCount = followers;
        followingCount = following;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> signOut() async {
    await authService.signOut();
  }

  Future<void> deletePost(PostModel post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await supabaseService.deletePost(post.id);
    setState(() => posts.remove(post));
  }

  Future<void> showEditProfile() async {
    if (user == null) return;
    final usernameController = TextEditingController(text: user!.username);
    final String? oldAvatarUrl = user!.profileImage;
    String? newAvatarUrl = user!.profileImage;
    bool isUploading = false;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                  if (xfile == null) return;
                  setDialogState(() => isUploading = true);
                  try {
                    final rawUrl = await StorageService().uploadProfileImage(xfile.path, user!.id);
                    newAvatarUrl = '$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}';
                    setDialogState(() {});
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Image upload failed: ${e.toString()}')),
                      );
                    }
                  } finally {
                    setDialogState(() => isUploading = false);
                  }
                },
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(imageUrl: newAvatarUrl, username: user!.username, radius: 40),
                      if (isUploading)
                        const Positioned.fill(child: Center(child: CircularProgressIndicator()))
                      else
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey.shade700,
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newUsername = usernameController.text.trim();
                      if (newUsername.isEmpty) return;
                      setDialogState(() => isSaving = true);
                      try {
                        if (oldAvatarUrl != null) {
                          await CachedNetworkImage.evictFromCache(oldAvatarUrl);
                        }
                        await supabaseService.updateUser(user!.id, {
                          'username': newUsername,
                          'profile_image': newAvatarUrl,
                        });
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        loadProfile();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Failed to save: ${e.toString()}')),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStat(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: showEditProfile),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        signOut();
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('Profile not found'))
              : RefreshIndicator(
                  onRefresh: loadProfile,
                  child: ListView(
                    children: [
                      const SizedBox(height: 24),
                      Center(child: UserAvatar(imageUrl: user!.profileImage, username: user!.username, radius: 50)),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(user!.username,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      Center(child: Text(user!.email)),
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('My Posts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      const Divider(),
                      if (posts.isEmpty)
                        const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No posts yet')))
                      else
                        ...posts.map(
                          (post) => PostCard(
                            post: post,
                            onAuthorTap: null,
                            onTap: null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => deletePost(post),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
