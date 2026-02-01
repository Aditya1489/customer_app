import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_sync/services/api_service.dart';

class UniversalImage extends ConsumerWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String placeholder;

  const UniversalImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder = 'https://picsum.photos/400/300',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (imagePath == null || imagePath!.isEmpty) {
      return _buildPlaceholder();
    }

    // Use ApiService to resolve the URL (handles server paths vs full URLs vs local files)
    final resolvedPath = ref.read(apiServiceProvider).resolveUrl(imagePath);
    
    // Debug logging to help identify broken image paths
    if (imagePath != null && imagePath!.isNotEmpty) {
      debugPrint('UniversalImage: [Original: $imagePath] -> [Resolved: $resolvedPath]');
    }

    if (resolvedPath == null) {
       return _buildPlaceholder();
    }

    if (resolvedPath.startsWith('http')) {
      // Basic validation for host
      try {
        final uri = Uri.parse(resolvedPath);
        if (!uri.hasScheme || !uri.hasAuthority) {
          return _buildPlaceholder();
        }
      } catch (e) {
        return _buildPlaceholder();
      }

      return Image.network(
        resolvedPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    }

    // For local files (which resolveUrl returns as-is if not http/server path)
    if (File(resolvedPath).existsSync()) {
      return Image.file(
        File(resolvedPath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Image.network(
      placeholder,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width, 
        height: height, 
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }
}
