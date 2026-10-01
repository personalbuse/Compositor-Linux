import 'layer_transform.dart';
import 'layer_mask.dart';
import 'blend_mode.dart';
import 'imported_image.dart';

class ImageLayer {
  final String id;
  final String name;
  ImportedImage? asset;
  final LayerTransform transform;
  final String? parentID;
  final bool isGroup;
  final bool isVisible;
  final double opacity;
  final BlendMode blendMode;
  final LayerMask? mask;
  final Map<String, dynamic> adjustment;
  final Map<String, dynamic> shape;
  final Map<String, dynamic> effects;
  final Map<String, dynamic> text;
  final Map<String, dynamic> unknown;

  ImageLayer({
    required this.id,
    required this.name,
    this.asset,
    required this.transform,
    this.parentID,
    this.isGroup = false,
    this.isVisible = true,
    this.opacity = 1.0,
    this.blendMode = BlendMode.normal,
    this.mask,
    Map<String, dynamic>? adjustment,
    Map<String, dynamic>? shape,
    Map<String, dynamic>? effects,
    Map<String, dynamic>? text,
    Map<String, dynamic>? unknown,
  }) : adjustment = adjustment ?? {},
       shape = shape ?? {},
       effects = effects ?? {},
       text = text ?? {},
       unknown = unknown ?? {};

  factory ImageLayer.fromJson(Map<String, dynamic> json) {
    final unknown = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) unknown[k] = v;
    });

    return ImageLayer(
      id: (json['id'] as String).toUpperCase(),
      name: json['name'] as String? ?? 'Layer',
      asset: null,
      transform: LayerTransform.fromJson(json['transform'] as Map<String, dynamic>? ?? {}),
      parentID: json['parentID'] as String?,
      isGroup: json['isGroup'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      blendMode: BlendMode.fromJson(json['blendMode'] as String? ?? 'Normal'),
      mask: json['maskFile'] != null || json['maskEnabled'] != null || json['maskSourceID'] != null
          ? LayerMask.fromJson(json as Map<String, dynamic>)
          : null,
      adjustment: json['adjustment'] as Map<String, dynamic>? ?? {},
      shape: json['shape'] as Map<String, dynamic>? ?? {},
      effects: json['effects'] as Map<String, dynamic>? ?? {},
      text: json['text'] as Map<String, dynamic>? ?? {},
      unknown: unknown,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'transform': transform.toJson(),
      if (parentID != null) 'parentID': parentID,
      'isGroup': isGroup,
      'isVisible': isVisible,
      'opacity': opacity,
      'blendMode': blendMode.toJson(),
      if (mask != null) ...mask!.toJson(),
      if (adjustment.isNotEmpty) 'adjustment': adjustment,
      if (shape.isNotEmpty) 'shape': shape,
      if (effects.isNotEmpty) 'effects': effects,
      if (text.isNotEmpty) 'text': text,
    };
    map.addAll(unknown);
    return map;
  }

  ImageLayer copyWith({
    String? id,
    String? name,
    ImportedImage? asset,
    LayerTransform? transform,
    String? parentID,
    bool? isGroup,
    bool? isVisible,
    double? opacity,
    BlendMode? blendMode,
    LayerMask? mask,
    Map<String, dynamic>? adjustment,
    Map<String, dynamic>? shape,
    Map<String, dynamic>? effects,
    Map<String, dynamic>? text,
    Map<String, dynamic>? unknown,
  }) {
    return ImageLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      asset: asset ?? this.asset,
      transform: transform ?? this.transform,
      parentID: parentID ?? this.parentID,
      isGroup: isGroup ?? this.isGroup,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      mask: mask ?? this.mask,
      adjustment: adjustment ?? this.adjustment,
      shape: shape ?? this.shape,
      effects: effects ?? this.effects,
      text: text ?? this.text,
      unknown: unknown ?? this.unknown,
    );
  }

  static const _knownKeys = {
    'id', 'name', 'imageFile', 'transform', 'parentID', 'isGroup',
    'isVisible', 'opacity', 'blendMode', 'maskFile', 'maskEnabled',
    'maskSourceID', 'adjustment', 'shape', 'effects', 'text',
    'maskPlacement', 'maskLinked', 'guides',
  };
}