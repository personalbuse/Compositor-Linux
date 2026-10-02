import 'package:flutter/material.dart';
import 'package:compositor/ui/theme/app_theme.dart';
import 'package:compositor/ui/canvas/canvas_view.dart';
import 'package:compositor/ui/panels/layers_panel.dart';
import 'package:compositor/ui/widgets/tool_header.dart';
import 'package:compositor/ui/shell/app_menu_bar.dart';
import 'package:compositor/ui/canvas/viewport.dart';
import 'package:compositor/core/model.dart';
import 'package:compositor/core/brush/brush_dab.dart';

class EditorShell extends StatefulWidget {
  final CanvasDocument? document;
  final VoidCallback? onNewCanvas;
  final VoidCallback? onOpen;
  final VoidCallback? onSave;
  final VoidCallback? onSaveAs;
  final VoidCallback? onExportPng;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onFit;
  final VoidCallback? onZoom100;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onCloseProject;
  final bool canUndo;
  final bool canRedo;
  final bool hasUnsavedChanges;
  final Tool activeTool;
  final ValueChanged<Tool> onToolChanged;
  final CanvasViewport viewport;
  final ValueChanged<CanvasViewport> onViewportChanged;
  final List<ImageLayer> selectedLayers;
  final ValueChanged<List<ImageLayer>> onSelectionChanged;
  final VoidCallback? onDeleteLayer;
  final VoidCallback? onDuplicateLayer;
  final VoidCallback? onAddLayer;
  final VoidCallback? onAddGroup;
  final void Function(ImageLayer layer, bool visible)? onLayerVisibilityChanged;
  final void Function(ImageLayer layer, double opacity)? onLayerOpacityChanged;
  final void Function(ImageLayer layer, BlendMode blendMode)? onLayerBlendModeChanged;
  final void Function(int oldIndex, int newIndex)? onLayerReorder;
  final VoidCallback? onToggleLayerVisibility;
  final VoidCallback? onRaiseLayer;
  final VoidCallback? onLowerLayer;
  final double brushSize;
  final double brushHardness;
  final double brushOpacity;
  final Color brushColor;
  final ValueChanged<double> onBrushSizeChanged;
  final ValueChanged<double> onBrushHardnessChanged;
  final ValueChanged<double> onBrushOpacityChanged;
  final ValueChanged<Color> onBrushColorChanged;
  final bool brushIsEraser;
  final ValueChanged<bool>? onBrushModeChanged;
  final void Function(List<BrushDab> dabs, bool isEraser)? onBrushStroke;
  final bool spacePanActive;

  const EditorShell({
    super.key,
    this.document,
    this.onNewCanvas,
    this.onOpen,
    this.onSave,
    this.onSaveAs,
    this.onExportPng,
    this.onUndo,
    this.onRedo,
    this.onFit,
    this.onZoom100,
    this.onZoomIn,
    this.onZoomOut,
    this.onCloseProject,
    this.canUndo = false,
    this.canRedo = false,
    this.hasUnsavedChanges = false,
    required this.activeTool,
    required this.onToolChanged,
    required this.viewport,
    required this.onViewportChanged,
    this.selectedLayers = const [],
    required this.onSelectionChanged,
    this.onDeleteLayer,
    this.onDuplicateLayer,
    this.onAddLayer,
    this.onAddGroup,
    this.onLayerVisibilityChanged,
    this.onLayerOpacityChanged,
    this.onLayerBlendModeChanged,
    this.onLayerReorder,
    this.onToggleLayerVisibility,
    this.onRaiseLayer,
    this.onLowerLayer,
    required this.brushSize,
    required this.brushHardness,
    required this.brushOpacity,
    required this.brushColor,
    required this.onBrushSizeChanged,
    required this.onBrushHardnessChanged,
    required this.onBrushOpacityChanged,
    required this.onBrushColorChanged,
    this.brushIsEraser = false,
    this.onBrushModeChanged,
    this.onBrushStroke,
    this.spacePanActive = false,
  });

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  double _layersPanelWidth = AppTheme.layersPanelDefaultWidth;
  bool _showLayersPanel = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.windowBackground,
      body: Column(
        children: [
          AppMenuBar(
            onNewCanvas: widget.onNewCanvas,
            onOpen: widget.onOpen,
            onSave: widget.onSave,
            onSaveAs: widget.onSaveAs,
            onExportPng: widget.onExportPng,
            onUndo: widget.onUndo,
            onRedo: widget.onRedo,
            onFit: widget.onFit,
            onZoom100: widget.onZoom100,
            onZoomIn: widget.onZoomIn,
            onZoomOut: widget.onZoomOut,
            onCloseProject: widget.onCloseProject,
            onToggleLayerVisibility: widget.onToggleLayerVisibility,
            onRaiseLayer: widget.onRaiseLayer,
            onLowerLayer: widget.onLowerLayer,
            onDeleteLayer: widget.onDeleteLayer,
            canUndo: widget.canUndo,
            canRedo: widget.canRedo,
            hasDocument: widget.document != null,
          ),
          _buildToolbar(context),
          Expanded(
            child: Row(
              children: [
                _buildRail(context),
                Expanded(
                  child: Column(
                    children: [
                      _buildToolHeader(context),
                      Expanded(
                        child: _buildCanvasArea(context),
                      ),
                    ],
                  ),
                ),
                if (_showLayersPanel) _buildLayersPanel(context),
              ],
            ),
          ),
          _buildStatusBar(context),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      height: AppTheme.toolbarHeight,
      color: AppTheme.toolbarBackground,
      child: Row(
        children: [
          _buildToolbarGroup([
            _ToolbarButton(
              icon: Icons.add,
              tooltip: 'New Canvas (Ctrl+N)',
              onPressed: widget.onNewCanvas,
            ),
            _ToolbarButton(
              icon: Icons.folder_open,
              tooltip: 'Open (Ctrl+O)',
              onPressed: widget.onOpen,
            ),
            _ToolbarButton(
              icon: Icons.save,
              tooltip: 'Save (Ctrl+S)',
              onPressed: widget.onSave,
              enabled: widget.hasUnsavedChanges,
            ),
          ]),
          const VerticalDivider(width: 1, color: AppTheme.borderColor),
          _buildToolbarGroup([
            _ToolbarButton(
              icon: Icons.fit_screen,
              tooltip: 'Fit (Ctrl+0)',
              onPressed: widget.onFit,
            ),
            _ToolbarButton(
              icon: Icons.zoom_out_map,
              tooltip: '100% (Ctrl+1)',
              onPressed: widget.onZoom100,
            ),
            _ToolbarButton(
              icon: Icons.remove,
              tooltip: 'Zoom Out (Ctrl+-)',
              onPressed: widget.onZoomOut,
            ),
            _ToolbarButton(
              icon: Icons.add,
              tooltip: 'Zoom In (Ctrl+=)',
              onPressed: widget.onZoomIn,
            ),
          ]),
          const Spacer(),
          _buildToolbarGroup([
            _ToolbarButton(
              icon: Icons.undo,
              tooltip: 'Undo (Ctrl+Z)',
              onPressed: widget.onUndo,
              enabled: widget.canUndo,
            ),
            _ToolbarButton(
              icon: Icons.redo,
              tooltip: 'Redo (Ctrl+Y)',
              onPressed: widget.onRedo,
              enabled: widget.canRedo,
            ),
          ]),
          const VerticalDivider(width: 1, color: AppTheme.borderColor),
          _buildToolbarGroup([
            _ToolbarButton(
              icon: Icons.file_download,
              tooltip: 'Export PNG (Ctrl+E)',
              onPressed: widget.onExportPng,
              enabled: widget.document != null,
            ),
            _ToolbarButton(
              icon: Icons.close,
              tooltip: 'Close Project',
              onPressed: widget.onCloseProject,
              enabled: widget.document != null,
            ),
          ]),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildToolbarGroup(List<Widget> children) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildRail(BuildContext context) {
    return Container(
      width: AppTheme.railWidth,
      color: AppTheme.railBackground,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppTheme.railSpacing),
            ..._buildRailButtons(),
            const SizedBox(height: AppTheme.railSpacing),
            ..._buildDisabledRailButtons(),
            const SizedBox(height: AppTheme.railSpacing),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRailButtons() {
    return [
      _buildRailButton(
        Tool.move,
        Icons.open_with,
        'Move (V)',
        widget.activeTool == Tool.move,
      ),
      _buildRailButton(
        Tool.hand,
        Icons.pan_tool,
        'Hand (H)',
        widget.activeTool == Tool.hand,
      ),
      _buildRailButton(
        Tool.zoom,
        Icons.zoom_in,
        'Zoom (Z)',
        widget.activeTool == Tool.zoom,
      ),
      _buildRailButton(
        Tool.brush,
        Icons.brush,
        'Brush (B)',
        widget.activeTool == Tool.brush,
      ),
      _buildRailButton(
        Tool.eyedropper,
        Icons.colorize,
        'Eyedropper (I)',
        widget.activeTool == Tool.eyedropper,
      ),
    ];
  }

  List<Widget> _buildDisabledRailButtons() {
    final disabledTools = [
      Tool.marquee,
      Tool.lasso,
      Tool.wand,
      Tool.objectSelect,
      Tool.crop,
      Tool.spotHeal,
      Tool.cloneStamp,
      Tool.smudge,
      Tool.gradient,
      Tool.shape,
      Tool.type,
    ];
    return disabledTools.map((tool) => _buildRailButton(
      tool,
      tool.iconData,
      tool.tooltip,
      false,
      enabled: false,
    )).toList();
  }

  Widget _buildRailButton(Tool tool, IconData icon, String tooltip, bool isActive, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => widget.onToolChanged(tool) : null,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            child: Container(
              width: AppTheme.railButtonSize,
              height: AppTheme.railButtonSize,
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: isActive
                    ? Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1)
                    : null,
              ),
              child: Icon(
                icon,
                size: 20,
                color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolHeader(BuildContext context) {
    return Container(
      height: AppTheme.toolHeaderHeight,
      color: AppTheme.railBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ToolHeader(
          activeTool: widget.activeTool,
          brushSize: widget.brushSize,
          brushHardness: widget.brushHardness,
          brushOpacity: widget.brushOpacity,
          brushColor: widget.brushColor,
          brushIsEraser: widget.brushIsEraser,
          onBrushSizeChanged: widget.onBrushSizeChanged,
          onBrushHardnessChanged: widget.onBrushHardnessChanged,
          onBrushOpacityChanged: widget.onBrushOpacityChanged,
          onBrushColorChanged: widget.onBrushColorChanged,
          onBrushModeChanged: widget.onBrushModeChanged,
        ),
      ),
    );
  }

  Widget _buildCanvasArea(BuildContext context) {
    return Container(
      color: AppTheme.windowBackground,
      child: CanvasView(
        document: widget.document,
        viewport: widget.viewport,
        onViewportChanged: widget.onViewportChanged,
        activeTool: widget.activeTool,
        selectedLayers: widget.selectedLayers,
        onSelectionChanged: widget.onSelectionChanged,
        brushSize: widget.brushSize,
        brushHardness: widget.brushHardness,
        brushOpacity: widget.brushOpacity,
        brushColor: widget.brushColor,
        brushIsEraser: widget.brushIsEraser,
        spacePanActive: widget.spacePanActive,
        onBrushStroke: widget.onBrushStroke,
      ),
    );
  }

  Widget _buildLayersPanel(BuildContext context) {
    return Container(
      width: _layersPanelWidth,
      color: AppTheme.panelBackground,
      child: Column(
        children: [
          Container(
            height: AppTheme.toolHeaderHeight,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'LAYERS',
                    style: AppTheme.layerNameSmallStyle.copyWith(
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Add Layer',
                  onPressed: widget.onAddLayer,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.folder, size: 18),
                  tooltip: 'Add Group',
                  onPressed: widget.onAddGroup,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 18),
                  tooltip: 'Duplicate Layer (Ctrl+J)',
                  onPressed: widget.selectedLayers.isNotEmpty ? widget.onDuplicateLayer : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  tooltip: 'Delete Layer (Backspace)',
                  onPressed: widget.selectedLayers.isNotEmpty ? widget.onDeleteLayer : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayersPanel(
              document: widget.document,
              selectedLayers: widget.selectedLayers,
              onSelectionChanged: widget.onSelectionChanged,
              onLayerVisibilityChanged: (layer, visible) =>
                  widget.onLayerVisibilityChanged?.call(layer, visible),
              onLayerOpacityChanged: (layer, opacity) =>
                  widget.onLayerOpacityChanged?.call(layer, opacity),
              onLayerBlendModeChanged: (layer, blendMode) =>
                  widget.onLayerBlendModeChanged?.call(layer, blendMode),
              onLayerReorder: (oldIndex, newIndex) =>
                  widget.onLayerReorder?.call(oldIndex, newIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final zoomPercent = (widget.viewport.zoom * 100).round();
    final docSize = widget.document != null
        ? '${widget.document!.width} × ${widget.document!.height} px'
        : '—';

    return Container(
      height: AppTheme.statusBarHeight,
      decoration: const BoxDecoration(
        color: AppTheme.statusBarBackground,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Text(
            '${zoomPercent}%',
            style: AppTheme.statusBarStyle,
          ),
          const SizedBox(width: 24),
          Container(
            width: 1,
            height: 16,
            color: AppTheme.borderColor,
          ),
          const SizedBox(width: 12),
          Text(
            docSize,
            style: AppTheme.statusBarStyle,
          ),
          const SizedBox(width: 24),
          Container(
            width: 1,
            height: 16,
            color: AppTheme.borderColor,
          ),
          const SizedBox(width: 12),
          Text(
            'sRGB',
            style: AppTheme.statusBarStyle,
          ),
          const SizedBox(width: 24),
          Container(
            width: 1,
            height: 16,
            color: AppTheme.borderColor,
          ),
          const SizedBox(width: 12),
          Text(
            'Transparent',
            style: AppTheme.statusBarStyle,
          ),
          const Spacer(),
          if (widget.hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '● Unsaved Changes',
                style: AppTheme.statusBarStyle.copyWith(color: AppTheme.accentOrange),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool enabled;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 20,
              color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}