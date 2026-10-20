import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/pin_model.dart';
import '../services/api_service.dart';
import 'profile_avatar.dart';

class PinGrid extends StatelessWidget {
  const PinGrid({
    required this.pins,
    required this.onOpenPin,
    required this.onToggleSave,
    required this.onOpenProfile,
    super.key,
  });

  final List<PinModel> pins;
  final ValueChanged<PinModel> onOpenPin;
  final ValueChanged<PinModel> onToggleSave;
  final ValueChanged<int> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: pins.length,
      itemBuilder: (context, index) {
        return PinGridItem(
          pin: pins[index],
          onOpenPin: onOpenPin,
          onToggleSave: onToggleSave,
          onOpenProfile: onOpenProfile,
        );
      },
    );
  }
}

class PinGridItem extends StatelessWidget {
  const PinGridItem({
    required this.pin,
    required this.onOpenPin,
    required this.onToggleSave,
    required this.onOpenProfile,
    super.key,
  });

  final PinModel pin;
  final ValueChanged<PinModel> onOpenPin;
  final ValueChanged<PinModel> onToggleSave;
  final ValueChanged<int> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final imageUrl = ApiService.resolveImageUrl(pin.imageUrl);
    final aspectRatio = switch (pin.id % 3) {
      0 => 0.78,
      1 => 0.92,
      _ => 0.68,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              InkWell(
                onTap: () => onOpenPin(pin),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Hero(
                    tag: 'pin-image-${pin.id}',
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ColoredBox(
                        color: Color(0xFFF1F1F1),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF777777),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: Color(0xFFF1F1F1),
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF777777),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: pin.isSaved ? 'Hapus dari simpanan' : 'Simpan',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onToggleSave(pin),
                    icon: Icon(
                      pin.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: pin.isSaved
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF111111),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: InkWell(
              onTap: () => onOpenPin(pin),
              child: Text(
                pin.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (pin.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
              child: Text(
                pin.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 4, 9, 10),
            child: InkWell(
              onTap: pin.user == null
                  ? null
                  : () => onOpenProfile(pin.user!.id),
              borderRadius: BorderRadius.circular(30),
              child: Row(
                children: [
                  ProfileAvatar(
                    name: pin.user?.name ?? 'Pinterus',
                    imageUrl: pin.user?.avatarUrl,
                    radius: 13,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      pin.user?.username ?? 'Pinterus',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
