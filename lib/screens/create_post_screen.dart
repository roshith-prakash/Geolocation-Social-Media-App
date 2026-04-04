import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => CreatePostScreenState();
}

class CreatePostScreenState extends State<CreatePostScreen> {
  final contentController = TextEditingController();
  final locationService = LocationService();
  final supabaseService = SupabaseService();
  final storageService = StorageService();
  final imagePicker = ImagePicker();

  Position? currentPosition;
  File? selectedImage;
  bool isLoading = false;
  bool isGettingLocation = true;
  String? supabaseUserId;

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final user = await supabaseService.getUserByFirebaseUid(firebaseUser.uid);
      supabaseUserId = user?.id;
    }

    try {
      final position = await locationService.getCurrentPosition();
      setState(() {
        currentPosition = position;
        isGettingLocation = false;
      });
    } catch (e) {
      setState(() => isGettingLocation = false);
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await imagePicker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  Future<void> createPost() async {
    if (contentController.text.trim().isEmpty && selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add text or an image')),
      );
      return;
    }
    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
      return;
    }
    if (supabaseUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile not found')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      String? imageUrl;
      if (selectedImage != null) {
        imageUrl = await storageService.uploadPostImage(selectedImage!);
      }

      await supabaseService.createPost(
        userId: supabaseUserId!,
        content: contentController.text.trim().isNotEmpty
            ? contentController.text.trim()
            : null,
        imageUrl: imageUrl,
        latitude: currentPosition!.latitude,
        longitude: currentPosition!.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created!')),
        );
        contentController.clear();
        setState(() => selectedImage = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: isLoading ? null : createPost,
            child: isLoading
                ? const Text('Posting...')
                : const Text('Post'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location info
            Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 8),
                if (isGettingLocation)
                  const Text('Getting your location...')
                else if (currentPosition != null)
                  Text(
                    '${currentPosition!.latitude.toStringAsFixed(4)}, '
                    '${currentPosition!.longitude.toStringAsFixed(4)}',
                  )
                else
                  const Text('Location unavailable'),
                if (isGettingLocation) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Content text field
            TextField(
              controller: contentController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "What's happening here?",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Selected image preview
            if (selectedImage != null) ...[
              Image.file(
                selectedImage!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
              TextButton.icon(
                onPressed: () => setState(() => selectedImage = null),
                icon: const Icon(Icons.close),
                label: const Text('Remove image'),
              ),
              const SizedBox(height: 8),
            ],

            // Image picker buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
