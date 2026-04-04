import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../screens/post_detail_screen.dart';
import '../services/supabase_service.dart';
import 'user_avatar.dart';

class PostMarkerInfo extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onAuthorTap;

  const PostMarkerInfo({
    super.key,
    required this.post,
    this.onAuthorTap,
  });

  @override
  State<PostMarkerInfo> createState() => PostMarkerInfoState();
}

class PostMarkerInfoState extends State<PostMarkerInfo> {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  radius: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onAuthorTap,
                      child: Text(
                        widget.post.authorUsername ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Text(
                      '${widget.post.createdAt.day}/${widget.post.createdAt.month}/${widget.post.createdAt.year}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (widget.post.distance != null)
                Text(widget.post.distanceLabel),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          if (widget.post.content != null && widget.post.content!.isNotEmpty)
            Text(widget.post.content!, style: const TextStyle(fontSize: 15)),

          // Image
          if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            CachedNetworkImage(
              imageUrl: widget.post.imageUrl!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
            ),
          ],

          const SizedBox(height: 8),

          // Like row and View Post button
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
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: widget.post),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('View Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
