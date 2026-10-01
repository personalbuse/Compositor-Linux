class DocumentLimits {
  static const int maxSide = 30000;
  static const int maxSingleSurfacePixels = 200_000_000;
  static const int maxManifestBytes = 4 * 1024 * 1024;
  static const int maxAssetBytes = 512 * 1024 * 1024;
  static const int maxLayers = 10_000;
  static const int maxGuides = 1000;
  static const int maxNestingDepth = 64;

  static int documentBudgetPixels(int ramBytes) {
    final ramBased = ramBytes ~/ 16;
    return ramBased.clamp(200_000_000, 800_000_000);
  }

  static void validateDimensions(int width, int height) {
    if (width > maxSide || height > maxSide) {
      throw DocumentLimitException('Document dimensions exceed maxSide ($maxSide)');
    }
    if (width * height > maxSingleSurfacePixels) {
      throw DocumentLimitException('Document surface exceeds maxSingleSurfacePixels');
    }
  }

  static void validateLayerCount(int count) {
    if (count > maxLayers) {
      throw DocumentLimitException('Too many layers (max $maxLayers)');
    }
  }

  static void validateGuideCount(int count) {
    if (count > maxGuides) {
      throw DocumentLimitException('Too many guides (max $maxGuides)');
    }
  }

  static void validateNestingDepth(List<dynamic> layers, int depth) {
    if (depth > maxNestingDepth) {
      throw DocumentLimitException('Nesting depth exceeds max ($maxNestingDepth)');
    }
    for (final layer in layers) {
      if (layer.isGroup == true) {
        final children = layers.where((l) => l.parentID == layer.id).toList();
        validateNestingDepth(children, depth + 1);
      }
    }
  }
}

class DocumentLimitException implements Exception {
  final String message;
  DocumentLimitException(this.message);
  @override
  String toString() => 'DocumentLimitException: $message';
}