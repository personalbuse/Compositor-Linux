import 'package:flutter/material.dart';
import 'package:compositor/ui/theme/app_theme.dart';

class _MenuItem {
  final String? label;
  final String? value;
  final String? shortcut;
  final bool enabled;

  const _MenuItem.action(this.label, this.value, {this.shortcut, this.enabled = true})
      : assert(label != null);
  const _MenuItem.separator()
      : label = null,
        value = null,
        shortcut = null,
        enabled = true;
}

class AppMenuBar extends StatelessWidget {
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
  final VoidCallback? onToggleLayerVisibility;
  final VoidCallback? onRaiseLayer;
  final VoidCallback? onLowerLayer;
  final VoidCallback? onDeleteLayer;
  final bool canUndo;
  final bool canRedo;
  final bool hasDocument;

  const AppMenuBar({
    super.key,
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
    this.onToggleLayerVisibility,
    this.onRaiseLayer,
    this.onLowerLayer,
    this.onDeleteLayer,
    this.canUndo = false,
    this.canRedo = false,
    this.hasDocument = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      color: AppTheme.toolbarBackground,
      child: Row(
        children: [
          _menu(context, 'File', [
            const _MenuItem.action('New Canvas', 'new', shortcut: 'Ctrl+N'),
            const _MenuItem.action('Open…', 'open', shortcut: 'Ctrl+O'),
            const _MenuItem.separator(),
            _MenuItem.action('Save', 'save', shortcut: 'Ctrl+S', enabled: hasDocument),
            _MenuItem.action('Save As…', 'saveAs', shortcut: 'Ctrl+Shift+S', enabled: hasDocument),
            _MenuItem.action('Export PNG…', 'export', shortcut: 'Ctrl+E', enabled: hasDocument),
            const _MenuItem.separator(),
            _MenuItem.action('Close Project', 'close', enabled: hasDocument),
          ]),
          _menu(context, 'Edit', [
            _MenuItem.action('Undo', 'undo', shortcut: 'Ctrl+Z', enabled: canUndo),
            _MenuItem.action('Redo', 'redo', shortcut: 'Ctrl+Y', enabled: canRedo),
          ]),
          _menu(context, 'View', [
            _MenuItem.action('Fit on Screen', 'fit', shortcut: 'Ctrl+0', enabled: hasDocument),
            _MenuItem.action('Actual Size', 'zoom100', shortcut: 'Ctrl+1', enabled: hasDocument),
            const _MenuItem.separator(),
            _MenuItem.action('Zoom In', 'zoomIn', shortcut: 'Ctrl+=', enabled: hasDocument),
            _MenuItem.action('Zoom Out', 'zoomOut', shortcut: 'Ctrl+-', enabled: hasDocument),
          ]),
          _menu(context, 'Layer', [
            _MenuItem.action('Toggle Visibility', 'toggleVis', enabled: hasDocument),
            const _MenuItem.separator(),
            _MenuItem.action('Bring Forward', 'raise', enabled: hasDocument),
            _MenuItem.action('Send Backward', 'lower', enabled: hasDocument),
            const _MenuItem.separator(),
            _MenuItem.action('Delete Layer', 'delete', enabled: hasDocument),
          ]),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, String label, List<_MenuItem> items) {
    return PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      color: AppTheme.surfaceColor,
      padding: EdgeInsets.zero,
      onSelected: (value) => _dispatch(value),
      itemBuilder: (context) => items.map((item) {
        if (item.label == null) {
          return const PopupMenuDivider(height: 8) as PopupMenuEntry<String>;
        }
        return PopupMenuItem<String>(
          value: item.value,
          enabled: item.enabled,
          height: 32,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label!,
                  style: AppTheme.layerNameSmallStyle.copyWith(
                    color: item.enabled ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
              ),
              if (item.shortcut != null)
                Text(
                  item.shortcut!,
                  style: AppTheme.layerNameSmallStyle.copyWith(color: AppTheme.textMuted),
                ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTheme.layerNameSmallStyle.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _dispatch(String value) {
    switch (value) {
      case 'new':
        onNewCanvas?.call();
      case 'open':
        onOpen?.call();
      case 'save':
        onSave?.call();
      case 'saveAs':
        onSaveAs?.call();
      case 'export':
        onExportPng?.call();
      case 'close':
        onCloseProject?.call();
      case 'undo':
        onUndo?.call();
      case 'redo':
        onRedo?.call();
      case 'fit':
        onFit?.call();
      case 'zoom100':
        onZoom100?.call();
      case 'zoomIn':
        onZoomIn?.call();
      case 'zoomOut':
        onZoomOut?.call();
      case 'toggleVis':
        onToggleLayerVisibility?.call();
      case 'raise':
        onRaiseLayer?.call();
      case 'lower':
        onLowerLayer?.call();
      case 'delete':
        onDeleteLayer?.call();
    }
  }
}
