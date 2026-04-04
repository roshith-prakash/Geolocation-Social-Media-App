import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../services/supabase_service.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => PostDetailScreenState();
}

class PostDetailScreenState extends State<PostDetailScreen> {
  final supabaseService = SupabaseService();
  final commentController = TextEditingController();
  final scrollController = ScrollController();

  List<CommentModel> comments = [];
  bool isLoadingComments = true;
  bool isSubmitting = false;

  late int likeCount;
  bool isLiked = false;
  bool isLikeLoading = false;

  String? currentSupabaseUserId;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post.likeCount;
    init();
  }

  Future<void> init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final supaUser = await supabaseService.getUserByFirebaseUid(uid);
      if (supaUser != null && mounted) {
        currentSupabaseUserId = supaUser.id;
        final liked = await supabaseService.isLiked(
          postId: widget.post.id,
          userId: supaUser.id,
        );
        if (mounted) setState(() => isLiked = liked);
      }
    }
    await loadComments();
  }

  Future<void> loadComments() async {
    setState(() => isLoadingComments = true);
    try {
      final result = await supabaseService.getComments(widget.post.id);
      if (mounted) setState(() => comments = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingComments = false);
    }
  }

  Future<void> toggleLike() async {
    if (isLikeLoading || currentSupabaseUserId == null) return;
    setState(() {
      isLikeLoading = true;
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
    try {
      if (isLiked) {
        await supabaseService.likePost(postId: widget.post.id, userId: currentSupabaseUserId!);
      } else {
        await supabaseService.unlikePost(postId: widget.post.id, userId: currentSupabaseUserId!);
      }
    } catch (e) {
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

  Future<void> submitComment() async {
    final text = commentController.text.trim();
    if (text.isEmpty || currentSupabaseUserId == null || isSubmitting) return;

    setState(() => isSubmitting = true);
    try {
      final comment = await supabaseService.addComment(
        postId: widget.post.id,
        userId: currentSupabaseUserId!,
        content: text,
      );
      commentController.clear();
      setState(() => comments.add(comment));
      WidgetsBinding.instance.addPostFrameCallback((ts) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> deleteComment(CommentModel comment) async {
    if (currentSupabaseUserId != comment.userId) return;
    try {
      await supabaseService.deleteComment(comment.id);
      setState(() => comments.remove(comment));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  String formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget buildCommentTile(CommentModel comment) {
    final isOwn = comment.userId == currentSupabaseUserId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(imageUrl: comment.profileImage, username: comment.username ?? 'User', radius: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.username ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(formatTime(comment.createdAt), style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content),
              ],
            ),
          ),
          if (isOwn)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => deleteComment(comment),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => UserProfileScreen(userId: widget.post.userId),
                  )),
                  child: Row(
                    children: [
                      UserAvatar(imageUrl: widget.post.authorImage, username: widget.post.authorUsername ?? 'User', radius: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.post.authorUsername ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(formatTime(widget.post.createdAt), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.post.content != null && widget.post.content!.isNotEmpty)
                  Text(widget.post.content!, style: const TextStyle(fontSize: 16)),
                if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  CachedNetworkImage(
                    imageUrl: widget.post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: toggleLike,
                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : null),
                    ),
                    Text('$likeCount ${likeCount == 1 ? 'like' : 'likes'}'),
                    const SizedBox(width: 16),
                    const Icon(Icons.comment_outlined, size: 20),
                    const SizedBox(width: 6),
                    Text('${comments.length} comments'),
                  ],
                ),
                const Divider(),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (isLoadingComments)
                  const Center(child: CircularProgressIndicator())
                else if (comments.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('No comments yet. Be the first!'))
                else
                  ...comments.map((c) => buildCommentTile(c)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 12, right: 12, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                isSubmitting
                    ? const CircularProgressIndicator()
                    : IconButton(onPressed: submitComment, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
