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