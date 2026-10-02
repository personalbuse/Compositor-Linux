import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CanvasViewport {
  double zoom;
  double panX;
  double panY;
  final double devicePixelRatio;

  CanvasViewport({
    this.zoom = 1.0,
    this.panX = 0.0,
    this.panY = 0.0,
    this.devicePixelRatio = 1.0,
  });

  double get scale => zoom / devicePixelRatio;
  double get pointsPerPixel => devicePixelRatio / zoom;

  static const List<double> zoomSteps = [
    0.125, 1 / 6, 0.25, 1 / 3, 0.5, 2 / 3,
    1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 12.0, 16.0,
  ];

  static const double minZoom = 0.001;
  static const double maxZoom = 32.0;

  CanvasViewport copyWith({
    double? zoom,
    double? panX,
    double? panY,
    double? devicePixelRatio,
  }) {
    return CanvasViewport(
      zoom: zoom ?? this.zoom,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }

  double clampZoom(double zoom) {
    return zoom.clamp(minZoom, maxZoom);
  }

  double nearestZoomStep(double zoom) {
    if (zoom <= zoomSteps.first) return zoomSteps.first;
    if (zoom >= zoomSteps.last) return zoomSteps.last;

    double closest = zoomSteps.first;
    double minDiff = (zoom - zoomSteps.first).abs();

    for (final step in zoomSteps) {
      final diff = (zoom - step).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = step;
      }
    }
    return closest;
  }

  void zoomIn({double? anchoredAtX, double? anchoredAtY}) {
    final currentIndex = zoomSteps.indexWhere((s) => s >= zoom);
    final nextIndex = (currentIndex == -1 || currentIndex == zoomSteps.length - 1)
        ? zoomSteps.length - 1
        : currentIndex + 1;
    setZoom(zoomSteps[nextIndex], anchoredAtX: anchoredAtX, anchoredAtY: anchoredAtY);
  }

  void zoomOut({double? anchoredAtX, double? anchoredAtY}) {
    final currentIndex = zoomSteps.lastIndexWhere((s) => s <= zoom);
    final prevIndex = currentIndex <= 0 ? 0 : currentIndex - 1;
    setZoom(zoomSteps[prevIndex], anchoredAtX: anchoredAtX, anchoredAtY: anchoredAtY);
  }

  void setZoom(double newZoom, {double? anchoredAtX, double? anchoredAtY}) {
    newZoom = clampZoom(newZoom);
    if (anchoredAtX != null && anchoredAtY != null) {
      final docPointBefore = screenToDocument(anchoredAtX, anchoredAtY);
      zoom = newZoom;
      final docPointAfter = screenToDocument(anchoredAtX, anchoredAtY);
      panX += (docPointAfter.dx - docPointBefore.dx) * scale;
      panY += (docPointAfter.dy - docPointBefore.dy) * scale;
    } else {
      zoom = newZoom;
    }
  }

  void fit(double viewWidth, double viewHeight, double docWidth, double docHeight) {
    if (docWidth <= 0 || docHeight <= 0) return;
    const padding = 96.0;
    final availableWidth = math.max(1, viewWidth - padding);
    final availableHeight = math.max(1, viewHeight - padding);
    final scaleX = availableWidth / docWidth;
    final scaleY = availableHeight / docHeight;
    final fitScale = math.min(scaleX, scaleY);
    zoom = (fitScale * devicePixelRatio).clamp(minZoom, maxZoom);
    panX = 0;
    panY = 0;
  }

  void setZoom100() {
    zoom = devicePixelRatio;
  }

  ui.Offset screenToDocument(double screenX, double screenY) {
    return ui.Offset(
      (screenX - panX) / scale,
      (screenY - panY) / scale,
    );
  }

  ui.Offset documentToScreen(double docX, double docY) {
    return ui.Offset(
      docX * scale + panX,
      docY * scale + panY,
    );
  }

  ui.Rect getVisibleDocumentRect(double viewWidth, double viewHeight) {
    final topLeft = screenToDocument(0, 0);
    final bottomRight = screenToDocument(viewWidth, viewHeight);
    return ui.Rect.fromPoints(topLeft, bottomRight);
  }

  bool get isAt100Percent => (zoom - devicePixelRatio).abs() < 0.001;
}

enum Tool {
  move,
  hand,
  zoom,
  brush,
  eyedropper,
  marquee,
  lasso,
  wand,
  objectSelect,
  crop,
  spotHeal,
  cloneStamp,
  smudge,
  gradient,
  shape,
  type,
}

extension ToolExtension on Tool {
  String get name {
    switch (this) {
      case Tool.move:
        return 'Move';
      case Tool.hand:
        return 'Hand';
      case Tool.zoom:
        return 'Zoom';
      case Tool.brush:
        return 'Brush';
      case Tool.eyedropper:
        return 'Eyedropper';
      case Tool.marquee:
        return 'Marquee';
      case Tool.lasso:
        return 'Lasso';
      case Tool.wand:
        return 'Wand';
      case Tool.objectSelect:
        return 'Object Select';
      case Tool.crop:
        return 'Crop';
      case Tool.spotHeal:
        return 'Spot Heal';
      case Tool.cloneStamp:
        return 'Clone Stamp';
      case Tool.smudge:
        return 'Smudge';
      case Tool.gradient:
        return 'Gradient';
      case Tool.shape:
        return 'Shape';
      case Tool.type:
        return 'Type';
    }
  }

  String get tooltip {
    switch (this) {
      case Tool.move:
        return 'Move (V)';
      case Tool.hand:
        return 'Hand (H)';
      case Tool.zoom:
        return 'Zoom (Z)';
      case Tool.brush:
        return 'Brush (B)';
      case Tool.eyedropper:
        return 'Eyedropper (I)';
      case Tool.marquee:
        return 'Marquee (M)';
      case Tool.lasso:
        return 'Lasso (L)';
      case Tool.wand:
        return 'Wand (W)';
      case Tool.objectSelect:
        return 'Object Select';
      case Tool.crop:
        return 'Crop (C)';
      case Tool.spotHeal:
        return 'Spot Heal (J)';
      case Tool.cloneStamp:
        return 'Clone Stamp (S)';
      case Tool.smudge:
        return 'Smudge';
      case Tool.gradient:
        return 'Gradient (G)';
      case Tool.shape:
        return 'Shape (U)';
      case Tool.type:
        return 'Type (T)';
    }
  }

  String get shortcut {
    switch (this) {
      case Tool.move:
        return 'V';
      case Tool.hand:
        return 'H';
      case Tool.zoom:
        return 'Z';
      case Tool.brush:
        return 'B';
      case Tool.eyedropper:
        return 'I';
      case Tool.marquee:
        return 'M';
      case Tool.lasso:
        return 'L';
      case Tool.wand:
        return 'W';
      case Tool.objectSelect:
        return '';
      case Tool.crop:
        return 'C';
      case Tool.spotHeal:
        return 'J';
      case Tool.cloneStamp:
        return 'S';
      case Tool.smudge:
        return '';
      case Tool.gradient:
        return 'G';
      case Tool.shape:
        return 'U';
      case Tool.type:
        return 'T';
    }
  }

  bool get isEnabledInMVP {
    switch (this) {
      case Tool.move:
      case Tool.hand:
      case Tool.zoom:
      case Tool.brush:
      case Tool.eyedropper:
        return true;
      default:
        return false;
    }
  }

  IconData get iconData {
    switch (this) {
      case Tool.move:
        return Icons.open_with;
      case Tool.hand:
        return Icons.pan_tool;
      case Tool.zoom:
        return Icons.zoom_in;
      case Tool.brush:
        return Icons.brush;
      case Tool.eyedropper:
        return Icons.colorize;
      case Tool.marquee:
        return Icons.crop_square;
      case Tool.lasso:
        return Icons.gesture;
      case Tool.wand:
        return Icons.auto_fix_high;
      case Tool.objectSelect:
        return Icons.select_all;
      case Tool.crop:
        return Icons.crop;
      case Tool.spotHeal:
        return Icons.healing;
      case Tool.cloneStamp:
        return Icons.content_copy;
      case Tool.smudge:
        return Icons.blur_on;
      case Tool.gradient:
        return Icons.gradient;
      case Tool.shape:
        return Icons.crop_free;
      case Tool.type:
        return Icons.text_fields;
    }
  }
}