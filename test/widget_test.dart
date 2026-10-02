import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:compositor/main.dart';
import 'package:compositor/core/model.dart';
import 'package:compositor/core/native_bindings.dart';
import 'package:compositor/ui/canvas/canvas_view.dart';
import 'package:compositor/ui/canvas/viewport.dart';

void main() {
  testWidgets('Compositor app shows empty editor shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CompositorApp());
    await tester.pump();

    expect(find.text('No document open'), findsOneWidget);
  });

  testWidgets('canvas renders a document layer at document resolution',
      (WidgetTester tester) async {
    NativeBindings.initialize();

    const w = 40, h = 30;
    final rgba = Uint8List(w * h * 4);
    for (int i = 0; i < rgba.length; i += 4) {
      rgba[i] = 200;
      rgba[i + 1] = 100;
      rgba[i + 2] = 50;
      rgba[i + 3] = 255;
    }

    final document = CanvasDocument(
      id: 'd',
      width: w,
      height: h,
      activeLayerID: 'L',
      layers: [
        ImageLayer(
          id: 'L',
          name: 'bg',
          asset: ImportedImage(name: 'bg', rgba: rgba, width: w, height: h),
          transform: LayerTransform(
            originX: 0,
            originY: 0,
            sizeWidth: w.toDouble(),
            sizeHeight: h.toDouble(),
          ),
        ),
      ],
    );

    // Zoom != 100% is the regression case: the canvas used to render blank.
    final viewport = CanvasViewport(zoom: 2.0);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CanvasView(
          document: document,
          viewport: viewport,
          onViewportChanged: (_) {},
          activeTool: Tool.move,
          selectedLayers: const [],
          onSelectionChanged: (_) {},
          brushSize: 10,
          brushHardness: 1,
          brushOpacity: 1,
          brushColor: const Color(0xFFFF0000),
        ),
      ),
    ));
    await tester.pump();
    // The renderer decodes a raw image off the fake-async clock; let the real
    // event loop run so the future completes.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    final rawImage = tester.widget<RawImage>(find.byType(RawImage));
    expect(rawImage.image, isNotNull);
    expect(rawImage.image!.width, w);
    expect(rawImage.image!.height, h);

    // The document transform must be a valid, non-degenerate zoom matrix.
    final transforms = tester.widgetList<Transform>(find.byType(Transform));
    expect(
      transforms.any((t) =>
          (t.transform.storage[0] - 2.0).abs() < 0.001 &&
          (t.transform.storage[15] - 1.0).abs() < 0.001),
      isTrue,
      reason: 'canvas transform must apply the viewport zoom with a valid matrix',
    );
  });
}
