class PostModel {
  final String id;
  final String userId;
  final String? content;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String? authorUsername;
  final String? authorImage;
  final double? distance; // distance in meters from query point
  final int likeCount;

  PostModel({
    required this.id,
    required this.userId,
    this.content,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.authorUsername,
    this.authorImage,
    this.distance,
    this.likeCount = 0,
  });

  /// From the RPC `get_nearby_posts` result
  static PostModel fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      authorUsername: json['username'] as String?,
      authorImage: json['profile_image'] as String?,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'content': content,
      'image_url': imageUrl,
      // PostGIS point: ST_MakePoint(lng, lat)
      'location': 'POINT($longitude $latitude)',
    };
  }

  String get distanceLabel {
    if (distance == null) return '';
    if (distance! < 1000) {
      return '${distance!.round()} m away';
    } else {
      return '${(distance! / 1000).toStringAsFixed(1)} km away';
    }
  }
}
