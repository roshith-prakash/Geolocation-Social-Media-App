import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

class UserListScreen extends StatefulWidget {
  final String title;
  final String userId;
  final bool isFollowers;

  const UserListScreen({
    super.key,
    required this.title,
    required this.userId,
    required this.isFollowers,
  });

  @override
  State<UserListScreen> createState() => UserListScreenState();
}

class UserListScreenState extends State<UserListScreen> {
  final supabaseService = SupabaseService();
  List<UserModel> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    setState(() => isLoading = true);
    try {
      final result = widget.isFollowers
          ? await supabaseService.getFollowers(widget.userId)
          : await supabaseService.getFollowing(widget.userId);
      setState(() {
        users = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? Center(child: Text('No ${widget.title.toLowerCase()} yet.'))
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: UserAvatar(
                        imageUrl: user.profileImage,
                        username: user.username,
                        radius: 20,
                      ),
                      title: Text(user.username),
                      subtitle: Text(user.email),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserProfileScreen(userId: user.id),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
