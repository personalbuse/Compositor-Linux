import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import '../../core/model.dart';

/// Decodes loose image files (PNG/JPEG/...) into [ImportedImage] assets.
class ImageImporter {
  /// Extensions accepted by the Open dialog / importer.
  static const Set<String> supportedExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
    'gif',
  };

  static bool hasImageExtension(String filePath) {
    final ext = path.extension(filePath).replaceFirst('.', '').toLowerCase();
    return supportedExtensions.contains(ext);
  }

  static Future<ImportedImage> fromFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return fromBytes(bytes, name: path.basename(filePath), sourcePath: filePath);
  }

  static ImportedImage fromBytes(
    Uint8List bytes, {
    String? name,
    String? sourcePath,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (e) {
      throw ImageImportException(
        'Unsupported or corrupt image data${sourcePath != null ? ': $sourcePath' : ''} ($e)',
      );
    }
    if (decoded == null) {
      throw ImageImportException(
        'Unsupported or corrupt image data${sourcePath != null ? ': $sourcePath' : ''}',
      );
    }
    return ImportedImage(
      name: name ?? 'image',
      rgba: premultipliedRgbaFromImage(decoded),
      width: decoded.width,
      height: decoded.height,
      sourcePath: sourcePath,
    );
  }
}

/// Converts a decoded image to straight RGBA8888 premultiplied bytes,
/// the canonical pixel format used across the compositor kernels.
Uint8List premultipliedRgbaFromImage(img.Image image) {
  final rgba = Uint8List(image.width * image.height * 4);
  // Sources may be 16-bit (or float); normalize channels to 8-bit.
  final maxChannel = image.maxChannelValue;
  final toByte = (maxChannel > 0 && maxChannel != 255) ? 255.0 / maxChannel : 1.0;
  int idx = 0;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = (pixel.r * toByte).round().clamp(0, 255);
      final g = (pixel.g * toByte).round().clamp(0, 255);
      final b = (pixel.b * toByte).round().clamp(0, 255);
      final a = (pixel.a * toByte).round().clamp(0, 255);

      if (a == 0) {
        rgba[idx] = 0;
        rgba[idx + 1] = 0;
        rgba[idx + 2] = 0;
        rgba[idx + 3] = 0;
      } else if (a < 255) {
        rgba[idx] = (r * a / 255).round().clamp(0, 255);
        rgba[idx + 1] = (g * a / 255).round().clamp(0, 255);
        rgba[idx + 2] = (b * a / 255).round().clamp(0, 255);
        rgba[idx + 3] = a;
      } else {
        rgba[idx] = r;
        rgba[idx + 1] = g;
        rgba[idx + 2] = b;
        rgba[idx + 3] = 255;
      }
      idx += 4;
    }
  }
  return rgba;
}

class ImageImportException implements Exception {
  final String message;
  ImageImportException(this.message);

  @override
  String toString() => 'ImageImportException: $message';
}
