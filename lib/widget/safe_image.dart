import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeImage extends StatelessWidget {
  final String? url;
  final double size;
  final BorderRadius? borderRadius;
  final bool isCircular;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  const SafeImage({
    super.key,
    required this.url,
    this.size = 50,
    this.borderRadius,
    this.isCircular = true,
    this.onTap,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = const AssetImage('assets/logo/user.png');

    // ⭐ SAFE: If URL is empty, return fallback immediately
    if (url == null || url!.trim().isEmpty) {
      return _wrapShape(
        Image(
          image: fallback,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    Widget img = CachedNetworkImage(
      imageUrl: url!,
      width: size,
      height: size,
      fit: BoxFit.cover,

      placeholder: (_, __) => _shimmer(),

      errorWidget: (_, __, ___) => Image(
        image: fallback,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),

      fadeInDuration: const Duration(milliseconds: 300),
    );

    return _wrapShape(img);
  }

  Widget _wrapShape(Widget img) {
    Widget shaped = isCircular
        ? ClipOval(child: img)
        : ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            child: img,
          );

    // ⭐ BORDER SUPPORT
    if (borderColor != null && borderWidth > 0) {
      shaped = Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          color: borderColor,
          shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircular ? null : (borderRadius ?? BorderRadius.circular(12)),
        ),
        child: shaped,
      );
    }

    // ⭐ TAP
    if (onTap != null) {
      shaped = GestureDetector(onTap: onTap, child: shaped);
    }

    return shaped;
  }

  Widget _shimmer() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : (borderRadius ?? BorderRadius.circular(12)),
      ),
    );
  }
}
