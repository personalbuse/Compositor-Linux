enum TransformSampling {
  nearest('Nearest'),
  smooth('Smooth'),
  highQuality('High quality');

  final String jsonName;
  const TransformSampling(this.jsonName);

  static TransformSampling fromJson(String name) {
    return TransformSampling.values.firstWhere(
      (e) => e.jsonName == name,
      orElse: () => TransformSampling.highQuality,
    );
  }

  String toJson() => jsonName;
}

class LayerTransform {
  final double originX;
  final double originY;
  final double sizeWidth;
  final double sizeHeight;
  final double rotation;
  final bool flipX;
  final bool flipY;
  final TransformSampling sampling;
  final Map<String, dynamic> unknown;

  LayerTransform({
    required this.originX,
    required this.originY,
    required this.sizeWidth,
    required this.sizeHeight,
    this.rotation = 0,
    this.flipX = false,
    this.flipY = false,
    this.sampling = TransformSampling.highQuality,
    Map<String, dynamic>? unknown,
  }) : unknown = unknown ?? {};

  factory LayerTransform.fromJson(Map<String, dynamic> json) {
    final unknown = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) unknown[k] = v;
    });

    final origin = json['origin'] as List? ?? [0, 0];
    final size = json['size'] as List? ?? [0, 0];

    return LayerTransform(
      originX: (origin[0] as num).toDouble(),
      originY: (origin[1] as num).toDouble(),
      sizeWidth: (size[0] as num).toDouble(),
      sizeHeight: (size[1] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      flipX: json['flipX'] as bool? ?? false,
      flipY: json['flipY'] as bool? ?? false,
      sampling: TransformSampling.fromJson(json['sampling'] as String? ?? 'High quality'),
      unknown: unknown,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'origin': [originX, originY],
      'size': [sizeWidth, sizeHeight],
      'rotation': rotation,
      'flipX': flipX,
      'flipY': flipY,
      'sampling': sampling.toJson(),
    };
    map.addAll(unknown);
    return map;
  }

  static const _knownKeys = {
    'origin', 'size', 'rotation', 'flipX', 'flipY', 'sampling',
  };
}