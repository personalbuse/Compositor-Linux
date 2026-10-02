import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:compositor/io/image.dart';

void main() {
  group('ImageImporter', () {
    test('hasImageExtension recognizes image extensions', () {
      expect(ImageImporter.hasImageExtension('a.PNG'), isTrue);
      expect(ImageImporter.hasImageExtension('/tmp/b.jpeg'), isTrue);
      expect(ImageImporter.hasImageExtension('c.webp'), isTrue);
      expect(ImageImporter.hasImageExtension('project.comp'), isFalse);
      expect(ImageImporter.hasImageExtension('notes.txt'), isFalse);
    });

    test('decodes PNG and premultiplies alpha', () {
      final source = img.Image(width: 2, height: 1, numChannels: 4);
      source.setPixelRgba(0, 0, 255, 0, 0, 255);
      source.setPixelRgba(1, 0, 255, 255, 255, 128);

      final png = Uint8List.fromList(img.encodePng(source));
      final imported = ImageImporter.fromBytes(png, name: 'x.png');

      expect(imported.width, 2);
      expect(imported.height, 1);
      expect(imported.rgba.length, 2 * 4);

      // Fully opaque red.
      expect(imported.rgba[0], 255);
      expect(imported.rgba[1], 0);
      expect(imported.rgba[2], 0);
      expect(imported.rgba[3], 255);

      // Half-transparent white becomes premultiplied grey (128,128,128,128).
      expect(imported.rgba[4], 128);
      expect(imported.rgba[5], 128);
      expect(imported.rgba[6], 128);
      expect(imported.rgba[7], 128);
    });

    test('fromFile reads an encoded PNG from disk', () async {
      final source = img.Image(width: 1, height: 1);
      source.setPixelRgba(0, 0, 10, 20, 30, 255);

      final dir = await Directory.systemTemp.createTemp('compositor_import');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/pixel.png');
      await file.writeAsBytes(img.encodePng(source));

      final imported = await ImageImporter.fromFile(file.path);
      expect(imported.width, 1);
      expect(imported.height, 1);
      expect(imported.sourcePath, file.path);
      expect(imported.rgba[0], 10);
      expect(imported.rgba[1], 20);
      expect(imported.rgba[2], 30);
      expect(imported.rgba[3], 255);
    });

    test('rejects invalid data', () {
      expect(
        () => ImageImporter.fromBytes(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<ImageImportException>()),
      );
    });
  });
}
