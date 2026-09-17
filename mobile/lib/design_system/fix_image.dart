import 'dart:typed_data';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:flutter/material.dart';

/// Reusable Image & Avatar component that obeys FixNow data integrity rules:
/// 1. Uses genuine backend URLs or raw bytes when available.
/// 2. If unavailable, loading, or on network error: renders a clean, authentic
///    monogram, category icon, or minimal placeholder state.
/// 3. Never loads random remote stock photos or fake placeholder images.
class FixImage extends StatelessWidget {
  const FixImage({
    this.imageUrl,
    this.bytes,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackIcon = Icons.home_repair_service_rounded,
    this.fallbackLabel,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    super.key,
  });

  final String? imageUrl;
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final String? fallbackLabel;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(12);

    Widget content;
    if (bytes != null && bytes!.isNotEmpty) {
      content = Image.memory(
        bytes!,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    } else if (imageUrl != null && imageUrl!.trim().isNotEmpty && imageUrl!.startsWith('http')) {
      content = Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: AppColors.surfaceContainerLow,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    } else {
      content = _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: content,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceContainerLow,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              fallbackIcon,
              size: (width != null && width! < 60) ? 22 : 32,
              color: AppColors.primaryEmerald,
            ),
            if (fallbackLabel != null && (height == null || height! >= 70)) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  fallbackLabel!,
                  style: FixNowTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Circular avatar with monogram initials or verified technician badge
class FixAvatar extends StatelessWidget {
  const FixAvatar({
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.verified = false,
    this.role,
    super.key,
  });

  final String? imageUrl;
  final String? name;
  final double radius;
  final bool verified;
  final String? role;

  String get _initials {
    if (name == null || name!.trim().isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    Widget avatarContent;
    if (imageUrl != null && imageUrl!.trim().isNotEmpty && imageUrl!.startsWith('http')) {
      avatarContent = Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildMonogram(),
      );
    } else {
      avatarContent = _buildMonogram();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: avatarContent,
          ),
        ),
        if (verified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppColors.primaryEmerald,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonogram() {
    return Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
