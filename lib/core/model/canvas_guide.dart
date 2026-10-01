class CanvasGuide {
  final String id;
  final double position;
  final bool isVertical;
  final Map<String, dynamic> unknown;

  CanvasGuide({
    required this.id,
    required this.position,
    required this.isVertical,
    Map<String, dynamic>? unknown,
  }) : unknown = unknown ?? {};

  factory CanvasGuide.fromJson(Map<String, dynamic> json) {
    final unknown = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) unknown[k] = v;
    });

    return CanvasGuide(
      id: (json['id'] as String? ?? '').toUpperCase(),
      position: (json['position'] as num?)?.toDouble() ?? 0,
      isVertical: json['isVertical'] as bool? ?? true,
      unknown: unknown,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'position': position,
      'isVertical': isVertical,
    };
    map.addAll(unknown);
    return map;
  }

  static const _knownKeys = {
    'id', 'position', 'isVertical',
  };
}