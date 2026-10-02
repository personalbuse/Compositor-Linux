import 'package:flutter/material.dart';
import 'package:compositor/ui/theme/app_theme.dart';
import 'package:compositor/ui/canvas/viewport.dart';

class ToolHeader extends StatelessWidget {
  final Tool activeTool;
  final double brushSize;
  final double brushHardness;
  final double brushOpacity;
  final Color brushColor;
  final bool brushIsEraser;
  final ValueChanged<double> onBrushSizeChanged;
  final ValueChanged<double> onBrushHardnessChanged;
  final ValueChanged<double> onBrushOpacityChanged;
  final ValueChanged<Color> onBrushColorChanged;
  final ValueChanged<bool>? onBrushModeChanged;

  const ToolHeader({
    super.key,
    required this.activeTool,
    required this.brushSize,
    required this.brushHardness,
    required this.brushOpacity,
    required this.brushColor,
    this.brushIsEraser = false,
    required this.onBrushSizeChanged,
    required this.onBrushHardnessChanged,
    required this.onBrushOpacityChanged,
    required this.onBrushColorChanged,
    this.onBrushModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (activeTool) {
      case Tool.brush:
        return _buildBrushHeader(context);
      case Tool.move:
        return _buildMoveHeader();
      case Tool.hand:
        return _buildHandHeader();
      case Tool.zoom:
        return _buildZoomHeader();
      case Tool.eyedropper:
        return _buildEyedropperHeader();
      default:
        return _buildDisabledHeader();
    }
  }

  Widget _buildBrushHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Brush',
            style: AppTheme.layerNameStyle.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 24),
          _buildSliderGroup(
            label: 'Size',
            value: brushSize,
            min: 1,
            max: 2000,
            onChanged: onBrushSizeChanged,
            formatter: (v) => '${v.round()}',
          ),
          const SizedBox(width: 24),
          _buildSliderGroup(
            label: 'Hardness',
            value: brushHardness,
            min: 0.0,
            max: 1.0,
            onChanged: onBrushHardnessChanged,
            formatter: (v) => '${(v * 100).round()}%',
          ),
          const SizedBox(width: 24),
          _buildSliderGroup(
            label: 'Opacity',
            value: brushOpacity,
            min: 0.0,
            max: 1.0,
            onChanged: onBrushOpacityChanged,
            formatter: (v) => '${(v * 100).round()}%',
          ),
          const SizedBox(width: 24),
          _buildColorPicker(context),
          const SizedBox(width: 32),
          _buildBrushModeButtons(),
        ],
      ),
    );
  }

  Widget _buildMoveHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Move Tool',
            style: AppTheme.layerNameStyle.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 24),
          _buildActionButton('Auto-Select', Icons.touch_app, () {}),
          const SizedBox(width: 8),
          _buildActionButton('Show Transform', Icons.transform, () {}),
        ],
      ),
    );
  }

  Widget _buildHandHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Hand Tool',
            style: AppTheme.layerNameStyle.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 24),
          _buildActionButton('Scroll All Windows', Icons.sync, () {}),
        ],
      ),
    );
  }

  Widget _buildZoomHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Zoom Tool',
            style: AppTheme.layerNameStyle.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 24),
          _buildActionButton('Zoom In', Icons.add, () {}),
          const SizedBox(width: 8),
          _buildActionButton('Zoom Out', Icons.remove, () {}),
          const SizedBox(width: 8),
          _buildActionButton('Fit', Icons.fit_screen, () {}),
          const SizedBox(width: 8),
          _buildActionButton('100%', Icons.zoom_out_map, () {}),
        ],
      ),
    );
  }

  Widget _buildEyedropperHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Eyedropper',
            style: AppTheme.layerNameStyle.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 24),
          _buildActionButton('Sample All Layers', Icons.layers, () {}),
          const SizedBox(width: 8),
          _buildActionButton('Show Sample Ring', Icons.circle_outlined, () {}),
        ],
      ),
    );
  }

  Widget _buildDisabledHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            activeTool.name,
            style: AppTheme.layerNameStyle.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 24),
          const Text(
            'Not available in MVP',
            style: AppTheme.layerNameSmallStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderGroup({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String Function(double) formatter,
  }) {
    return SizedBox(
      width: 140,
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: AppTheme.layerNameSmallStyle),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
              activeColor: AppTheme.accentBlue,
              inactiveColor: AppTheme.borderColor,
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              formatter(value),
              style: AppTheme.layerNameSmallStyle.copyWith(
                fontFamily: 'monospace',
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(BuildContext context) {
    return GestureDetector(
      onTap: () => _showColorPicker(context),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: brushColor,
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildActionButton(String tooltip, IconData icon, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 18, color: AppTheme.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildBrushModeButtons() {
    return Row(
      children: [
        _buildModeButton('Paint', Icons.brush, !brushIsEraser, () {
          onBrushModeChanged?.call(false);
        }),
        _buildModeButton('Erase', Icons.cleaning_services, brushIsEraser, () {
          onBrushModeChanged?.call(true);
        }),
      ],
    );
  }

  Widget _buildModeButton(String tooltip, IconData icon, bool isActive, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isActive
                  ? Border.all(color: Colors.white.withValues(alpha: 0.14))
                  : null,
            ),
            child: Icon(icon, size: 18, color: AppTheme.textPrimary),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initialColor: brushColor,
        onColorSelected: onBrushColorChanged,
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerDialog({
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    final hsv = HSVColor.fromColor(_selectedColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      title: const Text('Color Picker'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHueSlider(),
            const SizedBox(height: 16),
            _buildSaturationValuePicker(),
            const SizedBox(height: 16),
            _buildColorPreview(),
            const SizedBox(height: 16),
            _buildHexInput(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onColorSelected(_selectedColor);
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildHueSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hue', style: AppTheme.layerNameSmallStyle),
        Slider(
          value: _hue,
          min: 0,
          max: 360,
          divisions: 360,
          onChanged: (value) {
            setState(() {
              _hue = value;
              _updateColor();
            });
          },
          activeColor: AppTheme.accentBlue,
        ),
      ],
    );
  }

  Widget _buildSaturationValuePicker() {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: CustomPaint(
              painter: _SaturationValuePainter(hue: _hue),
              size: Size.infinite,
            ),
          ),
          Positioned(
            left: _saturation * 298,
            top: (1 - _value) * 198,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final local = renderBox.globalToLocal(details.globalPosition);
                setState(() {
                  _saturation = (local.dx / 300).clamp(0.0, 1.0);
                  _value = (1 - local.dy / 200).clamp(0.0, 1.0);
                  _updateColor();
                });
              },
              onTapDown: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final local = renderBox.globalToLocal(details.globalPosition);
                setState(() {
                  _saturation = (local.dx / 300).clamp(0.0, 1.0);
                  _value = (1 - local.dy / 200).clamp(0.0, 1.0);
                  _updateColor();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPreview() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.initialColor,
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _selectedColor,
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildHexInput() {
    final hex = _selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return TextField(
      decoration: InputDecoration(
        labelText: 'Hex',
        prefixText: '#',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      ),
      controller: TextEditingController(text: hex.toUpperCase()),
      onChanged: (value) {
        if (value.length == 6) {
          try {
            final color = Color(int.parse('FF$value', radix: 16));
            setState(() {
              _selectedColor = color;
              final hsv = HSVColor.fromColor(color);
              _hue = hsv.hue;
              _saturation = hsv.saturation;
              _value = hsv.value;
            });
          } catch (_) {}
        }
      },
    );
  }

  void _updateColor() {
    _selectedColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }
}

class _SaturationValuePainter extends CustomPainter {
  final double hue;

  _SaturationValuePainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Saturation gradient (horizontal)
    final saturationGradient = LinearGradient(
      colors: [
        HSVColor.fromAHSV(1.0, hue, 0.0, 1.0).toColor(),
        HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor(),
      ],
    );

    // Value gradient (vertical)
    const valueGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Colors.transparent,
      ],
    );

    final saturationPaint = Paint()
      ..shader = saturationGradient.createShader(rect);
    canvas.drawRect(rect, saturationPaint);

    final valuePaint = Paint()
      ..shader = valueGradient.createShader(rect)
      ..blendMode = BlendMode.multiply;
    canvas.drawRect(rect, valuePaint);
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      oldDelegate.hue != hue;
}