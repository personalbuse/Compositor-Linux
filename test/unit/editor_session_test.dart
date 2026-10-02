import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:compositor/core/model.dart';
import 'package:compositor/core/session/editor_session.dart';
import 'package:compositor/core/brush/brush_dab.dart';

CanvasDocument _makeDocument() {
  final rgba = Uint8List(10 * 10 * 4);
  for (int i = 0; i < rgba.length; i += 4) {
    rgba[i + 3] = 0;
  }
  const layerId = 'LAYER1';
  return CanvasDocument(
    id: 'DOC1',
    width: 10,
    height: 10,
    activeLayerID: layerId,
    layers: [
      ImageLayer(
        id: layerId,
        name: 'Background',
        asset: ImportedImage(name: 'bg', rgba: rgba, width: 10, height: 10),
        transform: LayerTransform(
          originX: 0,
          originY: 0,
          sizeWidth: 10,
          sizeHeight: 10,
        ),
      ),
    ],
  );
}

void main() {
  group('EditorSession', () {
    late EditorSession session;

    setUp(() {
      session = EditorSession();
      session.setDocument(_makeDocument());
    });

    tearDown(() {
      session.dispose();
    });

    test('sets and closes document', () {
      expect(session.document, isNotNull);
      expect(session.hasUnsavedChanges, isFalse);

      session.closeDocument();
      expect(session.document, isNull);
    });

    test('visibility change is undoable', () {
      session.setLayerVisibility('LAYER1', false);
      expect(session.document!.layers.first.isVisible, isFalse);
      expect(session.canUndo, isTrue);

      session.undo();
      expect(session.document!.layers.first.isVisible, isTrue);

      session.redo();
      expect(session.document!.layers.first.isVisible, isFalse);
    });

    test('opacity change is undoable', () {
      session.setLayerOpacity('LAYER1', 0.25);
      expect(session.document!.layers.first.opacity, closeTo(0.25, 0.001));

      session.undo();
      expect(session.document!.layers.first.opacity, closeTo(1.0, 0.001));
    });

    test('blend mode change is undoable', () {
      session.setLayerBlendMode('LAYER1', BlendMode.multiply);
      expect(session.document!.layers.first.blendMode, BlendMode.multiply);

      session.undo();
      expect(session.document!.layers.first.blendMode, BlendMode.normal);
    });

    test('add and remove layer are undoable', () {
      final newLayer = ImageLayer(
        id: 'LAYER2',
        name: 'Layer 2',
        asset: ImportedImage(
          name: 'l2',
          rgba: Uint8List(10 * 10 * 4),
          width: 10,
          height: 10,
        ),
        transform: LayerTransform(
          originX: 0,
          originY: 0,
          sizeWidth: 10,
          sizeHeight: 10,
        ),
      );

      session.addLayer(newLayer);
      expect(session.document!.layers.length, 2);

      session.undo();
      expect(session.document!.layers.length, 1);
    });

    test('duplicate layer is undoable', () {
      session.duplicateLayer('LAYER1');
      expect(session.document!.layers.length, 2);

      session.undo();
      expect(session.document!.layers.length, 1);
    });

    test('reorder layer is undoable', () {
      session.addLayer(ImageLayer(
        id: 'LAYER2',
        name: 'Layer 2',
        asset: ImportedImage(
          name: 'l2',
          rgba: Uint8List(10 * 10 * 4),
          width: 10,
          height: 10,
        ),
        transform: LayerTransform(
          originX: 0,
          originY: 0,
          sizeWidth: 10,
          sizeHeight: 10,
        ),
      ));

      final originalOrder = session.document!.layers.map((l) => l.id).toList();
      session.reorderLayer(0, 1);
      expect(session.document!.layers.first.id, 'LAYER2');

      session.undo();
      expect(session.document!.layers.map((l) => l.id).toList(), originalOrder);
    });

    test('brush stroke paints pixels and is undoable', () {
      final dab = BrushDab(
        x: 5,
        y: 5,
        size: 6,
        hardness: 1.0,
        opacity: 1.0,
        color: const Color(0xFFFF0000),
      );

      session.applyBrushStroke([dab]);

      final rgba = session.document!.layers.first.asset!.rgba;
      const centerIdx = (5 * 10 + 5) * 4;
      expect(rgba[centerIdx + 3], greaterThan(0));
      expect(session.canUndo, isTrue);

      session.undo();
      final undoneAlpha = session.document!.layers.first.asset!.rgba[centerIdx + 3];
      expect(undoneAlpha, 0);
    });

    test('erase reduces alpha', () {
      final paintDab = BrushDab(
        x: 5,
        y: 5,
        size: 10,
        hardness: 1.0,
        opacity: 1.0,
        color: const Color(0xFFFFFFFF),
      );
      session.applyBrushStroke([paintDab]);

      final eraseDab = BrushDab(
        x: 5,
        y: 5,
        size: 10,
        hardness: 1.0,
        opacity: 1.0,
        color: const Color(0x00000000),
      );
      session.applyBrushStroke([eraseDab], isEraser: true);

      final rgba = session.document!.layers.first.asset!.rgba;
      const centerIdx = (5 * 10 + 5) * 4;
      expect(rgba[centerIdx + 3], 0);
    });

    test('markDirty and markClean toggle unsaved changes', () {
      expect(session.hasUnsavedChanges, isFalse);
      session.markDirty();
      expect(session.hasUnsavedChanges, isTrue);
      session.markClean();
      expect(session.hasUnsavedChanges, isFalse);
    });
  });
}