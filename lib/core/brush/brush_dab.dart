import 'dart:ui' as ui;

class BrushDab {
  final double x;
  final double y;
  final double size;
  final double hardness;
  final double opacity;
  final ui.Color color;

  BrushDab({
    required this.x,
    required this.y,
    required this.size,
    required this.hardness,
    required this.opacity,
    required this.color,
  });
}