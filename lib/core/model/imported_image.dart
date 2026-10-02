import 'dart:typed_data';
import 'dart:ui' as ui;

class ImportedImage {
  final String name;
  final Uint8List rgba;
  final int width;
  final int height;
  final String? sourcePath;

  ImportedImage({
    required this.name,
    required this.rgba,
    required this.width,
    required this.height,
    this.sourcePath,
  });

  factory ImportedImage.createBlank(int width, int height, ui.Color color) {
    final rgba = Uint8List(width * height * 4);
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    final a = (color.a * 255).round();
    for (int i = 0; i < rgba.length; i += 4) {
      rgba[i] = r;
      rgba[i + 1] = g;
      rgba[i + 2] = b;
      rgba[i + 3] = a;
    }
    return ImportedImage(
      name: 'blank_${width}x$height',
      rgba: rgba,
      width: width,
      height: height,
    );
  }

  int get stride => width * 4;
  int get byteCount => height * stride;

  ImportedImage copyWith({
    String? name,
    Uint8List? rgba,
    int? width,
    int? height,
    String? sourcePath,
  }) {
    return ImportedImage(
      name: name ?? this.name,
      rgba: rgba ?? this.rgba,
      width: width ?? this.width,
      height: height ?? this.height,
      sourcePath: sourcePath ?? this.sourcePath,
    );
  }
}