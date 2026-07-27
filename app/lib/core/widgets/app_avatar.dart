import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular avatar with a cached network image, falling back to initials
/// over the brand color when there's no photo yet.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.photoUrl, this.name, this.radius = 20});

  final String? photoUrl;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => _Initials(name: name, radius: radius),
          ),
        ),
      );
    }

    return _Initials(name: name, radius: radius);
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.radius});

  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = name?.trim() ?? '';
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.isNotEmpty ? part[0].toUpperCase() : '')
              .join();

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
