import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

class StorageService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const _uuid = Uuid();

  /// Upload an image file to Supabase Storage and return the public URL
  Future<String> uploadPostImage(File imageFile) async {
    final fileExtension = imageFile.path.split('.').last;
    final fileName = '${_uuid.v4()}.$fileExtension';
    final filePath = 'posts/$fileName';

    await _client.storage
        .from(AppConstants.postImagesBucket)
        .upload(filePath, imageFile);

    final publicUrl = _client.storage
        .from(AppConstants.postImagesBucket)
        .getPublicUrl(filePath);

    return publicUrl;
  }

  /// Delete an image from Supabase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extract the path from the full URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      // The path after /storage/v1/object/public/{bucket}/
      final bucketIndex =
          pathSegments.indexOf(AppConstants.postImagesBucket);
      if (bucketIndex == -1) return;

      final filePath =
          pathSegments.sublist(bucketIndex + 1).join('/');

      await _client.storage
          .from(AppConstants.postImagesBucket)
          .remove([filePath]);
    } catch (e) {
      // Silently fail — image may already be deleted
    }
  }
}
