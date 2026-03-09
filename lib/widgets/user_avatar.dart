import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/theme.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String username;
  final double radius;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.username,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.cardDark,
        backgroundImage: CachedNetworkImageProvider(imageUrl!),
      );
    }

    // Fallback: initials with gradient background
    final initials = username.isNotEmpty
        ? username[0].toUpperCase()
        : '?';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
