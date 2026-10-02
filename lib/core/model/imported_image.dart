import 'dart:typed_data';

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

  factory ImportedImage.createBlank(
    int width,
    int height, {
    int red = 0,
    int green = 0,
    int blue = 0,
    int alpha = 0,
  }) {
    final rgba = Uint8List(width * height * 4);
    for (int i = 0; i < rgba.length; i += 4) {
      rgba[i] = red;
      rgba[i + 1] = green;
      rgba[i + 2] = blue;
      rgba[i + 3] = alpha;
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