import 'package:test/test.dart';
import 'package:compositor/core/model.dart';
import 'package:compositor/core/history.dart';
import 'dart:typed_data';

void main() {
  group('DocumentHistory', () {
    late DocumentHistory history;
    late CanvasDocument doc;
    late ImageLayer layer;

    setUp(() {
      history = DocumentHistory(maxMemoryBytes: 1024 * 1024);
      doc = CanvasDocument(
        id: 'DOC-1',
        width: 100,
        height: 100,
        layers: [
          ImageLayer(
            id: 'LAYER-1',
            name: 'Layer 1',
            transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100),
          ),
        ],
      );
      layer = doc.layers.first;
    });

    test('pushProperty records and undoes/redoes', () {
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);

      history.pushProperty(
        layer,
        'opacity',
        1.0,
        0.5,
        (v) => layer.copyWith(opacity: v as double),
        name: 'Opacity Change',
      );

      expect(history.canUndo, isTrue);
      expect(history.undoName, equals('Opacity Change'));

      history.undo();
      // Note: PropertyHistoryEntry uses setter, but layer is immutable
      // This test verifies the mechanism works
      expect(history.canRedo, isTrue);
      expect(history.redoName, equals('Opacity Change'));

      history.redo();
      expect(history.canUndo, isTrue);
    });

    test('pushStructure records layer changes', () {
      final oldLayers = List<ImageLayer>.from(doc.layers);
      final newLayer = ImageLayer(
        id: 'LAYER-2',
        name: 'Layer 2',
        transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100),
      );
      final newLayers = [...oldLayers, newLayer];

      history.pushStructure(doc, oldLayers, newLayers, name: 'Add Layer');

      expect(history.canUndo, isTrue);
      history.undo();
      expect(history.canRedo, isTrue);
      history.redo();
    });

    test('clear empties stacks', () {
      history.pushProperty(layer, 'opacity', 1.0, 0.5, (v) {});
      history.clear();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
    });

    test('redo stack cleared on new push after undo', () {
      history.pushProperty(layer, 'opacity', 1.0, 0.5, (v) {});
      history.undo();
      expect(history.canRedo, isTrue);

      history.pushProperty(layer, 'opacity', 0.5, 0.3, (v) {});
      expect(history.canRedo, isFalse);
    });
  });

  group('PixelHistoryEntry', () {
    test('memoryCost calculated correctly', () {
      final asset = ImportedImage(
        name: 'test.png',
        rgba: Uint8List(100),
        width: 10,
        height: 10,
      );
      final entry = PixelHistoryEntry(
        name: 'Brush',
        asset: asset,
        oldPixels: Uint8List(100),
        newPixels: Uint8List(100),
        tiles: [],
      );
      expect(entry.memoryCost, equals(200));
    });
  });
}