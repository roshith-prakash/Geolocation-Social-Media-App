import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../utils/constants.dart';

const likesTable = 'post_likes';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ─── User Operations ───

  /// Create a new user profile in Supabase
  Future<UserModel> createUser({
    required String firebaseUid,
    required String username,
    required String email,
    String? profileImage,
  }) async {
    final response = await client.from(AppConstants.usersTable).insert({
      'firebase_uid': firebaseUid,
      'username': username,
      'email': email,
      'profile_image': profileImage,
    }).select().single();

    return UserModel.fromJson(response);
  }

  /// Get user by Firebase UID
  Future<UserModel?> getUserByFirebaseUid(String firebaseUid) async {
    final response = await client
        .from(AppConstants.usersTable)
        .select()
        .eq('firebase_uid', firebaseUid)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  /// Get user by Supabase ID
  Future<UserModel?> getUserById(String userId) async {
    final response = await client
        .from(AppConstants.usersTable)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  /// Update user profile
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await client
        .from(AppConstants.usersTable)
        .update(data)
        .eq('id', userId);
  }

  /// Search users by username
  Future<List<UserModel>> searchUsers(String query) async {
    final response = await client
        .from(AppConstants.usersTable)
        .select()
        .ilike('username', '%$query%')
        .limit(20);

    return (response as List)
        .map((json) => UserModel.fromJson(json))
        .toList();
  }

  // ─── Post Operations ───

  /// Create a new post
  Future<void> createPost({
    required String userId,
    String? content,
    String? imageUrl,
    required double latitude,
    required double longitude,
  }) async {
    await client.rpc('create_post_with_location', params: {
      'p_user_id': userId,
      'p_content': content,
      'p_image_url': imageUrl,
      'p_lng': longitude,
      'p_lat': latitude,
    });
  }

  /// Get nearby posts using PostGIS spatial query
  Future<List<PostModel>> getNearbyPosts({
    required double latitude,
    required double longitude,
    double radiusMeters = 1000.0,
  }) async {
    final response = await client.rpc('get_nearby_posts', params: {
      'lat': latitude,
      'lng': longitude,
      'radius_meters': radiusMeters,
    });

    return (response as List)
        .map((json) => PostModel.fromJson(json))
        .toList();
  }

  /// Get posts by a specific user
  Future<List<PostModel>> getPostsByUser(String userId) async {
    final response = await client.rpc('get_user_posts', params: {
      'target_user_id': userId,
    });

    return (response as List)
        .map((json) => PostModel.fromJson(json))
        .toList();
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    await client.from(AppConstants.postsTable).delete().eq('id', postId);
  }

  // ─── Like Operations ───

  /// Like a post
  Future<void> likePost({required String postId, required String userId}) async {
    await client.from(likesTable).insert({
      'post_id': postId,
      'user_id': userId,
    });
  }

  /// Unlike a post
  Future<void> unlikePost({required String postId, required String userId}) async {
    await client
        .from(likesTable)
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  /// Whether the current user has liked a post
  Future<bool> isLiked({required String postId, required String userId}) async {
    final response = await client
        .from(likesTable)
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    return response != null;
  }

  /// Total like count for a post
  Future<int> getLikeCount(String postId) async {
    final response = await client
        .from(likesTable)
        .select()
        .eq('post_id', postId);
    return (response as List).length;
  }

  // ─── Comment Operations ───

  /// Add a comment to a post
  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    final response = await client.from('comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
    }).select().single();
    // Fetch full comment with username via RPC
    final comments = await getComments(postId);
    return comments.firstWhere((c) => c.id == response['id']);
  }

  /// Get all comments for a post
  Future<List<CommentModel>> getComments(String postId) async {
    final response = await client.rpc('get_comments', params: {
      'target_post_id': postId,
    });
    return (response as List)
        .map((json) => CommentModel.fromJson(json))
        .toList();
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    await client.from('comments').delete().eq('id', commentId);
  }

  // ─── Follower Operations ───

  /// Follow a user
  Future<void> followUser({
    required String followerId,
    required String followingId,
  }) async {
    await client.from(AppConstants.followersTable).insert({
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  /// Unfollow a user
  Future<void> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    await client
        .from(AppConstants.followersTable)
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
  }

  /// Check if user A follows user B
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    final response = await client
        .from(AppConstants.followersTable)
        .select()
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();

    return response != null;
  }

  /// Get follower count
  Future<int> getFollowerCount(String userId) async {
    final response = await client
        .from(AppConstants.followersTable)
        .select()
        .eq('following_id', userId);

    return (response as List).length;
  }

  /// Get following count
  Future<int> getFollowingCount(String userId) async {
    final response = await client
        .from(AppConstants.followersTable)
        .select()
        .eq('follower_id', userId);

    return (response as List).length;
  }

  /// Get list of users that a user follows
  Future<List<UserModel>> getFollowing(String userId) async {
    final response = await client
        .from(AppConstants.followersTable)
        .select('following_id, users!followers_following_id_fkey(*)')
        .eq('follower_id', userId);

    return (response as List).map((json) {
      return UserModel.fromJson(json['users']);
    }).toList();
  }

  /// Get list of followers
  Future<List<UserModel>> getFollowers(String userId) async {
    final response = await client
        .from(AppConstants.followersTable)
        .select('follower_id, users!followers_follower_id_fkey(*)')
        .eq('following_id', userId);

    return (response as List).map((json) {
      return UserModel.fromJson(json['users']);
    }).toList();
  }
}
