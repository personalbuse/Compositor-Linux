import 'dart:typed_data';
import '../core/native_bindings.dart';

class Surface {
  final int width;
  final int height;
  final Uint8List rgba;
  final int stride;

  Surface({
    required this.width,
    required this.height,
    Uint8List? rgba,
  }) : stride = width * 4,
       rgba = rgba ?? Uint8List(width * height * 4);

  factory Surface.alloc(int width, int height) {
    return Surface(width: width, height: height);
  }

  void fill(int r, int g, int b, int a) {
    for (int i = 0; i < rgba.length; i += 4) {
      rgba[i] = r;
      rgba[i + 1] = g;
      rgba[i + 2] = b;
      rgba[i + 3] = a;
    }
  }

  void clear() {
    rgba.fillRange(0, rgba.length, 0);
  }

  void copyFrom(Surface src) {
    if (src.width != width || src.height != height) {
      throw ArgumentError('Surface dimensions must match');
    }
    rgba.setRange(0, rgba.length, src.rgba);
  }

  void blit(Surface src, int srcX, int srcY, int dstX, int dstY, int w, int h) {
    if (srcX + w > src.width || srcY + h > src.height) {
      throw ArgumentError('Source rect out of bounds');
    }
    if (dstX + w > width || dstY + h > height) {
      throw ArgumentError('Destination rect out of bounds');
    }

    for (int y = 0; y < h; y++) {
      final srcOffset = (srcY + y) * src.stride + srcX * 4;
      final dstOffset = (dstY + y) * stride + dstX * 4;
      rgba.setRange(dstOffset, dstOffset + w * 4, src.rgba, srcOffset);
    }
  }

  Surface resize(int newWidth, int newHeight) {
    final dst = Surface.alloc(newWidth, newHeight);
    final xRatio = width / newWidth;
    final yRatio = height / newHeight;

    for (int y = 0; y < newHeight; y++) {
      for (int x = 0; x < newWidth; x++) {
        final srcX = (x * xRatio).floor().clamp(0, width - 1);
        final srcY = (y * yRatio).floor().clamp(0, height - 1);
        final srcOffset = srcY * stride + srcX * 4;
        final dstOffset = y * dst.stride + x * 4;
        dst.rgba.setRange(dstOffset, dstOffset + 4, rgba, srcOffset);
      }
    }
    return dst;
  }

  int get byteCount => rgba.length;
}

class Mask {
  final int width;
  final int height;
  final Uint8List gray;
  final int stride;

  Mask({
    required this.width,
    required this.height,
    Uint8List? gray,
  }) : stride = width,
       gray = gray ?? Uint8List(width * height);

  factory Mask.alloc(int width, int height) {
    return Mask(width: width, height: height);
  }

  void fill(int value) {
    gray.fillRange(0, gray.length, value.clamp(0, 255));
  }
}

class Resample {
  static const int nearest = 0;
  static const int bilinear = 1;
  static const int lanczos3 = 2;

  static int halvingRgba(Uint8List src, int srcW, int srcH, int srcStride,
                         Uint8List dst, int dstStride) {
    return NativeBindings.halvingRgba(src, srcW, srcH, srcStride, dst, dstStride);
  }

  static int halvingGray(Uint8List src, int srcW, int srcH, int srcStride,
                         Uint8List dst, int dstStride) {
    return NativeBindings.halvingGray(src, srcW, srcH, srcStride, dst, dstStride);
  }

  static int resampleRgba(Uint8List src, int srcW, int srcH, int srcStride,
                          Uint8List dst, int dstW, int dstH, int dstStride, int method) {
    return NativeBindings.resampleRgba(src, srcW, srcH, srcStride, dst, dstW, dstH, dstStride, method);
  }

  static int resampleGray(Uint8List src, int srcW, int srcH, int srcStride,
                          Uint8List dst, int dstW, int dstH, int dstStride, int method) {
    return NativeBindings.resampleGray(src, srcW, srcH, srcStride, dst, dstW, dstH, dstStride, method);
  }

  static void clampPremultiplied(Uint8List rgba) {
    NativeBindings.rgbaClampPremultiplied(rgba);
  }
}

class Compositor {
  static void compositeLayer(Uint8List src, int srcStride,
                             Uint8List dst, int dstStride,
                             int width, int height,
                             double opacity, int mode,
                             Uint8List? mask, int maskStride) {
    NativeBindings.compositeLayer(src, srcStride, dst, dstStride,
                                  width, height, opacity, mode, mask, maskStride);
  }

  static void blendPixel(Uint8List dst, Uint8List src, int mode) {
    NativeBindings.blendPixel(dst, src, mode);
  }
}