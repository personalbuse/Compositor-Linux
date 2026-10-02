import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:compositor/core/model.dart';
import 'package:compositor/core/history.dart';
import 'package:compositor/core/brush/brush_dab.dart';
import 'package:compositor/io/comp.dart';
import 'dart:io';

class EditorSession extends ChangeNotifier {
  CanvasDocument? _document;
  String? _projectPath;
  bool _hasUnsavedChanges = false;
  final DocumentHistory _history = DocumentHistory();

  CanvasDocument? get document => _document;
  String? get projectPath => _projectPath;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  DocumentHistory get history => _history;

  void setDocument(CanvasDocument document, {String? path}) {
    _document = document;
    _projectPath = path;
    _hasUnsavedChanges = false;
    _history.clear();
    notifyListeners();
  }

  void closeDocument() {
    _document = null;
    _projectPath = null;
    _hasUnsavedChanges = false;
    _history.clear();
    notifyListeners();
  }

  void markDirty() {
    if (!_hasUnsavedChanges) {
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void markClean() {
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  Future<bool> save() async {
    if (_document == null) return false;
    if (_projectPath == null) return false;

    try {
      final dir = Directory(_projectPath!);
      await ProjectStore.writeComp(_document!, dir, overwrite: true);
      markClean();
      return true;
    } catch (e) {
      debugPrint('Save failed: $e');
      return false;
    }
  }

  Future<bool> saveAs(String newPath) async {
    if (_document == null) return false;

    try {
      final dir = Directory(newPath);
      await ProjectStore.writeComp(_document!, dir, overwrite: true);
      _projectPath = newPath;
      markClean();
      return true;
    } catch (e) {
      debugPrint('Save as failed: $e');
      return false;
    }
  }

  Future<bool> exportPng(String path) async {
    if (_document == null) return false;
    // Implementation will use DocumentRenderer
    return true;
  }

  void undo() {
    if (_history.canUndo) {
      _history.undo();
      markDirty();
      notifyListeners();
    }
  }

  void redo() {
    if (_history.canRedo) {
      _history.redo();
      markDirty();
      notifyListeners();
    }
  }

  void setLayerVisibility(String layerId, bool visible) {
    final layer = _document?.layers.firstWhere((l) => l.id == layerId, orElse: () => throw StateError('Layer not found'));
    if (layer != null && layer.isVisible != visible) {
      final index = _document!.layers.indexOf(layer);
      _history.pushProperty(
        layer,
        'isVisible',
        layer.isVisible,
        visible,
        (value) {
          _document!.layers[index] = layer.copyWith(isVisible: value as bool);
        },
        name: 'Layer Visibility',
      );
      _document!.layers[index] = layer.copyWith(isVisible: visible);
      markDirty();
      notifyListeners();
    }
  }

  void setLayerOpacity(String layerId, double opacity) {
    final layer = _document?.layers.firstWhere((l) => l.id == layerId, orElse: () => throw StateError('Layer not found'));
    if (layer != null && layer.opacity != opacity) {
      final index = _document!.layers.indexOf(layer);
      _history.pushProperty(
        layer,
        'opacity',
        layer.opacity,
        opacity.clamp(0.0, 1.0),
        (value) {
          _document!.layers[index] = layer.copyWith(opacity: value as double);
        },
        name: 'Layer Opacity',
      );
      _document!.layers[index] = layer.copyWith(opacity: opacity.clamp(0.0, 1.0));
      markDirty();
      notifyListeners();
    }
  }

  void setLayerBlendMode(String layerId, BlendMode blendMode) {
    final layer = _document?.layers.firstWhere((l) => l.id == layerId, orElse: () => throw StateError('Layer not found'));
    if (layer != null && layer.blendMode != blendMode) {
      final index = _document!.layers.indexOf(layer);
      _history.pushProperty(
        layer,
        'blendMode',
        layer.blendMode,
        blendMode,
        (value) {
          _document!.layers[index] = layer.copyWith(blendMode: value as BlendMode);
        },
        name: 'Layer Blend Mode',
      );
      _document!.layers[index] = layer.copyWith(blendMode: blendMode);
      markDirty();
      notifyListeners();
    }
  }

  void reorderLayer(int oldIndex, int newIndex) {
    if (_document == null || oldIndex < 0 || oldIndex >= _document!.layers.length) return;
    if (newIndex < 0 || newIndex >= _document!.layers.length) return;
    if (oldIndex == newIndex) return;

    final oldLayers = List<ImageLayer>.from(_document!.layers);
    final layer = _document!.layers.removeAt(oldIndex);
    _document!.layers.insert(newIndex, layer);
    final newLayers = List<ImageLayer>.from(_document!.layers);

    _history.pushStructure(
      _document!,
      oldLayers,
      newLayers,
      name: 'Reorder Layer',
    );

    markDirty();
    notifyListeners();
  }

  void addLayer(ImageLayer layer, {int? index}) {
    if (_document == null) return;

    final oldLayers = List<ImageLayer>.from(_document!.layers);
    if (index != null) {
      _document!.layers.insert(index, layer);
    } else {
      _document!.layers.add(layer);
    }
    final newLayers = List<ImageLayer>.from(_document!.layers);

    _history.pushStructure(
      _document!,
      oldLayers,
      newLayers,
      name: 'Add Layer',
    );

    markDirty();
    notifyListeners();
  }

  void removeLayer(String layerId) {
    if (_document == null) return;
    final index = _document!.layers.indexWhere((l) => l.id == layerId);
    if (index == -1) return;

    final oldLayers = List<ImageLayer>.from(_document!.layers);
    _document!.layers.removeAt(index);
    final newLayers = List<ImageLayer>.from(_document!.layers);

    _history.pushStructure(
      _document!,
      oldLayers,
      newLayers,
      name: 'Remove Layer',
    );

    markDirty();
    notifyListeners();
  }

  void duplicateLayer(String layerId) {
    if (_document == null) return;
    final layer = _document!.layers.firstWhere((l) => l.id == layerId, orElse: () => throw StateError('Layer not found'));
    final index = _document!.layers.indexOf(layer);

    final newLayer = layer.copyWith(
      id: _generateId(),
      name: '${layer.name} copy',
    );

    final oldLayers = List<ImageLayer>.from(_document!.layers);
    _document!.layers.insert(index + 1, newLayer);
    final newLayers = List<ImageLayer>.from(_document!.layers);

    _history.pushStructure(
      _document!,
      oldLayers,
      newLayers,
      name: 'Duplicate Layer',
    );

    markDirty();
    notifyListeners();
  }

  void setLayerTransform(String layerId, LayerTransform transform) {
    final layer = _document?.layers.firstWhere((l) => l.id == layerId, orElse: () => throw StateError('Layer not found'));
    if (layer != null && layer.transform != transform) {
      final index = _document!.layers.indexOf(layer);
      _history.pushProperty(
        layer,
        'transform',
        layer.transform,
        transform,
        (value) {
          _document!.layers[index] = layer.copyWith(transform: value as LayerTransform);
        },
        name: 'Layer Transform',
      );
      _document!.layers[index] = layer.copyWith(transform: transform);
      markDirty();
      notifyListeners();
    }
  }

  void applyBrushStroke(List<BrushDab> dabs, {bool isEraser = false}) {
    if (_document == null) return;

    final activeLayerId = _document!.activeLayerID;
    if (activeLayerId == null) return;

    final layer = _document!.layers.firstWhere((l) => l.id == activeLayerId, orElse: () => throw StateError('Active layer not found'));
    if (layer.asset == null) return;

    final asset = layer.asset!;
    final oldPixels = Uint8List.fromList(asset.rgba);
    final newRgba = Uint8List.fromList(asset.rgba);

    for (final dab in dabs) {
      _applyDab(newRgba, asset.width, asset.height, dab, isEraser);
    }

    asset.rgba.setRange(0, asset.rgba.length, newRgba);

    _history.pushPixels(
      asset,
      oldPixels,
      newRgba,
      [],
      name: isEraser ? 'Erase' : 'Brush',
    );

    markDirty();
    notifyListeners();
  }

  void _applyDab(Uint8List rgba, int width, int height, BrushDab dab, bool isEraser) {
    final cx = dab.x.round();
    final cy = dab.y.round();
    final radius = (dab.size / 2).round();

    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final x = cx + dx;
        final y = cy + dy;
        if (x < 0 || x >= width || y < 0 || y >= height) continue;

        final dist = (dx * dx + dy * dy).toDouble();
        final radiusSq = (radius * radius).toDouble();
        if (dist > radiusSq) continue;

        final u = dist / radiusSq;
        final falloff = _gaussianFalloff(u, dab.hardness);

        final idx = (y * width + x) * 4;
        final srcA = rgba[idx + 3] / 255.0;

        if (isEraser) {
          final newA = srcA * (1.0 - dab.opacity * falloff);
          rgba[idx + 3] = (newA * 255).round().clamp(0, 255);
          if (rgba[idx + 3] == 0) {
            rgba[idx] = 0;
            rgba[idx + 1] = 0;
            rgba[idx + 2] = 0;
          }
        } else {
          final dstA = dab.opacity * falloff;
          final outA = srcA + dstA * (1.0 - srcA);
          if (outA > 0) {
            rgba[idx] = (((rgba[idx] / 255.0) * srcA * (1.0 - dstA) +
                    (dab.color.r / 255.0) * dstA) *
                255 /
                outA).round();
            rgba[idx + 1] = (((rgba[idx + 1] / 255.0) * srcA * (1.0 - dstA) +
                    (dab.color.g / 255.0) * dstA) *
                255 /
                outA).round();
            rgba[idx + 2] = (((rgba[idx + 2] / 255.0) * srcA * (1.0 - dstA) +
                    (dab.color.b / 255.0) * dstA) *
                255 /
                outA).round();
            rgba[idx + 3] = (outA * 255).round().clamp(0, 255);
          }
        }
      }
    }
  }

  double _gaussianFalloff(double u, double hardness) {
    if (hardness >= 1.0) return u <= 1.0 ? 1.0 : 0.0;
    final expVal = 2.5;
    final numerator = math.exp(-expVal * u * u) - math.exp(-expVal);
    final denominator = 1.0 - math.exp(-expVal);
    return (1.0 - numerator / denominator).clamp(0.0, 1.0);
  }

  String _generateId() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return 'LAYER_${random.toRadixString(16).toUpperCase()}';
  }
}