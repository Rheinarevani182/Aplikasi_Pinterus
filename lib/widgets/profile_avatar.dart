import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.name,
    this.imageUrl,
    this.radius = 18,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      foregroundImage: url == null || url.isEmpty
          ? null
          : NetworkImage(ApiService.resolveImageUrl(url)),
      onForegroundImageError: url == null || url.isEmpty ? null : (_, _) {},
      child: ClipOval(
        child: Image.asset(
          'assets/images/pinterus_logo.jpg',
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
