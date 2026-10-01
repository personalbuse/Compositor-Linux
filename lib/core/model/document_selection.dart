import 'dart:typed_data';

class DocumentSelection {
  final Uint8List? mask;
  final int? width;
  final int? height;
  final Map<String, dynamic> unknown;

  DocumentSelection({
    this.mask,
    this.width,
    this.height,
    Map<String, dynamic>? unknown,
  }) : unknown = unknown ?? {};

  factory DocumentSelection.fromJson(Map<String, dynamic> json) {
    return DocumentSelection(
      unknown: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(unknown);
  }
}