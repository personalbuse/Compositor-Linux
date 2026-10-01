import 'package:test/test.dart';
import 'package:compositor/core/model.dart';

void main() {
  group('BlendMode', () {
    test('fromJson and toJson round-trip', () {
      for (final mode in BlendMode.values) {
        final json = mode.toJson();
        final parsed = BlendMode.fromJson(json);
        expect(parsed, equals(mode));
      }
    });

    test('unknown mode defaults to normal', () {
      expect(BlendMode.fromJson('Unknown'), equals(BlendMode.normal));
    });

    test('nativeValue matches index', () {
      for (var i = 0; i < BlendMode.values.length; i++) {
        expect(BlendMode.values[i].nativeValue, equals(i));
      }
    });
  });

  group('TransformSampling', () {
    test('fromJson and toJson round-trip', () {
      for (final sampling in TransformSampling.values) {
        final json = sampling.toJson();
        final parsed = TransformSampling.fromJson(json);
        expect(parsed, equals(sampling));
      }
    });
  });

  group('LayerTransform', () {
    test('fromJson and toJson round-trip', () {
      final transform = LayerTransform(
        originX: 100,
        originY: 200,
        sizeWidth: 500,
        sizeHeight: 300,
        rotation: 45,
        flipX: true,
        flipY: false,
        sampling: TransformSampling.smooth,
      );

      final json = transform.toJson();
      final parsed = LayerTransform.fromJson(json);

      expect(parsed.originX, equals(transform.originX));
      expect(parsed.originY, equals(transform.originY));
      expect(parsed.sizeWidth, equals(transform.sizeWidth));
      expect(parsed.sizeHeight, equals(transform.sizeHeight));
      expect(parsed.rotation, equals(transform.rotation));
      expect(parsed.flipX, equals(transform.flipX));
      expect(parsed.flipY, equals(transform.flipY));
      expect(parsed.sampling, equals(transform.sampling));
    });

    test('preserves unknown fields', () {
      final json = {
        'origin': [0, 0],
        'size': [100, 100],
        'customField': 'customValue',
        'anotherField': 42,
      };
      final transform = LayerTransform.fromJson(json);
      expect(transform.unknown['customField'], equals('customValue'));
      expect(transform.unknown['anotherField'], equals(42));

      final output = transform.toJson();
      expect(output['customField'], equals('customValue'));
      expect(output['anotherField'], equals(42));
    });

    test('defaults for missing fields', () {
      final transform = LayerTransform.fromJson({});
      expect(transform.originX, equals(0));
      expect(transform.originY, equals(0));
      expect(transform.sizeWidth, equals(0));
      expect(transform.sizeHeight, equals(0));
      expect(transform.rotation, equals(0));
      expect(transform.flipX, isFalse);
      expect(transform.flipY, isFalse);
      expect(transform.sampling, equals(TransformSampling.highQuality));
    });
  });

  group('LayerMask', () {
    test('fromJson and toJson round-trip', () {
      final mask = LayerMask(
        maskSourceID: 'ABC-123',
        maskFile: 'mask.png',
        maskEnabled: false,
      );

      final json = mask.toJson();
      final parsed = LayerMask.fromJson(json);

      expect(parsed.maskSourceID, equals(mask.maskSourceID));
      expect(parsed.maskFile, equals(mask.maskFile));
      expect(parsed.maskEnabled, equals(mask.maskEnabled));
    });

    test('preserves unknown fields', () {
      final json = {'maskEnabled': true, 'unknownField': 'value'};
      final mask = LayerMask.fromJson(json);
      expect(mask.unknown['unknownField'], equals('value'));
    });
  });

  group('ImageLayer', () {
    test('fromJson and toJson round-trip', () {
      final layer = ImageLayer(
        id: 'TEST-123',
        name: 'Test Layer',
        transform: LayerTransform(
          originX: 0,
          originY: 0,
          sizeWidth: 100,
          sizeHeight: 100,
        ),
        isVisible: true,
        opacity: 0.5,
        blendMode: BlendMode.multiply,
        parentID: 'GROUP-1',
        isGroup: false,
      );

      final json = layer.toJson();
      final parsed = ImageLayer.fromJson(json);

      expect(parsed.id, equals(layer.id));
      expect(parsed.name, equals(layer.name));
      expect(parsed.isVisible, equals(layer.isVisible));
      expect(parsed.opacity, equals(layer.opacity));
      expect(parsed.blendMode, equals(layer.blendMode));
      expect(parsed.parentID, equals(layer.parentID));
      expect(parsed.isGroup, equals(layer.isGroup));
    });

    test('preserves unknown fields including adjustment, effects, shape, text', () {
      final layer = ImageLayer(
        id: 'TEST-123',
        name: 'Test',
        transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100),
        adjustment: {'type': 'levels', 'input': [0, 255]},
        effects: {'dropShadow': {'radius': 10}},
        shape: {'cornerRadius': 5},
        text: {'fontSize': 14},
      );

      final json = layer.toJson();
      final parsed = ImageLayer.fromJson(json);

      expect(parsed.adjustment['type'], equals('levels'));
      expect(parsed.effects['dropShadow']['radius'], equals(10));
      expect(parsed.shape['cornerRadius'], equals(5));
      expect(parsed.text['fontSize'], equals(14));
    });

    test('copyWith creates modified copy', () {
      final layer = ImageLayer(
        id: 'TEST-123',
        name: 'Original',
        transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100),
      );

      final copied = layer.copyWith(name: 'Modified', opacity: 0.8);
      expect(copied.name, equals('Modified'));
      expect(copied.opacity, equals(0.8));
      expect(copied.id, equals('TEST-123'));
    });
  });

  group('CanvasDocument', () {
    test('fromJson and toJson round-trip', () {
      final doc = CanvasDocument(
        id: 'DOC-123',
        width: 1920,
        height: 1080,
        resolution: 72,
        layers: [
          ImageLayer(
            id: 'LAYER-1',
            name: 'Background',
            transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 1920, sizeHeight: 1080),
          ),
          ImageLayer(
            id: 'LAYER-2',
            name: 'Foreground',
            transform: LayerTransform(originX: 100, originY: 100, sizeWidth: 500, sizeHeight: 500),
            opacity: 0.8,
            blendMode: BlendMode.overlay,
          ),
        ],
        guides: [
          CanvasGuide(id: 'GUIDE-1', position: 500, isVertical: true),
        ],
      );

      final json = doc.toJson();
      final parsed = CanvasDocument.fromJson(json);

      expect(parsed.id, equals(doc.id));
      expect(parsed.width, equals(doc.width));
      expect(parsed.height, equals(doc.height));
      expect(parsed.resolution, equals(doc.resolution));
      expect(parsed.layers.length, equals(2));
      expect(parsed.layers[0].id, equals('LAYER-1'));
      expect(parsed.layers[1].id, equals('LAYER-2'));
      expect(parsed.layers[1].opacity, equals(0.8));
      expect(parsed.layers[1].blendMode, equals(BlendMode.overlay));
      expect(parsed.guides.length, equals(1));
    });

    test('preserves unknown top-level fields', () {
      final json = {
        'format': 'com.compositor.project',
        'version': 11,
        'colorSpace': 'sRGB',
        'documentID': 'DOC-123',
        'width': 100,
        'height': 100,
        'resolution': 72,
        'activeLayerID': 'LAYER-1',
        'layers': [
          {'id': 'LAYER-1', 'name': 'Layer', 'transform': {'origin': [0,0], 'size': [100,100]}}
        ],
        'customTopLevel': 'value',
      };
      final doc = CanvasDocument.fromJson(json);
      expect(doc.unknown['customTopLevel'], equals('value'));

      final output = doc.toJson();
      expect(output['customTopLevel'], equals('value'));
    });

    test('effectiveVisibleLayerIDs respects visibility and groups', () {
      final doc = CanvasDocument(
        id: 'DOC-1',
        width: 100,
        height: 100,
        layers: [
          ImageLayer(id: 'A', name: 'A', transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100)),
          ImageLayer(id: 'B', name: 'B', transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100), isVisible: false),
          ImageLayer(id: 'G', name: 'Group', transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100), isGroup: true),
          ImageLayer(id: 'C', name: 'C', transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100), parentID: 'G'),
          ImageLayer(id: 'D', name: 'D', transform: LayerTransform(originX: 0, originY: 0, sizeWidth: 100, sizeHeight: 100), parentID: 'G', isVisible: false),
        ],
      );

      final visible = doc.effectiveVisibleLayerIDs;
      expect(visible, contains('A'));
      expect(visible, contains('C'));
      expect(visible, isNot(contains('B')));
      expect(visible, isNot(contains('D')));
      expect(visible, isNot(contains('G')));
    });
  });

  group('CanvasGuide', () {
    test('fromJson and toJson round-trip', () {
      final guide = CanvasGuide(id: 'GUIDE-1', position: 500, isVertical: true);
      final json = guide.toJson();
      final parsed = CanvasGuide.fromJson(json);
      expect(parsed.id, equals(guide.id));
      expect(parsed.position, equals(guide.position));
      expect(parsed.isVertical, equals(guide.isVertical));
    });
  });
}