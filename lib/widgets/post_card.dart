import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../screens/post_detail_screen.dart';
import '../services/supabase_service.dart';
import 'user_avatar.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final Widget? trailing;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAuthorTap,
    this.trailing,
  });

  @override
  State<PostCard> createState() => PostCardState();
}

class PostCardState extends State<PostCard> {
  final supabaseService = SupabaseService();
  late int likeCount;
  bool isLiked = false;
  bool isLikeLoading = false;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post.likeCount;
    loadLikeStatus();
  }

  Future<void> loadLikeStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final supaUser = await supabaseService.getUserByFirebaseUid(uid);
    if (supaUser == null || !mounted) return;
    final liked = await supabaseService.isLiked(
      postId: widget.post.id,
      userId: supaUser.id,
    );
    if (mounted) setState(() => isLiked = liked);
  }

  Future<void> toggleLike() async {
    if (isLikeLoading) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final supaUser = await supabaseService.getUserByFirebaseUid(uid);
    if (supaUser == null) return;

    setState(() {
      isLikeLoading = true;
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    try {
      if (isLiked) {
        await supabaseService.likePost(
            postId: widget.post.id, userId: supaUser.id);
      } else {
        await supabaseService.unlikePost(
            postId: widget.post.id, userId: supaUser.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isLiked = !isLiked;
          likeCount += isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => isLikeLoading = false);
    }
  }

  String formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: widget.onTap ?? () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(post: widget.post),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author row
              Row(
                children: [
                   GestureDetector(
                    onTap: widget.onAuthorTap,
                    child: UserAvatar(
                      imageUrl: widget.post.authorImage,
                      username: widget.post.authorUsername ?? 'User',
                      radius: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: widget.onAuthorTap,
                          child: Text(
                            widget.post.authorUsername ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          formatTime(widget.post.createdAt),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (widget.post.distance != null)
                    Chip(
                      label: Text(widget.post.distanceLabel),
                      avatar: const Icon(Icons.location_on, size: 14),
                    ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),

              // Content text
              if (widget.post.content != null && widget.post.content!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(widget.post.content!),
              ],

              // Image
              if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                CachedNetworkImage(
                  imageUrl: widget.post.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image, size: 40),
                ),
              ],

              // Like button
              Row(
                children: [
                  IconButton(
                    onPressed: toggleLike,
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : null,
                    ),
                  ),
                  Text('$likeCount'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
