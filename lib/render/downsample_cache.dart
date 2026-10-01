import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'surface.dart';
import '../core/model.dart';

class DownsampleCache {
  final Map<String, _ImagePyramid> _cache = {};
  final int _maxPixels;
  int _currentPixels = 0;

  DownsampleCache({int maxPixels = 200_000_000}) : _maxPixels = maxPixels;

  Uint8List? getLevel(String imageId, int level, int srcWidth, int srcHeight,
                      Uint8List srcRgba, int srcStride) {
    final pyramid = _cache.putIfAbsent(imageId, () => _ImagePyramid(imageId));
    final oldTotal = pyramid.totalPixels;
    final result = pyramid.getLevel(level, srcWidth, srcHeight, srcRgba, srcStride);
    _currentPixels += pyramid.totalPixels - oldTotal;
    return result;
  }

  void invalidate(String imageId) {
    final pyramid = _cache.remove(imageId);
    if (pyramid != null) {
      _currentPixels -= pyramid.totalPixels;
    }
  }

  void clear() {
    _cache.clear();
    _currentPixels = 0;
  }

  int get currentPixels => _currentPixels;
  int get maxPixels => _maxPixels;
}

class _ImagePyramid {
  final String imageId;
  final List<_PyramidLevel> levels = [];
  int totalPixels = 0;
  int lastAccess = 0;
  static int _globalAccessCounter = 0;

  _ImagePyramid(this.imageId);

  Uint8List? getLevel(int level, int srcWidth, int srcHeight,
                      Uint8List srcRgba, int srcStride) {
    lastAccess = _globalAccessCounter++;
    
    if (level == 0) {
      return srcRgba;
    }

    while (levels.length <= level) {
      final prevLevel = levels.isEmpty ? 0 : levels.length - 1;
      final prev = prevLevel == 0 ? srcRgba : levels[prevLevel].rgba;
      final prevW = prevLevel == 0 ? srcWidth : levels[prevLevel].width;
      final prevH = prevLevel == 0 ? srcHeight : levels[prevLevel].height;
      final prevStride = prevLevel == 0 ? srcStride : levels[prevLevel].stride;

      final newW = (prevW + 1) ~/ 2;
      final newH = (prevH + 1) ~/ 2;
      final newStride = newW * 4;
      final dst = Uint8List(newH * newStride);

      final result = Resample.halvingRgba(prev, prevW, prevH, prevStride, dst, newStride);
      if (result != 0) {
        return null;
      }

      Resample.clampPremultiplied(dst);

      final newLevel = _PyramidLevel(
        level: levels.length,
        width: newW,
        height: newH,
        stride: newStride,
        rgba: dst,
      );
      levels.add(newLevel);
      totalPixels += newW * newH;
    }

    if (level < levels.length) {
      return levels[level].rgba;
    }
    return null;
  }

  int getLevelForFactor(double factor) {
    if (factor >= 0.5 || factor <= 0) return 0;
    final level = (log(1 / factor) / ln2).floor();
    return level.clamp(0, 6);
  }
}

class _PyramidLevel {
  final int level;
  final int width;
  final int height;
  final int stride;
  final Uint8List rgba;

  _PyramidLevel({
    required this.level,
    required this.width,
    required this.height,
    required this.stride,
    required this.rgba,
  });
}