import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../../core/model.dart';
import '../image/image_importer.dart';

class ProjectStore {
  static Future<CanvasDocument> readComp(Directory compDir) async {
    final manifestFile = File(path.join(compDir.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw ProjectStoreException('manifest.json not found in ${compDir.path}');
    }

    final manifestContent = await manifestFile.readAsString();
    final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

    _validateManifest(manifest);

    final version = manifest['version'] as int? ?? 1;
    if (version < 1 || version > 11) {
      throw ProjectStoreException('Unsupported format version: $version');
    }

    final doc = CanvasDocument.fromJson(manifest);

    final imagesDir = Directory(path.join(compDir.path, 'images'));
    if (await imagesDir.exists()) {
      await _loadLayerImages(doc, imagesDir);
    }

    DocumentLimits.validateDimensions(doc.width, doc.height);
    DocumentLimits.validateLayerCount(doc.layers.length);
    DocumentLimits.validateGuideCount(doc.guides.length);
    DocumentLimits.validateNestingDepth(doc.layers, 0);

    return doc;
  }

  static Future<void> writeComp(CanvasDocument doc, Directory compDir, {bool overwrite = false}) async {
    if (await compDir.exists()) {
      if (!overwrite) {
        throw ProjectStoreException('Directory already exists: ${compDir.path}');
      }
      await compDir.delete(recursive: true);
    }
    await compDir.create(recursive: true);

    final imagesDir = Directory(path.join(compDir.path, 'images'));
    await imagesDir.create();

    for (final layer in doc.layers) {
      if (layer.asset != null && !layer.isGroup) {
        await _writeLayerImage(layer, imagesDir);
      }
    }

    final manifest = doc.toJson();
    final manifestFile = File(path.join(compDir.path, 'manifest.json'));
    final tmpFile = File('${manifestFile.path}.tmp');

    const encoder = JsonEncoder.withIndent('  ');
    await tmpFile.writeAsString(encoder.convert(manifest));
    await tmpFile.rename(manifestFile.path);
  }

  static Future<void> _loadLayerImages(CanvasDocument doc, Directory imagesDir) async {
    for (final layer in doc.layers) {
      if (layer.isGroup) continue;
      if (layer.asset != null) continue;

      final imageFile = '${layer.id}.png';
      final imagePath = path.join(imagesDir.path, imageFile);

      final imageFileExists = await File(imagePath).exists();
      if (!imageFileExists) {
        throw ProjectStoreException('Layer image not found: $imageFile');
      }

      final imageBytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        throw ProjectStoreException('Failed to decode image: $imageFile');
      }

      final rgba = premultipliedRgbaFromImage(decoded);

      layer.asset = ImportedImage(
        name: imageFile,
        rgba: rgba,
        width: decoded.width,
        height: decoded.height,
        sourcePath: imagePath,
      );
    }
  }

  static Future<void> _writeLayerImage(ImageLayer layer, Directory imagesDir) async {
    if (layer.asset == null || layer.isGroup) return;

    final imageFile = '${layer.id}.png';
    final imagePath = path.join(imagesDir.path, imageFile);

    final image = img.Image.fromBytes(
      width: layer.asset!.width,
      height: layer.asset!.height,
      bytes: layer.asset!.rgba.buffer,
    );

    final pngBytes = img.encodePng(image);
    await File(imagePath).writeAsBytes(pngBytes);

    if (layer.mask != null && layer.mask!.maskEnabled && layer.mask!.maskFile != null) {
      final maskPath = path.join(imagesDir.path, layer.mask!.maskFile!);
      if (await File(maskPath).exists()) {
        // Mask already exists, keep it (round-trip)
      }
    }
  }

  static void _validateManifest(Map<String, dynamic> manifest) {
    if (manifest['format'] != 'com.compositor.project') {
      throw ProjectStoreException('Invalid format identifier');
    }
    if (manifest['width'] == null || manifest['height'] == null) {
      throw ProjectStoreException('Missing width/height in manifest');
    }
    if (manifest['layers'] == null) {
      throw ProjectStoreException('Missing layers in manifest');
    }
  }
}

class ProjectStoreException implements Exception {
  final String message;
  ProjectStoreException(this.message);
  @override
  String toString() => 'ProjectStoreException: $message';
}