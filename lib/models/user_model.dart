class UserModel {
  final String id;
  final String firebaseUid;
  final String username;
  final String email;
  final String? profileImage;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.firebaseUid,
    required this.username,
    required this.email,
    this.profileImage,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      firebaseUid: json['firebase_uid'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      profileImage: json['profile_image'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firebase_uid': firebaseUid,
      'username': username,
      'email': email,
      'profile_image': profileImage,
    };
  }

  UserModel copyWith({
    String? id,
    String? firebaseUid,
    String? username,
    String? email,
    String? profileImage,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
