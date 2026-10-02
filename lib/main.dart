import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:compositor/ui/theme/app_theme.dart';
import 'package:compositor/ui/shell/editor_shell.dart';
import 'package:compositor/ui/canvas/viewport.dart';
import 'package:compositor/core/session/editor_session.dart';
import 'package:compositor/core/model.dart';
import 'package:compositor/core/native_bindings.dart';
import 'package:compositor/io/comp.dart';
import 'package:compositor/io/image.dart';
import 'package:file_selector/file_selector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    NativeBindings.initialize();
  } catch (e) {
    initError = e;
  }

  runApp(CompositorApp(initError: initError));
}

class CompositorApp extends StatelessWidget {
  final Object? initError;

  const CompositorApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compositor',
      theme: AppTheme.themeData,
      darkTheme: AppTheme.themeData,
      themeMode: ThemeMode.dark,
      home: initError == null
          ? const CompositorHome()
          : _NativeLibraryErrorScreen(error: initError!),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _NativeLibraryErrorScreen extends StatelessWidget {
  final Object error;

  const _NativeLibraryErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.windowBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.accentRed, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Compositor failed to start',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The native rendering library could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              SelectableText(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompositorHome extends StatefulWidget {
  const CompositorHome({super.key});

  @override
  State<CompositorHome> createState() => _CompositorHomeState();
}

class _CompositorHomeState extends State<CompositorHome> {
  final EditorSession _session = EditorSession();
  Tool _activeTool = Tool.move;
  CanvasViewport _viewport = CanvasViewport();
  List<ImageLayer> _selectedLayers = [];
  double _brushSize = 50.0;
  double _brushHardness = 0.5;
  double _brushOpacity = 1.0;
  Color _brushColor = Colors.black;
  bool _brushIsEraser = false;
  bool _isSpacePressed = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _session.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  bool _handleKeyEvent(KeyEvent event) {
    final isKeyDown = event is KeyDownEvent;
    final isKeyUp = event is KeyUpEvent;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (isKeyDown) {
        _isSpacePressed = true;
      } else if (isKeyUp) {
        _isSpacePressed = false;
      }
      return true;
    }

    if (isKeyDown) {
      if (HardwareKeyboard.instance.isControlPressed) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyN:
            _newCanvas();
            return true;
          case LogicalKeyboardKey.keyO:
            _openDocument();
            return true;
          case LogicalKeyboardKey.keyS:
            if (HardwareKeyboard.instance.isShiftPressed) {
              _saveAs();
            } else {
              _save();
            }
            return true;
          case LogicalKeyboardKey.keyE:
            _exportPng();
            return true;
          case LogicalKeyboardKey.keyZ:
            if (HardwareKeyboard.instance.isShiftPressed) {
              _session.redo();
            } else {
              _session.undo();
            }
            return true;
          case LogicalKeyboardKey.keyY:
            _session.redo();
            return true;
          case LogicalKeyboardKey.digit0:
            _fit();
            return true;
          case LogicalKeyboardKey.digit1:
            _zoom100();
            return true;
          case LogicalKeyboardKey.equal:
            _zoomIn();
            return true;
          case LogicalKeyboardKey.minus:
            _zoomOut();
            return true;
          case LogicalKeyboardKey.keyW:
            _closeProject();
            return true;
          default:
            break;
        }
      }

      if (!HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isAltPressed) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyV:
            _setTool(Tool.move);
            return true;
          case LogicalKeyboardKey.keyH:
            _setTool(Tool.hand);
            return true;
          case LogicalKeyboardKey.keyZ:
            _setTool(Tool.zoom);
            return true;
          case LogicalKeyboardKey.keyB:
            _setTool(Tool.brush);
            return true;
          case LogicalKeyboardKey.keyI:
            _setTool(Tool.eyedropper);
            return true;
          case LogicalKeyboardKey.bracketLeft:
            _adjustBrushSize(-10);
            return true;
          case LogicalKeyboardKey.bracketRight:
            _adjustBrushSize(10);
            return true;
          case LogicalKeyboardKey.keyE:
            _setTool(Tool.eyedropper);
            return true;
          default:
            break;
        }
      }
    }

    return false;
  }

  void _setTool(Tool tool) {
    if (!tool.isEnabledInMVP) return;
    setState(() => _activeTool = tool);
  }

  void _adjustBrushSize(double delta) {
    setState(() {
      _brushSize = (_brushSize + delta).clamp(1.0, 2000.0);
    });
  }

  void _newCanvas() async {
    final params = await _showNewCanvasDialog();
    if (params != null) {
      final layerId = _generateLayerId();
      final document = CanvasDocument(
        id: _generateId(),
        width: params.width,
        height: params.height,
        layers: [
          ImageLayer(
            id: layerId,
            name: 'Background',
            asset: ImportedImage.createBlank(params.width, params.height),
            transform: LayerTransform(
              originX: 0,
              originY: 0,
              sizeWidth: params.width.toDouble(),
              sizeHeight: params.height.toDouble(),
            ),
            isVisible: true,
            opacity: 1.0,
            blendMode: BlendMode.normal,
          ),
        ],
        activeLayerID: layerId,
      );
      _session.setDocument(document);
      _viewport.fit(800, 600, params.width.toDouble(), params.height.toDouble());
      setState(() {});
    }
  }

  void _openDocument() async {
    const typeGroup = XTypeGroup(
      label: 'Compositor Images & Projects',
      extensions: ['comp', 'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    await _openPath(file.path);
  }

  void _openProjectFolder() async {
    final dirPath = await getDirectoryPath();
    if (dirPath == null) return;
    await _openComp(dirPath);
  }

  Future<void> _openPath(String filePath) async {
    if (ImageImporter.hasImageExtension(filePath)) {
      await _importImage(filePath);
    } else {
      await _openComp(filePath);
    }
  }

  Future<void> _openComp(String dirPath) async {
    try {
      final document = await ProjectStore.readComp(Directory(dirPath));
      _session.setDocument(document, path: dirPath);
      _viewport.fit(800, 600, document.width.toDouble(), document.height.toDouble());
      setState(() {});
    } catch (e) {
      _showError('Failed to open document: $e');
    }
  }

  Future<void> _importImage(String filePath) async {
    try {
      final image = await ImageImporter.fromFile(filePath);
      _session.importImageAsLayer(image);
      final doc = _session.document;
      if (doc != null) {
        _viewport.fit(800, 600, doc.width.toDouble(), doc.height.toDouble());
      }
      setState(() {});
    } catch (e) {
      _showError('Failed to import image: $e');
    }
  }

  Future<void> _save() async {
    if (_session.projectPath != null) {
      await _session.save();
    } else {
      await _saveAs();
    }
  }

  Future<void> _saveAs() async {
    final file = await getSaveLocation(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Compositor Projects', extensions: ['comp']),
      ],
      suggestedName: _session.document?.id ?? 'Untitled.comp',
    );
    if (file != null) {
      await _session.saveAs(file.path);
    }
  }

  Future<void> _exportPng() async {
    final file = await getSaveLocation(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'PNG Image', extensions: ['png']),
      ],
      suggestedName: '${_session.document?.id ?? 'export'}.png',
    );
    if (file != null) {
      await _session.exportPng(file.path);
    }
  }

  void _closeProject() {
    _session.closeDocument();
  }

  void _toggleSelectedLayerVisibility() {
    final doc = _session.document;
    if (doc == null || _selectedLayers.isEmpty) return;
    final layer = _selectedLayers.first;
    _session.setLayerVisibility(layer.id, !layer.isVisible);
  }

  void _raiseSelectedLayer() {
    final doc = _session.document;
    if (doc == null || _selectedLayers.isEmpty) return;
    final index = doc.layers.indexOf(_selectedLayers.first);
    if (index >= 0 && index < doc.layers.length - 1) {
      _session.reorderLayer(index, index + 1);
    }
  }

  void _lowerSelectedLayer() {
    final doc = _session.document;
    if (doc == null || _selectedLayers.isEmpty) return;
    final index = doc.layers.indexOf(_selectedLayers.first);
    if (index > 0) {
      _session.reorderLayer(index, index - 1);
    }
  }

  void _fit() {
    if (_session.document != null) {
      setState(() {
        _viewport.fit(800, 600, _session.document!.width.toDouble(), _session.document!.height.toDouble());
      });
    }
  }

  void _zoom100() {
    setState(() {
      _viewport.setZoom100();
    });
  }

  void _zoomIn() {
    setState(() {
      _viewport.zoomIn();
    });
  }

  void _zoomOut() {
    setState(() {
      _viewport.zoomOut();
    });
  }

  Future<_NewCanvasParams?> _showNewCanvasDialog() async {
    final widthController = TextEditingController(text: '1920');
    final heightController = TextEditingController(text: '1080');

    return showDialog<_NewCanvasParams>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('New Canvas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widthController,
              decoration: const InputDecoration(labelText: 'Width'),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightController,
              decoration: const InputDecoration(labelText: 'Height'),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final width = int.tryParse(widthController.text) ?? 1920;
              final height = int.tryParse(heightController.text) ?? 1080;
              Navigator.pop(context, _NewCanvasParams(width: width, height: height));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentRed,
      ),
    );
  }

  String _generateId() {
    return 'DOC_${DateTime.now().microsecondsSinceEpoch.toRadixString(16).toUpperCase()}';
  }

  String _generateLayerId() {
    return 'LAYER_${DateTime.now().microsecondsSinceEpoch.toRadixString(16).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: EditorShell(
        document: _session.document,
        onNewCanvas: _newCanvas,
        onOpen: _openDocument,
        onOpenProject: _openProjectFolder,
        onSave: _save,
        onSaveAs: _saveAs,
        onExportPng: _exportPng,
        onUndo: _session.undo,
        onRedo: _session.redo,
        onFit: _fit,
        onZoom100: _zoom100,
        onZoomIn: _zoomIn,
        onZoomOut: _zoomOut,
        onCloseProject: _closeProject,
        canUndo: _session.canUndo,
        canRedo: _session.canRedo,
        hasUnsavedChanges: _session.hasUnsavedChanges,
        activeTool: _activeTool,
        onToolChanged: _setTool,
        viewport: _viewport,
        onViewportChanged: (v) => setState(() => _viewport = v),
        selectedLayers: _selectedLayers,
        onSelectionChanged: (layers) {
          setState(() {
            _selectedLayers = layers;
            if (layers.isNotEmpty && _session.document != null) {
              _session.document!.activeLayerID = layers.first.id;
            }
          });
        },
        onDeleteLayer: _selectedLayers.isNotEmpty
            ? () => _session.removeLayer(_selectedLayers.first.id)
            : null,
        onDuplicateLayer: _selectedLayers.isNotEmpty
            ? () => _session.duplicateLayer(_selectedLayers.first.id)
            : null,
        onAddLayer: () {
          if (_session.document != null) {
            final newLayer = ImageLayer(
              id: _generateLayerId(),
              name: 'Layer ${_session.document!.layers.length + 1}',
              asset: ImportedImage.createBlank(
                _session.document!.width,
                _session.document!.height,
              ),
              transform: LayerTransform(
                originX: 0,
                originY: 0,
                sizeWidth: _session.document!.width.toDouble(),
                sizeHeight: _session.document!.height.toDouble(),
              ),
              isVisible: true,
              opacity: 1.0,
              blendMode: BlendMode.normal,
            );
            _session.addLayer(newLayer);
          }
        },
        onAddGroup: () {},
        onLayerVisibilityChanged: (layer, visible) =>
            _session.setLayerVisibility(layer.id, visible),
        onLayerOpacityChanged: (layer, opacity) =>
            _session.setLayerOpacity(layer.id, opacity),
        onLayerBlendModeChanged: (layer, blendMode) =>
            _session.setLayerBlendMode(layer.id, blendMode),
        onLayerReorder: (oldIndex, newIndex) =>
            _session.reorderLayer(oldIndex, newIndex),
        onToggleLayerVisibility: _toggleSelectedLayerVisibility,
        onRaiseLayer: _raiseSelectedLayer,
        onLowerLayer: _lowerSelectedLayer,
        brushSize: _brushSize,
        brushHardness: _brushHardness,
        brushOpacity: _brushOpacity,
        brushColor: _brushColor,
        onBrushSizeChanged: (v) => setState(() => _brushSize = v),
        onBrushHardnessChanged: (v) => setState(() => _brushHardness = v),
        onBrushOpacityChanged: (v) => setState(() => _brushOpacity = v),
        onBrushColorChanged: (c) => setState(() => _brushColor = c),
        brushIsEraser: _brushIsEraser,
        onBrushModeChanged: (isEraser) => setState(() => _brushIsEraser = isEraser),
        onBrushStroke: (dabs, isEraser) =>
            _session.applyBrushStroke(dabs, isEraser: isEraser),
        spacePanActive: _isSpacePressed,
      ),
    );
  }
}

class _NewCanvasParams {
  final int width;
  final int height;

  _NewCanvasParams({required this.width, required this.height});
}