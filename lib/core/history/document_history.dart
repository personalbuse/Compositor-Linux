import 'dart:typed_data';
import '../model.dart';

abstract class HistoryEntry {
  final String name;
  HistoryEntry(this.name);

  void undo();
  void redo();
}

class PropertyHistoryEntry extends HistoryEntry {
  final dynamic target;
  final String propertyName;
  final dynamic oldValue;
  final dynamic newValue;
  final void Function(dynamic value) setter;

  PropertyHistoryEntry({
    required String name,
    required this.target,
    required this.propertyName,
    required this.oldValue,
    required this.newValue,
    required this.setter,
  }) : super(name);

  @override
  void undo() => setter(oldValue);

  @override
  void redo() => setter(newValue);
}

class PixelHistoryEntry extends HistoryEntry {
  final ImportedImage asset;
  final Uint8List oldPixels;
  final Uint8List newPixels;
  final List<_TileRegion> tiles;

  PixelHistoryEntry({
    required String name,
    required this.asset,
    required this.oldPixels,
    required this.newPixels,
    required this.tiles,
  }) : super(name);

  @override
  void undo() {
    asset.rgba.setRange(0, asset.rgba.length, oldPixels);
  }

  @override
  void redo() {
    asset.rgba.setRange(0, asset.rgba.length, newPixels);
  }

  int get memoryCost => oldPixels.length + newPixels.length;
}

class _TileRegion {
  final int x, y, width, height;
  _TileRegion(this.x, this.y, this.width, this.height);
}

class StructureHistoryEntry extends HistoryEntry {
  final CanvasDocument document;
  final List<ImageLayer> oldLayers;
  final List<ImageLayer> newLayers;
  final int? oldActiveIndex;
  final int? newActiveIndex;

  StructureHistoryEntry({
    required String name,
    required this.document,
    required this.oldLayers,
    required this.newLayers,
    this.oldActiveIndex,
    this.newActiveIndex,
  }) : super(name);

  @override
  void undo() {
    document.layers
      ..clear()
      ..addAll(oldLayers.map((l) => l.copyWith()));
  }

  @override
  void redo() {
    document.layers
      ..clear()
      ..addAll(newLayers.map((l) => l.copyWith()));
  }
}

class DocumentHistory {
  final List<HistoryEntry> _undoStack = [];
  final List<HistoryEntry> _redoStack = [];
  final int _maxMemoryBytes;
  int _currentMemoryBytes = 0;

  DocumentHistory({int maxMemoryBytes = 512 * 1024 * 1024})
      : _maxMemoryBytes = maxMemoryBytes;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  String? get undoName => _undoStack.isNotEmpty ? _undoStack.last.name : null;
  String? get redoName => _redoStack.isNotEmpty ? _redoStack.last.name : null;

  void pushProperty(dynamic target, String propertyName, dynamic oldValue, dynamic newValue,
                    void Function(dynamic value) setter, {String name = 'Property'}) {
    if (oldValue == newValue) return;
    final entry = PropertyHistoryEntry(
      name: name,
      target: target,
      propertyName: propertyName,
      oldValue: oldValue,
      newValue: newValue,
      setter: setter,
    );
    _pushEntry(entry);
  }

  void pushPixels(ImportedImage asset, Uint8List oldPixels, Uint8List newPixels,
                  List<_TileRegion> tiles, {String name = 'Brush'}) {
    final entry = PixelHistoryEntry(
      name: name,
      asset: asset,
      oldPixels: Uint8List.fromList(oldPixels),
      newPixels: Uint8List.fromList(newPixels),
      tiles: tiles,
    );
    _pushEntry(entry);
  }

  void pushStructure(CanvasDocument document, List<ImageLayer> oldLayers, List<ImageLayer> newLayers,
                     {int? oldActiveIndex, int? newActiveIndex, String name = 'Structure'}) {
    final entry = StructureHistoryEntry(
      name: name,
      document: document,
      oldLayers: oldLayers.map((l) => l.copyWith()).toList(),
      newLayers: newLayers.map((l) => l.copyWith()).toList(),
      oldActiveIndex: oldActiveIndex,
      newActiveIndex: newActiveIndex,
    );
    _pushEntry(entry);
  }

  void _pushEntry(HistoryEntry entry) {
    _undoStack.add(entry);
    _redoStack.clear();
    _trimMemory();
  }

  void undo() {
    if (!canUndo) return;
    final entry = _undoStack.removeLast();
    entry.undo();
    _redoStack.add(entry);
  }

  void redo() {
    if (!canRedo) return;
    final entry = _redoStack.removeLast();
    entry.redo();
    _undoStack.add(entry);
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _currentMemoryBytes = 0;
  }

  void _trimMemory() {
    _currentMemoryBytes = _undoStack
        .whereType<PixelHistoryEntry>()
        .fold(0, (sum, e) => sum + e.memoryCost);

    while (_currentMemoryBytes > _maxMemoryBytes && _undoStack.isNotEmpty) {
      final removed = _undoStack.removeAt(0);
      if (removed is PixelHistoryEntry) {
        _currentMemoryBytes -= removed.memoryCost;
      }
    }
  }
}