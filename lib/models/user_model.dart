class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.bio,
    required this.avatarUrl,
    required this.followersCount,
    required this.followingCount,
    required this.pinsCount,
    this.isPrivate = false,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String bio;
  final String? avatarUrl;
  final int followersCount;
  final int followingCount;
  final int pinsCount;
  final bool isPrivate;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final username = json['username'] as String?;

    return UserModel(
      id: id,
      name: json['name'] as String? ?? 'Pengguna Pinterus',
      username: username?.isNotEmpty == true ? username! : 'pengguna$id',
      email: json['email'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      pinsCount: (json['pins_count'] as num?)?.toInt() ?? 0,
      isPrivate: json['private_account'] as bool? ?? false,
    );
  }
}
