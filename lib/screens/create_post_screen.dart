import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../utils/theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _locationService = LocationService();
  final _supabaseService = SupabaseService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();

  Position? _currentPosition;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isGettingLocation = true;
  String? _supabaseUserId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // Get current user's Supabase ID
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final user =
          await _supabaseService.getUserByFirebaseUid(firebaseUser.uid);
      _supabaseUserId = user?.id;
    }

    // Get location
    try {
      final position = await _locationService.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add text or an image')),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
      return;
    }

    if (_supabaseUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile not found')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        imageUrl = await _storageService.uploadPostImage(_selectedImage!);
      }

      // Create post
      await _supabaseService.createPost(
        userId: _supabaseUserId!,
        content: _contentController.text.trim().isNotEmpty
            ? _contentController.text.trim()
            : null,
        imageUrl: imageUrl,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created! 📍'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );

        // Reset form
        _contentController.clear();
        setState(() => _selectedImage = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _createPost,
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentCyan,
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.accentCyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isGettingLocation
                        ? const Text(
                            'Getting your location...',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 14),
                          )
                        : _currentPosition != null
                            ? Text(
                                '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 14),
                              )
                            : const Text(
                                'Location unavailable',
                                style: TextStyle(
                                    color: AppTheme.accentOrange, fontSize: 14),
                              ),
                  ),
                  if (_isGettingLocation)
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content text field
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: TextField(
                controller: _contentController,
                maxLines: 6,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 16, height: 1.5),
                decoration: const InputDecoration(
                  hintText: "What's happening here? 📍",
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Selected image preview
            if (_selectedImage != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Image picker buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
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
