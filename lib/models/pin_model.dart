import 'user_model.dart';

const pinCategories = ['Gaya Hidup', 'Dekorasi', 'Resep', 'Fashion', 'Seni'];

class PinModel {
  const PinModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.linkUrl,
    required this.isSaved,
    required this.user,
    this.category = 'Gaya Hidup',
  });

  final int id;
  final String title;
  final String description;
  final String imageUrl;
  final String? linkUrl;
  final bool isSaved;
  final UserModel? user;
  final String category;

  PinModel copyWith({bool? isSaved}) {
    return PinModel(
      id: id,
      title: title,
      description: description,
      imageUrl: imageUrl,
      linkUrl: linkUrl,
      isSaved: isSaved ?? this.isSaved,
      user: user,
      category: category,
    );
  }

  factory PinModel.fromJson(Map<String, dynamic> json) {
    final owner = json['user'];

    return PinModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      linkUrl: json['link_url'] as String?,
      isSaved: json['is_saved'] as bool? ?? false,
      user: owner is Map<String, dynamic> ? UserModel.fromJson(owner) : null,
      category: json['category'] as String? ?? 'Gaya Hidup',
    );
  }
}
