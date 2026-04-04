import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

class StorageService {
  final supabase = Supabase.instance.client;
  final uuid = const Uuid();

  /// Upload a post image to Supabase Storage and return the public URL
  Future<String> uploadPostImage(File imageFile) async {
    final fileExtension = imageFile.path.split('.').last;
    final fileName = '${uuid.v4()}.$fileExtension';
    final filePath = 'posts/$fileName';

    await supabase.storage
        .from(AppConstants.postImagesBucket)
        .upload(filePath, imageFile);

    return supabase.storage
        .from(AppConstants.postImagesBucket)
        .getPublicUrl(filePath);
  }

  /// Upload a profile avatar image (upserts) and return the public URL
  Future<String> uploadProfileImage(String path, String userId) async {
    final file = File(path);
    final ext = path.split('.').last;
    final storagePath = 'avatars/$userId.$ext';

    await supabase.storage
        .from(AppConstants.postImagesBucket)
        .upload(storagePath, file,
            fileOptions: const FileOptions(upsert: true));

    return supabase.storage
        .from(AppConstants.postImagesBucket)
        .getPublicUrl(storagePath);
  }

  /// Delete an image from Supabase Storage by its public URL
  Future<void> deleteImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex =
          pathSegments.indexOf(AppConstants.postImagesBucket);
      if (bucketIndex == -1) return;
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      await supabase.storage
          .from(AppConstants.postImagesBucket)
          .remove([filePath]);
    } catch (_) {
      // Silently fail — image may already be deleted
    }
  }
}
