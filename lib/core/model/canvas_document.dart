import 'image_layer.dart';
import 'canvas_guide.dart';
import 'document_selection.dart';

class CanvasDocument {
  final String id;
  final int width;
  final int height;
  double resolution;
  final List<ImageLayer> layers;
  final List<CanvasGuide> guides;
  DocumentSelection? selection;
  final Map<String, dynamic> unknown;

  CanvasDocument({
    required this.id,
    required this.width,
    required this.height,
    this.resolution = 72.0,
    List<ImageLayer>? layers,
    List<CanvasGuide>? guides,
    this.selection,
    Map<String, dynamic>? unknown,
  }) : layers = layers ?? [],
       guides = guides ?? [],
       unknown = unknown ?? {};

  factory CanvasDocument.fromJson(Map<String, dynamic> json) {
    final unknown = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) unknown[k] = v;
    });

    final layersJson = json['layers'] as List? ?? [];
    final layers = layersJson
        .map((l) => ImageLayer.fromJson(l as Map<String, dynamic>))
        .toList();

    final guidesJson = json['guides'] as List? ?? [];
    final guides = guidesJson
        .map((g) => CanvasGuide.fromJson(g as Map<String, dynamic>))
        .toList();

    return CanvasDocument(
      id: (json['documentID'] as String? ?? '').toUpperCase(),
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      resolution: (json['resolution'] as num?)?.toDouble() ?? 72.0,
      layers: layers,
      guides: guides,
      unknown: unknown,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'format': 'com.compositor.project',
      'version': 11,
      'colorSpace': 'sRGB',
      'documentID': id,
      'width': width,
      'height': height,
      'resolution': resolution,
      'activeLayerID': layers.isNotEmpty ? layers.last.id : '',
      'layers': layers.map((l) => l.toJson()).toList(),
      if (guides.isNotEmpty) 'guides': guides.map((g) => g.toJson()).toList(),
    };
    map.addAll(unknown);
    return map;
  }

  List<String> get effectiveVisibleLayerIDs {
    final visible = <String>[];
    final visited = <String>{};
    final layerMap = {for (final l in layers) l.id: l};

    void checkLayer(ImageLayer layer) {
      if (!layer.isVisible) return;
      if (visited.contains(layer.id)) return;
      visited.add(layer.id);

      if (layer.isGroup) {
        for (final child in layers.where((l) => l.parentID == layer.id)) {
          checkLayer(child);
        }
      } else {
        visible.add(layer.id);
      }
    }

    // First, find all root layers (no parent or parent not in document)
    for (final layer in layers) {
      if (layer.parentID == null || !layerMap.containsKey(layer.parentID)) {
        checkLayer(layer);
      }
    }
    return visible;
  }

  static const _knownKeys = {
    'format', 'version', 'colorSpace', 'documentID', 'width', 'height',
    'resolution', 'activeLayerID', 'layers', 'guides',
  };
}