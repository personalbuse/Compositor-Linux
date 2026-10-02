import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:compositor/ui/theme/app_theme.dart';
import 'package:compositor/ui/canvas/viewport.dart';
import 'package:compositor/core/model.dart';
import 'package:compositor/core/brush/brush_dab.dart';
import 'package:compositor/render.dart';

class CanvasView extends StatefulWidget {
  final CanvasDocument? document;
  final CanvasViewport viewport;
  final ValueChanged<CanvasViewport> onViewportChanged;
  final Tool activeTool;
  final List<ImageLayer> selectedLayers;
  final ValueChanged<List<ImageLayer>> onSelectionChanged;
  final double brushSize;
  final double brushHardness;
  final double brushOpacity;
  final Color brushColor;
  final bool brushIsEraser;
  final bool spacePanActive;
  final void Function(List<BrushDab> dabs, bool isEraser)? onBrushStroke;

  const CanvasView({
    super.key,
    this.document,
    required this.viewport,
    required this.onViewportChanged,
    required this.activeTool,
    required this.selectedLayers,
    required this.onSelectionChanged,
    required this.brushSize,
    required this.brushHardness,
    required this.brushOpacity,
    required this.brushColor,
    this.brushIsEraser = false,
    this.spacePanActive = false,
    this.onBrushStroke,
  });

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  late TransformationController _transformationController;
  ui.Offset? _lastPanPosition;
  bool _isPanning = false;
  bool _isPainting = false;
  ui.Offset? _lastBrushDocPoint;
  final List<BrushDab> _currentStroke = [];

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _updateTransformationController();
  }

  @override
  void didUpdateWidget(CanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewport != widget.viewport) {
      _updateTransformationController();
    }
  }

  void _updateTransformationController() {
    final matrix = Matrix4.identity()
      ..translateByDouble(widget.viewport.panX, widget.viewport.panY, 0, 0)
      ..scaleByDouble(widget.viewport.scale, widget.viewport.scale, 1, 1);
    _transformationController.value = matrix;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onDoubleTap: _onDoubleTap,
        child: Container(
          color: AppTheme.canvasBackground,
          child: Stack(
            children: [
              _buildCheckerboard(),
              _buildDocumentShadow(),
              _buildDocumentBorder(),
              _buildCanvasContent(),
              if (_currentStroke.isNotEmpty) _buildStrokePreview(),
              if (widget.activeTool == Tool.brush) _buildBrushCursor(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckerboard() {
    return CustomPaint(
      painter: _CheckerboardPainter(),
      size: Size.infinite,
    );
  }

  Widget _buildDocumentShadow() {
    if (widget.document == null) return const SizedBox.shrink();

    return Transform(
      transform: _transformationController.value,
      alignment: Alignment.topLeft,
      child: CustomPaint(
        size: Size(
          widget.document!.width.toDouble(),
          widget.document!.height.toDouble(),
        ),
        painter: _DocumentShadowPainter(),
      ),
    );
  }

  Widget _buildDocumentBorder() {
    if (widget.document == null) return const SizedBox.shrink();

    return Transform(
      transform: _transformationController.value,
      alignment: Alignment.topLeft,
      child: CustomPaint(
        size: Size(
          widget.document!.width.toDouble(),
          widget.document!.height.toDouble(),
        ),
        painter: _DocumentBorderPainter(),
      ),
    );
  }

  Widget _buildCanvasContent() {
    if (widget.document == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_outlined,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No document open',
              style: AppTheme.layerNameStyle.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Press Ctrl+N to create a new canvas',
              style: AppTheme.layerNameSmallStyle,
            ),
          ],
        ),
      );
    }

    return Transform(
      transform: _transformationController.value,
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        child: _RenderedCanvas(
          document: widget.document!,
          viewport: widget.viewport,
        ),
      ),
    );
  }

  Widget _buildBrushCursor() {
    if (widget.document == null) return const SizedBox.shrink();

    final screenSize = widget.brushSize * widget.viewport.scale;
    final radius = screenSize / 2;

    return MouseRegion(
      cursor: SystemMouseCursors.none,
      child: CustomPaint(
        painter: _BrushCursorPainter(
          radius: radius,
          color: widget.brushColor,
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildStrokePreview() {
    final screenDabs = _currentStroke.map((dab) {
      return (
        offset: widget.viewport.documentToScreen(dab.x, dab.y),
        radius: dab.size * widget.viewport.scale / 2,
      );
    }).toList();

    return IgnorePointer(
      child: CustomPaint(
        painter: _StrokePreviewPainter(
          dabs: screenDabs,
          color: widget.brushColor,
          isEraser: widget.brushIsEraser,
        ),
        size: Size.infinite,
      ),
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (HardwareKeyboard.instance.isControlPressed) {
        final zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
        final newZoom = (widget.viewport.zoom * zoomFactor).clamp(
          CanvasViewport.minZoom,
          CanvasViewport.maxZoom,
        );
        _zoomAtPosition(newZoom, event.localPosition);
      } else {
        _panBy(-event.scrollDelta.dx, -event.scrollDelta.dy);
      }
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kMiddleMouseButton ||
        (event.buttons == kPrimaryButton && widget.spacePanActive)) {
      _isPanning = true;
      _lastPanPosition = event.localPosition;
      return;
    }

    if (widget.activeTool == Tool.brush &&
        event.buttons == kPrimaryButton &&
        widget.document != null) {
      _startStroke(event.localPosition);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isPanning && _lastPanPosition != null) {
      final delta = event.localPosition - _lastPanPosition!;
      _panBy(delta.dx, delta.dy);
      _lastPanPosition = event.localPosition;
      return;
    }

    if (_isPainting) {
      _extendStroke(event.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isPanning) {
      _isPanning = false;
      _lastPanPosition = null;
      return;
    }

    if (_isPainting) {
      _commitStroke();
    }
  }

  void _startStroke(ui.Offset localPosition) {
    final docPoint = widget.viewport.screenToDocument(localPosition.dx, localPosition.dy);
    _currentStroke.clear();
    _lastBrushDocPoint = docPoint;
    _currentStroke.add(_makeDab(docPoint));
    _isPainting = true;
    setState(() {});
  }

  void _extendStroke(ui.Offset localPosition) {
    final docPoint = widget.viewport.screenToDocument(localPosition.dx, localPosition.dy);
    final last = _lastBrushDocPoint;
    if (last != null) {
      final distance = (docPoint - last).distance;
      final spacing = (widget.brushSize * 0.25).clamp(1.0, 1000.0);
      if (distance >= spacing) {
        final steps = (distance / spacing).floor();
        for (int i = 1; i <= steps; i++) {
          final t = (i * spacing) / distance;
          final point = ui.Offset(
            last.dx + (docPoint.dx - last.dx) * t,
            last.dy + (docPoint.dy - last.dy) * t,
          );
          _currentStroke.add(_makeDab(point));
        }
        _lastBrushDocPoint = docPoint;
      }
    } else {
      _lastBrushDocPoint = docPoint;
      _currentStroke.add(_makeDab(docPoint));
    }
    setState(() {});
  }

  void _commitStroke() {
    _isPainting = false;
    _lastBrushDocPoint = null;
    if (_currentStroke.isNotEmpty) {
      widget.onBrushStroke?.call(List<BrushDab>.from(_currentStroke), widget.brushIsEraser);
    }
    _currentStroke.clear();
    setState(() {});
  }

  BrushDab _makeDab(ui.Offset docPoint) {
    return BrushDab(
      x: docPoint.dx,
      y: docPoint.dy,
      size: widget.brushSize,
      hardness: widget.brushHardness,
      opacity: widget.brushOpacity,
      color: widget.brushColor,
    );
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.activeTool == Tool.move) {
      // Handle layer selection
    }
  }

  void _onDoubleTap() {
    if (widget.activeTool == Tool.zoom) {
      widget.onViewportChanged(widget.viewport.copyWith(zoom: widget.viewport.devicePixelRatio));
    }
  }

  void _panBy(double dx, double dy) {
    final newPanX = widget.viewport.panX + dx;
    final newPanY = widget.viewport.panY + dy;
    widget.onViewportChanged(widget.viewport.copyWith(panX: newPanX, panY: newPanY));
  }

  void _zoomAtPosition(double newZoom, ui.Offset screenPosition) {
    final docPointBefore = widget.viewport.screenToDocument(
      screenPosition.dx,
      screenPosition.dy,
    );
    final newViewport = widget.viewport.copyWith(zoom: newZoom);
    final docPointAfter = newViewport.screenToDocument(
      screenPosition.dx,
      screenPosition.dy,
    );
    final newPanX = widget.viewport.panX +
        (docPointAfter.dx - docPointBefore.dx) * newViewport.scale;
    final newPanY = widget.viewport.panY +
        (docPointAfter.dy - docPointBefore.dy) * newViewport.scale;

    widget.onViewportChanged(newViewport.copyWith(panX: newPanX, panY: newPanY));
  }
}

class _RenderedCanvas extends StatefulWidget {
  final CanvasDocument document;
  final CanvasViewport viewport;

  const _RenderedCanvas({
    required this.document,
    required this.viewport,
  });

  @override
  State<_RenderedCanvas> createState() => _RenderedCanvasState();
}

class _RenderedCanvasState extends State<_RenderedCanvas> {
  ui.Image? _renderedImage;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(_RenderedCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewport != widget.viewport ||
        oldWidget.document != widget.document) {
      _render();
    }
  }

  Future<void> _render() async {
    final assets = <String, ImportedImage>{};
    for (final layer in widget.document.layers) {
      if (layer.asset != null) {
        assets[layer.id] = layer.asset!;
      }
    }

    final renderer = DocumentRenderer(
      document: widget.document,
      assets: assets,
    );

    final context = RenderContext(
      canvasWidth: (widget.document.width * widget.viewport.scale).round(),
      canvasHeight: (widget.document.height * widget.viewport.scale).round(),
      devicePixelRatio: widget.viewport.devicePixelRatio,
      zoom: widget.viewport.zoom,
      panX: widget.viewport.panX,
      panY: widget.viewport.panY,
    );

    final image = await renderer.renderToImage(context);

    if (mounted) {
      setState(() {
        _renderedImage = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_renderedImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RawImage(
      image: _renderedImage,
      width: widget.document.width.toDouble(),
      height: widget.document.height.toDouble(),
      fit: BoxFit.none,
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  static const double squareSize = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paintLight = Paint()..color = AppTheme.checkerboardLight;
    final paintDark = Paint()..color = AppTheme.checkerboardDark;

    final cols = (size.width / squareSize).ceil() + 1;
    final rows = (size.height / squareSize).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final isLight = (row + col) % 2 == 0;
        final rect = ui.Rect.fromLTWH(
          col * squareSize,
          row * squareSize,
          squareSize,
          squareSize,
        );
        canvas.drawRect(rect, isLight ? paintLight : paintDark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DocumentShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = AppTheme.documentShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final rect = ui.Rect.fromLTWH(-3, -3, size.width + 6, size.height + 6);
    canvas.drawRect(rect, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DocumentBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = AppTheme.documentBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rect = ui.Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrushCursorPainter extends CustomPainter {
  final double radius;
  final Color color;

  _BrushCursorPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final outerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, outerPaint);

    final innerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 1, innerPaint);

    final crosshairPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - radius - 4, center.dy),
      Offset(center.dx - radius - 1, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx + radius + 1, center.dy),
      Offset(center.dx + radius + 4, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - 4),
      Offset(center.dx, center.dy - radius - 1),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + radius + 1),
      Offset(center.dx, center.dy + radius + 4),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BrushCursorPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}
class _StrokePreviewPainter extends CustomPainter {
  final List<({Offset offset, double radius})> dabs;
  final Color color;
  final bool isEraser;

  _StrokePreviewPainter({
    required this.dabs,
    required this.color,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isEraser
          ? const Color(0x66FFFFFF)
          : color.withValues(alpha: 0.8);

    for (final dab in dabs) {
      canvas.drawCircle(dab.offset, dab.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePreviewPainter oldDelegate) => true;
}
