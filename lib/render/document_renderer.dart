import 'dart:typed_data';
import 'dart:ui' as ui;
import '../core/model.dart';
import 'surface.dart';
import 'downsample_cache.dart';

class RenderContext {
  final int canvasWidth;
  final int canvasHeight;
  final double devicePixelRatio;
  final double zoom;
  final double panX;
  final double panY;
  final DownsampleCache downsampleCache;

  RenderContext({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.devicePixelRatio,
    required this.zoom,
    required this.panX,
    required this.panY,
    DownsampleCache? downsampleCache,
  }) : downsampleCache = downsampleCache ?? DownsampleCache();

  int get logicalWidth => (canvasWidth / devicePixelRatio).round();
  int get logicalHeight => (canvasHeight / devicePixelRatio).round();

  RenderContext copyWith({
    int? canvasWidth,
    int? canvasHeight,
    double? devicePixelRatio,
    double? zoom,
    double? panX,
    double? panY,
    DownsampleCache? downsampleCache,
  }) {
    return RenderContext(
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      zoom: zoom ?? this.zoom,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
      downsampleCache: downsampleCache ?? this.downsampleCache,
    );
  }
}

class DocumentRenderer {
  final CanvasDocument document;
  final Map<String, ImportedImage> assets;

  DocumentRenderer({
    required this.document,
    required this.assets,
  });

  Future<ui.Image> renderToImage(RenderContext context) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final logicalWidth = context.logicalWidth;
    final logicalHeight = context.logicalHeight;

    canvas.save();
    canvas.scale(context.devicePixelRatio);
    canvas.translate(-context.panX / context.zoom, -context.panY / context.zoom);
    canvas.scale(context.zoom);

    await _renderLayers(canvas, context, logicalWidth, logicalHeight);

    canvas.restore();

    final picture = recorder.endRecording();
    return picture.toImage(
      (logicalWidth * context.zoom).round(),
      (logicalHeight * context.zoom).round(),
    );
  }

  Future<Uint8List?> renderToPngBytes(RenderContext context) async {
    final image = await renderToImage(context);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _renderLayers(
    ui.Canvas canvas,
    RenderContext context,
    int logicalWidth,
    int logicalHeight,
  ) async {
    final visibleLayerIds = document.effectiveVisibleLayerIDs;
    final layerMap = {for (final l in document.layers) l.id: l};

    for (final layerId in visibleLayerIds) {
      final layer = layerMap[layerId];
      if (layer == null || layer.asset == null || !layer.isVisible) continue;

      await _renderLayer(canvas, layer, context, logicalWidth, logicalHeight, layerMap);
    }
  }

  Future<void> _renderLayer(
    ui.Canvas canvas,
    ImageLayer layer,
    RenderContext context,
    int logicalWidth,
    int logicalHeight,
    Map<String, ImageLayer> layerMap,
  ) async {
    final asset = layer.asset!;
    final transform = layer.transform;

    final renderRect = _calculateRenderRect(transform, logicalWidth, logicalHeight);

    if (renderRect.isEmpty) return;

    int cacheLevel = _getCacheLevel(transform, context.zoom);

    Uint8List? sourceRgba;
    int sourceWidth = asset.width;
    int sourceStride = asset.stride;

    if (cacheLevel > 0) {
      sourceRgba = context.downsampleCache.getLevel(
        asset.sourcePath ?? layer.id,
        cacheLevel,
        asset.width,
        asset.height,
        asset.rgba,
        asset.stride,
      );
      if (sourceRgba != null) {
        sourceWidth = (asset.width + (1 << cacheLevel) - 1) >> cacheLevel;
        sourceStride = sourceWidth * 4;
      } else {
        cacheLevel = 0;
        sourceRgba = asset.rgba;
      }
    } else {
      sourceRgba = asset.rgba;
    }

    if (sourceRgba == null) return;

    final dstW = renderRect.width.round();
    final dstH = renderRect.height.round();
    final dstSurface = Surface.alloc(dstW, dstH);
    dstSurface.clear();

    Uint8List? maskRgba;
    int maskStride = 0;
    if (layer.mask != null && layer.mask!.maskEnabled && layer.mask!.maskFile != null) {
      final maskAsset = assets[layer.mask!.maskFile!];
      if (maskAsset != null) {
        maskRgba = maskAsset.rgba;
        maskStride = maskAsset.stride;
      }
    }

    Compositor.compositeLayer(
      sourceRgba,
      sourceStride,
      dstSurface.rgba,
      dstSurface.stride,
      dstW,
      dstH,
      layer.opacity,
      layer.blendMode.index,
      maskRgba,
      maskStride,
    );

    final ui.Image? image = await _surfaceToImage(dstSurface);
    if (image == null) return;

    canvas.save();
    canvas.translate(renderRect.left, renderRect.top);

    if (transform.rotation != 0) {
      canvas.translate(renderRect.width / 2, renderRect.height / 2);
      canvas.rotate(transform.rotation * 3.14159265359 / 180.0);
      canvas.translate(-renderRect.width / 2, -renderRect.height / 2);
    }

    if (transform.flipX || transform.flipY) {
      canvas.translate(
        transform.flipX ? renderRect.width : 0,
        transform.flipY ? renderRect.height : 0,
      );
      canvas.scale(transform.flipX ? -1 : 1, transform.flipY ? -1 : 1);
    }

    canvas.drawImage(image, ui.Offset.zero, ui.Paint());
    canvas.restore();
  }

  Rect _calculateRenderRect(LayerTransform transform, int canvasWidth, int canvasHeight) {
    final double x = transform.originX;
    final double y = transform.originY;
    final double w = transform.sizeWidth > 0 ? transform.sizeWidth : canvasWidth.toDouble();
    final double h = transform.sizeHeight > 0 ? transform.sizeHeight : canvasHeight.toDouble();

    return Rect.fromLTWH(x, y, w, h);
  }

  int _getCacheLevel(LayerTransform transform, double zoom) {
    final scale = zoom.abs();

    if (scale >= 0.5) return 0;
    if (scale >= 0.25) return 1;
    if (scale >= 0.125) return 2;
    if (scale >= 0.0625) return 3;
    if (scale >= 0.03125) return 4;
    if (scale >= 0.015625) return 5;
    return 6;
  }

  Future<ui.Image?> _surfaceToImage(Surface surface) async {
    try {
      final codec = await ui.instantiateImageCodec(
        surface.rgba.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      return null;
    }
  }
}

class Rect {
  final double left;
  final double top;
  final double width;
  final double height;

  Rect.fromLTWH(this.left, this.top, this.width, this.height);

  bool get isEmpty => width <= 0 || height <= 0;
}