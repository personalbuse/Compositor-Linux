import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:compositor/io/comp.dart';
import 'package:compositor/core/model.dart';

void main() {
  group('ProjectStore round-trip', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('compositor_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('write and read minimal document', () async {
      final doc = CanvasDocument(
        id: 'TEST-DOC-123',
        width: 800,
        height: 600,
        resolution: 72,
        layers: [
          ImageLayer(
            id: 'LAYER-1',
            name: 'Background',
            transform: LayerTransform(
              originX: 0,
              originY: 0,
              sizeWidth: 800,
              sizeHeight: 600,
            ),
            asset: ImportedImage(
              name: 'LAYER-1.png',
              rgba: Uint8List(800 * 600 * 4),
              width: 800,
              height: 600,
            ),
          ),
        ],
      );

      final compDir = Directory(path.join(tempDir.path, 'Test.comp'));
      await ProjectStore.writeComp(doc, compDir);

      expect(await compDir.exists(), isTrue);
      expect(await File(path.join(compDir.path, 'manifest.json')).exists(), isTrue);
      expect(await File(path.join(compDir.path, 'images', 'LAYER-1.png')).exists(), isTrue);

      final readDoc = await ProjectStore.readComp(compDir);
      expect(readDoc.id, equals(doc.id));
      expect(readDoc.width, equals(doc.width));
      expect(readDoc.height, equals(doc.height));
      expect(readDoc.layers.length, equals(1));
      expect(readDoc.layers[0].id, equals('LAYER-1'));
    });

    test('preserves unknown fields in manifest', () async {
      final doc = CanvasDocument(
        id: 'TEST-DOC',
        width: 100,
        height: 100,
        unknown: {'customField': 'customValue'},
        layers: [
          ImageLayer(
            id: 'LAYER-1',
            name: 'Layer',
            transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100),
            unknown: {'layerCustom': 'value'},
          ),
        ],
      );

      final compDir = Directory(path.join(tempDir.path, 'Test.comp'));
      await ProjectStore.writeComp(doc, compDir);

      final manifestFile = File(path.join(compDir.path, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      
      expect(manifest['customField'], equals('customValue'));
      expect(manifest['layers'][0]['layerCustom'], equals('value'));
    });

    test('preserves adjustment, effects, shape, text fields', () async {
      final doc = CanvasDocument(
        id: 'TEST-DOC',
        width: 100,
        height: 100,
        layers: [
          ImageLayer(
            id: 'LAYER-1',
            name: 'Layer',
            transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100),
            adjustment: {'type': 'levels', 'inputBlack': 10},
            effects: {'dropShadow': {'radius': 5}},
            shape: {'cornerRadius': 3},
            text: {'fontSize': 12},
            asset: ImportedImage(
              name: 'LAYER-1.png',
              rgba: Uint8List(100 * 100 * 4),
              width: 100,
              height: 100,
            ),
          ),
        ],
      );

      final compDir = Directory(path.join(tempDir.path, 'Test.comp'));
      await ProjectStore.writeComp(doc, compDir);

      final readDoc = await ProjectStore.readComp(compDir);
      final layer = readDoc.layers[0];
      expect(layer.adjustment['type'], equals('levels'));
      expect(layer.effects['dropShadow']['radius'], equals(5));
      expect(layer.shape['cornerRadius'], equals(3));
      expect(layer.text['fontSize'], equals(12));
    });

    test('writes version 11 manifest', () async {
      final doc = CanvasDocument(
        id: 'TEST-DOC',
        width: 100,
        height: 100,
        layers: [
          ImageLayer(
            id: 'LAYER-1',
            name: 'Layer',
            transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100),
          ),
        ],
      );

      final compDir = Directory(path.join(tempDir.path, 'Test.comp'));
      await ProjectStore.writeComp(doc, compDir);

      final manifestFile = File(path.join(compDir.path, 'manifest.json'));
      final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      expect(manifest['version'], equals(11));
      expect(manifest['format'], equals('com.compositor.project'));
      expect(manifest['colorSpace'], equals('sRGB'));
    });

    test('atomic write - tmp file renamed', () async {
      final doc = CanvasDocument(
        id: 'TEST-DOC',
        width: 100,
        height: 100,
        layers: [
          ImageLayer(
            id: 'LAYER-1',
            name: 'Layer',
            transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100),
          ),
        ],
      );

      final compDir = Directory(path.join(tempDir.path, 'Test.comp'));
      await ProjectStore.writeComp(doc, compDir);

      // Check no .tmp file remains
      final tmpFiles = await compDir.list().where((f) => f.path.endsWith('.tmp')).toList();
      expect(tmpFiles, isEmpty);
    });

    test('handles groups correctly', () async {
      final doc = CanvasDocument(
        id: 'TEST-DOC',
        width: 100,
        height: 100,
        layers: [
          ImageLayer(
            id: 'GROUP-1',
            name: 'Group',
            transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100),
            isGroup: true,
          ),
          ImageLayer(
            id: 'LAYER-1',
            name: 'Child',
            transform: LayerTransform(originX: 10, originY: 10, sizeWidth: 50, sizeHeight: 50),
            parentID: 'GROUP-1',
            asset: ImportedImage(
              name: 'LAYER-1.png',
              rgba: Uint8List(50 * 50 * 4),
              width: 50,
              height: 50,
            ),
          ),
        ],
      );

      final compDir = Directory(path.join(tempDir.path, 'Test.comp'));
      await ProjectStore.writeComp(doc, compDir);

      final readDoc = await ProjectStore.readComp(compDir);
      expect(readDoc.layers.length, equals(2));
      expect(readDoc.layers[0].isGroup, isTrue);
      expect(readDoc.layers[1].parentID, equals('GROUP-1'));
    });
  });
}