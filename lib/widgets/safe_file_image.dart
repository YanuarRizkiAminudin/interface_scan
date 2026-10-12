import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A drop-in replacement for `Image.file()` that works on all platforms.
///
/// On Android/iOS/desktop it delegates to `Image.file()`.
/// On Flutter Web `Image.file()` throws an assertion, so we show the
/// [fallback] widget instead (default: a grey placeholder with an icon).
///
/// InterfaceScan is designed for Android, so the web path should never be
/// reached in production. The fallback prevents red crash boxes if the app
/// is accidentally opened in a browser during development.
class SafeFileImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? fallback;

  const SafeFileImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Image.file is not supported on web — show fallback.
      return fallback ?? _defaultFallback();
    }

    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => fallback ?? _defaultFallback(),
    );
  }

  Widget _defaultFallback() => Container(
        width: width,
        height: height,
        color: const Color(0xFFF1F3F4), // AppTheme.surface equivalent
        child: const Center(
          child: Icon(Icons.image_outlined, color: Color(0xFF5F6368), size: 28),
        ),
      );
}
