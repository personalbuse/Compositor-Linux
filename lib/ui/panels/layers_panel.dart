import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:compositor/ui/theme/app_theme.dart';
import 'package:compositor/core/model.dart';
import 'package:compositor/ui/widgets/blend_mode_dropdown.dart';

class LayersPanel extends StatefulWidget {
  final CanvasDocument? document;
  final List<ImageLayer> selectedLayers;
  final ValueChanged<List<ImageLayer>> onSelectionChanged;
  final void Function(ImageLayer layer, bool visible) onLayerVisibilityChanged;
  final void Function(ImageLayer layer, double opacity) onLayerOpacityChanged;
  final void Function(ImageLayer layer, BlendMode blendMode) onLayerBlendModeChanged;
  final void Function(int oldIndex, int newIndex) onLayerReorder;

  const LayersPanel({
    super.key,
    this.document,
    required this.selectedLayers,
    required this.onSelectionChanged,
    required this.onLayerVisibilityChanged,
    required this.onLayerOpacityChanged,
    required this.onLayerBlendModeChanged,
    required this.onLayerReorder,
  });

  @override
  State<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<LayersPanel> {
  int? _draggedIndex;
  ImageLayer? _hoveredLayer;

  @override
  Widget build(BuildContext context) {
    if (widget.document == null) {
      return const Center(
        child: Text('No document', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    final visibleLayers = widget.document!.layers.where((l) => !l.isGroup).toList();

    return ReorderableListView.builder(
      onReorderItem: _onReorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          color: AppTheme.surfaceHoverColor,
          child: child,
        );
      },
      buildDefaultDragHandles: false,
      itemCount: visibleLayers.length,
      itemBuilder: (context, index) {
        final layer = visibleLayers[index];
        final isSelected = widget.selectedLayers.contains(layer);
        final originalIndex = widget.document!.layers.indexOf(layer);

        return _LayerTile(
          key: ValueKey(layer.id),
          layer: layer,
          index: originalIndex,
          isSelected: isSelected,
          isHovered: _hoveredLayer?.id == layer.id,
          onTap: () => _onLayerTap(layer),
          onVisibilityChanged: (visible) => widget.onLayerVisibilityChanged(layer, visible),
          onOpacityChanged: (opacity) => widget.onLayerOpacityChanged(layer, opacity),
          onBlendModeChanged: (blendMode) => widget.onLayerBlendModeChanged(layer, blendMode),
          onDragStarted: () => _draggedIndex = originalIndex,
          onDragEnd: () => _draggedIndex = null,
          onHover: (hovering) => setState(() => _hoveredLayer = hovering ? layer : null),
        );
      },
    );
  }

  void _onLayerTap(ImageLayer layer) {
    final isSelected = widget.selectedLayers.contains(layer);
    if (HardwareKeyboard.instance.isShiftPressed) {
      final newSelection = List<ImageLayer>.from(widget.selectedLayers);
      if (isSelected) {
        newSelection.remove(layer);
      } else {
        newSelection.add(layer);
      }
      widget.onSelectionChanged(newSelection);
    } else if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) {
      final newSelection = List<ImageLayer>.from(widget.selectedLayers);
      if (isSelected) {
        newSelection.remove(layer);
      } else {
        newSelection.add(layer);
      }
      widget.onSelectionChanged(newSelection);
    } else {
      widget.onSelectionChanged([layer]);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_draggedIndex == null) return;

    final visibleLayers = widget.document!.layers.where((l) => !l.isGroup).toList();
    if (_draggedIndex! < 0 || _draggedIndex! >= visibleLayers.length) return;
    if (newIndex < 0 || newIndex >= visibleLayers.length) return;

    final draggedLayer = visibleLayers[_draggedIndex!];
    final targetLayer = visibleLayers[newIndex];

    final oldOriginalIndex = widget.document!.layers.indexOf(draggedLayer);
    final newOriginalIndex = widget.document!.layers.indexOf(targetLayer);

    if (oldOriginalIndex != newOriginalIndex) {
      widget.onLayerReorder(oldOriginalIndex, newOriginalIndex);
    }
  }
}

class _LayerTile extends StatefulWidget {
  final ImageLayer layer;
  final int index;
  final bool isSelected;
  final bool isHovered;
  final VoidCallback onTap;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<BlendMode> onBlendModeChanged;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final ValueChanged<bool> onHover;

  const _LayerTile({
    super.key,
    required this.layer,
    required this.index,
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
    required this.onVisibilityChanged,
    required this.onOpacityChanged,
    required this.onBlendModeChanged,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onHover,
  });

  @override
  State<_LayerTile> createState() => _LayerTileState();
}

class _LayerTileState extends State<_LayerTile> {
  late double _opacity;
  late BlendMode _blendMode;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _opacity = widget.layer.opacity;
    _blendMode = widget.layer.blendMode;
  }

  @override
  Widget build(BuildContext context) {
    final indent = _calculateIndent();

    return MouseRegion(
      onEnter: (_) => widget.onHover(true),
      onExit: (_) => widget.onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: widget.isSelected
            ? AppTheme.selectionBlue.withValues(alpha: 0.2)
            : (widget.isHovered ? AppTheme.hoverOverlay : Colors.transparent),
        child: Column(
          children: [
            _buildMainRow(indent),
            if (_isExpanded) _buildExpandedControls(indent),
          ],
        ),
      ),
    );
  }

  int _calculateIndent() {
    int indent = 0;
    var current = widget.layer;
    while (current.parentID != null) {
      indent++;
      current = current; // Would need to look up parent in document
    }
    return indent;
  }

  Widget _buildMainRow(int indent) {
    return Container(
      height: 36,
      padding: EdgeInsets.only(left: 8 + indent * 16, right: 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              child: const Icon(
                Icons.drag_indicator,
                size: 16,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => widget.onVisibilityChanged(!widget.layer.isVisible),
            child: Icon(
              widget.layer.isVisible ? Icons.visibility : Icons.visibility_off,
              size: 18,
              color: widget.layer.isVisible ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          _buildThumbnail(),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: widget.onTap,
              onDoubleTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(
                widget.layer.name,
                style: AppTheme.layerNameStyle.copyWith(
                  color: widget.layer.isVisible ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildBlendModeDropdown(),
          const SizedBox(width: 8),
          _buildOpacitySlider(),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(3),
      ),
      child: widget.layer.asset != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.memory(
                _createThumbnail(widget.layer.asset!.rgba,
                    widget.layer.asset!.width, widget.layer.asset!.height),
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            )
          : Container(
              color: AppTheme.surfaceColor,
              child: const Icon(Icons.layers, size: 16, color: AppTheme.textMuted),
            ),
    );
  }

  Widget _buildBlendModeDropdown() {
    return SizedBox(
      width: 100,
      child: BlendModeDropdown(
        value: _blendMode,
        onChanged: (mode) {
          setState(() => _blendMode = mode);
          widget.onBlendModeChanged(mode);
        },
        dense: true,
      ),
    );
  }

  Widget _buildOpacitySlider() {
    return SizedBox(
      width: 70,
      child: Slider(
        value: _opacity,
        min: 0.0,
        max: 1.0,
        onChanged: (value) {
          setState(() => _opacity = value);
          widget.onOpacityChanged(value);
        },
        activeColor: AppTheme.accentBlue,
        inactiveColor: AppTheme.borderColor,
      ),
    );
  }

  Widget _buildExpandedControls(int indent) {
    return Container(
      padding: EdgeInsets.only(left: 40 + indent * 16, right: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Opacity ', style: AppTheme.layerNameSmallStyle),
              Text('${(_opacity * 100).round()}%', style: AppTheme.layerNameSmallStyle),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Blend ', style: AppTheme.layerNameSmallStyle),
              BlendModeDropdown(
                value: _blendMode,
                onChanged: (mode) {
                  setState(() => _blendMode = mode);
                  widget.onBlendModeChanged(mode);
                },
                dense: true,
              ),
            ],
          ),
          if (widget.layer.mask != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Mask ', style: AppTheme.layerNameSmallStyle),
                Switch(
                  value: widget.layer.mask!.maskEnabled,
                  onChanged: (v) {},
                  activeThumbColor: AppTheme.accentBlue,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Uint8List _createThumbnail(Uint8List rgba, int width, int height) {
    const thumbSize = 28;
    final thumbRgba = Uint8List(thumbSize * thumbSize * 4);

    final scaleX = width / thumbSize;
    final scaleY = height / thumbSize;

    for (int y = 0; y < thumbSize; y++) {
      for (int x = 0; x < thumbSize; x++) {
        final srcX = (x * scaleX).clamp(0, width - 1).toInt();
        final srcY = (y * scaleY).clamp(0, height - 1).toInt();
        final srcIdx = (srcY * width + srcX) * 4;
        final dstIdx = (y * thumbSize + x) * 4;
        thumbRgba[dstIdx] = rgba[srcIdx];
        thumbRgba[dstIdx + 1] = rgba[srcIdx + 1];
        thumbRgba[dstIdx + 2] = rgba[srcIdx + 2];
        thumbRgba[dstIdx + 3] = rgba[srcIdx + 3];
      }
    }

    return thumbRgba;
  }
}