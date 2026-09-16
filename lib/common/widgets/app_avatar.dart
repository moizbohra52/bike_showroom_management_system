import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A circular avatar backed by a photo, falling back to initials on a
/// deterministic colour when there is no image (or it fails to load).
///
/// Used for user avatars, customer initials and the showroom switcher, so the
/// same fallback logic (and thus the same colour for the same name) is not
/// reimplemented at every call site.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.imageUrl,
    this.size = 36,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double size;

  String get _initials {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  /// A stable colour derived from the name, so the same person's avatar looks
  /// the same everywhere without storing a colour choice anywhere.
  Color get _backgroundColor {
    final int hash = name.codeUnits.fold<int>(0, (int a, int b) => a + b);
    return AppColors.chartSeries[hash % AppColors.chartSeries.length];
  }

  @override
  Widget build(BuildContext context) {
    final Widget fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: _backgroundColor.withValues(alpha: 0.16),
      child: Text(
        _initials,
        style: TextStyle(
          color: _backgroundColor,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
        ),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (BuildContext context, String url) => fallback,
        errorWidget: (BuildContext context, String url, Object error) =>
            fallback,
      ),
    );
  }
}
