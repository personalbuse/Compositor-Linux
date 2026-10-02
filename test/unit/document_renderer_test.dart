import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:compositor/render.dart';
import 'package:compositor/core/model.dart';
import 'package:compositor/core/native_bindings.dart';

void main() {
  group('DocumentRenderer', () {
    late CanvasDocument document;
    late Map<String, ImportedImage> assets;
    late RenderContext context;

    setUpAll(() {
      NativeBindings.initialize();
    });

    setUp(() {
      document = CanvasDocument(
        id: 'test',
        width: 100,
        height: 100,
        layers: [],
      );

      final rgba = Uint8List(50 * 50 * 4);
      for (int i = 0; i < rgba.length; i += 4) {
        rgba[i] = 255;
        rgba[i + 1] = 128;
        rgba[i + 2] = 64;
        rgba[i + 3] = 255;
      }

      assets = {
        'layer1': ImportedImage(
          name: 'layer1',
          rgba: rgba,
          width: 50,
          height: 50,
          sourcePath: 'layer1.png',
        ),
      };

      context = RenderContext(
        canvasWidth: 800,
        canvasHeight: 600,
        devicePixelRatio: 1.0,
        zoom: 1.0,
        panX: 0,
        panY: 0,
      );
    });

    test('renders empty document', () async {
      final renderer = DocumentRenderer(document: document, assets: assets);
      final image = await renderer.renderToImage(context);
      
      expect(image.width, equals(800));
      expect(image.height, equals(600));
    });

    test('renders single layer', () async {
      document.layers.add(ImageLayer(
        id: 'LAYER1',
        name: 'Layer 1',
        asset: assets['layer1']!,
        transform: LayerTransform(
          originX: 10,
          originY: 10,
          sizeWidth: 50,
          sizeHeight: 50,
        ),
        isVisible: true,
        opacity: 1.0,
        blendMode: BlendMode.normal,
      ));

      final renderer = DocumentRenderer(document: document, assets: assets);
      final image = await renderer.renderToImage(context);
      
      expect(image.width, equals(800));
      expect(image.height, equals(600));
    });

    test('renders layer with opacity', () async {
      document.layers.add(ImageLayer(
        id: 'LAYER1',
        name: 'Layer 1',
        asset: assets['layer1']!,
        transform: LayerTransform(
          originX: 0,
          originY: 0,
          sizeWidth: 50,
          sizeHeight: 50,
        ),
        isVisible: true,
        opacity: 0.5,
        blendMode: BlendMode.normal,
      ));

      final renderer = DocumentRenderer(document: document, assets: assets);
      final image = await renderer.renderToImage(context);
      
      expect(image.width, equals(800));
      expect(image.height, equals(600));
    });

    test('renders layer with blend mode', () async {
      document.layers.add(ImageLayer(
        id: 'LAYER1',
        name: 'Layer 1',
        asset: assets['layer1']!,
        transform: LayerTransform(
          originX: 0,
          originY: 0,
          sizeWidth: 50,
          sizeHeight: 50,
        ),
        isVisible: true,
        opacity: 1.0,
        blendMode: BlendMode.multiply,
      ));

      final renderer = DocumentRenderer(document: document, assets: assets);
      final image = await renderer.renderToImage(context);
      
      expect(image.width, equals(800));
      expect(image.height, equals(600));
    });

    test('respects layer visibility', () async {
      document.layers.add(ImageLayer(
        id: 'LAYER1',
        name: 'Layer 1',
        asset: assets['layer1']!,
        transform: LayerTransform(
          originX: 0,
          originY: 0,
          sizeWidth: 50,
          sizeHeight: 50,
        ),
        isVisible: false,
        opacity: 1.0,
        blendMode: BlendMode.normal,
      ));

      final renderer = DocumentRenderer(document: document, assets: assets);
      final image = await renderer.renderToImage(context);
      
      expect(image.width, equals(800));
      expect(image.height, equals(600));
    });

    test('renders to PNG bytes', () async {
      document.layers.add(ImageLayer(
        id: 'LAYER1',
        name: 'Layer 1',
        asset: assets['layer1']!,
        transform: LayerTransform(
          originX: 0,
          originY: 0,
          sizeWidth: 50,
          sizeHeight: 50,
        ),
        isVisible: true,
        opacity: 1.0,
        blendMode: BlendMode.normal,
      ));

      final renderer = DocumentRenderer(document: document, assets: assets);
      final pngBytes = await renderer.renderToPngBytes(context);
      
      expect(pngBytes, isNotNull);
      expect(pngBytes!.length, greaterThan(0));
    });

    test('handles zoom and pan', () async {
      document.layers.add(ImageLayer(
        id: 'LAYER1',
        name: 'Layer 1',
        asset: assets['layer1']!,
        transform: LayerTransform(
          originX: 0,
          originY: 0,
          sizeWidth: 50,
          sizeHeight: 50,
        ),
        isVisible: true,
        opacity: 1.0,
        blendMode: BlendMode.normal,
      ));

      final zoomedContext = context.copyWith(zoom: 2.0, panX: 10, panY: 20);
      final renderer = DocumentRenderer(document: document, assets: assets);
      final image = await renderer.renderToImage(zoomedContext);
      
      expect(image.width, equals(1600));
      expect(image.height, equals(1200));
    });

    test('actually paints opaque layer pixels', () async {
      final opaqueDoc = CanvasDocument(
        id: 'opaque',
        width: 64,
        height: 64,
        layers: [
          ImageLayer(
            id: 'LAYER1',
            name: 'Opaque',
            asset: ImportedImage(
              name: 'opaque',
              rgba: Uint8List.fromList(List<int>.generate(
                64 * 64 * 4,
                (i) => (i % 4 == 3) ? 255 : (i % 4 == 0 ? 255 : 200),
              )),
              width: 64,
              height: 64,
            ),
            transform: LayerTransform(
              originX: 0,
              originY: 0,
              sizeWidth: 64,
              sizeHeight: 64,
            ),
            isVisible: true,
            opacity: 1.0,
            blendMode: BlendMode.normal,
          ),
        ],
      );

      final assets2 = <String, ImportedImage>{
        'LAYER1': opaqueDoc.layers.first.asset!,
      };

      final ctx = RenderContext(
        canvasWidth: 64,
        canvasHeight: 64,
        devicePixelRatio: 1.0,
        zoom: 1.0,
        panX: 0,
        panY: 0,
      );

      final renderer = DocumentRenderer(document: opaqueDoc, assets: assets2);
      final image = await renderer.renderToImage(ctx);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(data, isNotNull);

      final bytes = data!.buffer.asUint8List();
      const centerIdx = (32 * 64 + 32) * 4;
      expect(bytes[centerIdx + 3], equals(255),
          reason: 'opaque layer must produce opaque center pixel (render regression)');
    });
  });
}