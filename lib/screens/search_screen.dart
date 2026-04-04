import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final supabaseService = SupabaseService();
  final searchController = TextEditingController();

  List<UserModel> results = [];
  bool isSearching = false;
  bool hasSearched = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        results = [];
        hasSearched = false;
      });
      return;
    }
    setState(() => isSearching = true);
    try {
      final users = await supabaseService.searchUsers(q);
      if (mounted) {
        setState(() {
          results = users;
          hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search users...',
            border: InputBorder.none,
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      searchController.clear();
                      search('');
                    },
                  )
                : null,
          ),
          onChanged: search,
        ),
      ),
      body: isSearching
          ? const Center(child: CircularProgressIndicator())
          : !hasSearched
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 72),
                      SizedBox(height: 16),
                      Text('Search for users'),
                    ],
                  ),
                )
              : results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_search, size: 64),
                          const SizedBox(height: 16),
                          Text('No users found for "${searchController.text}"'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final user = results[index];
                        return ListTile(
                          leading: UserAvatar(
                            imageUrl: user.profileImage,
                            username: user.username,
                            radius: 22,
                          ),
                          title: Text(user.username),
                          subtitle: Text(user.email),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => UserProfileScreen(userId: user.id),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
