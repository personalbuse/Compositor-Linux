import 'package:flutter/material.dart';
import 'package:compositor/ui/theme/app_theme.dart';
import 'package:compositor/core/model.dart';

class BlendModeDropdown extends StatelessWidget {
  final BlendMode value;
  final ValueChanged<BlendMode> onChanged;
  final bool dense;

  const BlendModeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<BlendMode>(
      value: value,
      onChanged: (mode) => onChanged(mode!),
      isExpanded: true,
      isDense: dense,
      underline: const SizedBox(),
      icon: Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.textSecondary),
      iconSize: 16,
      dropdownColor: AppTheme.surfaceColor,
      style: dense ? AppTheme.layerNameSmallStyle : AppTheme.layerNameStyle,
      selectedItemBuilder: (context) => BlendMode.values.map((mode) {
        return Text(
          _shortName(mode),
          style: dense ? AppTheme.layerNameSmallStyle : AppTheme.layerNameStyle,
          overflow: TextOverflow.ellipsis,
        );
      }).toList(),
      items: BlendMode.values.map((mode) {
        return DropdownMenuItem<BlendMode>(
          value: mode,
          child: Text(
            mode.displayName,
            style: dense ? AppTheme.layerNameSmallStyle : AppTheme.layerNameStyle,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  String _shortName(BlendMode mode) {
    switch (mode) {
      case BlendMode.normal:
        return 'Normal';
      case BlendMode.darken:
        return 'Darken';
      case BlendMode.multiply:
        return 'Multiply';
      case BlendMode.colorBurn:
        return 'Color Burn';
      case BlendMode.linearBurn:
        return 'Linear Burn';
      case BlendMode.lighten:
        return 'Lighten';
      case BlendMode.screen:
        return 'Screen';
      case BlendMode.colorDodge:
        return 'Color Dodge';
      case BlendMode.linearDodge:
        return 'Linear Dodge';
      case BlendMode.overlay:
        return 'Overlay';
      case BlendMode.softLight:
        return 'Soft Light';
      case BlendMode.hardLight:
        return 'Hard Light';
      case BlendMode.vividLight:
        return 'Vivid Light';
      case BlendMode.linearLight:
        return 'Linear Light';
      case BlendMode.pinLight:
        return 'Pin Light';
      case BlendMode.hardMix:
        return 'Hard Mix';
      case BlendMode.difference:
        return 'Difference';
      case BlendMode.exclusion:
        return 'Exclusion';
      case BlendMode.subtract:
        return 'Subtract';
      case BlendMode.divide:
        return 'Divide';
      case BlendMode.hue:
        return 'Hue';
      case BlendMode.saturation:
        return 'Saturation';
      case BlendMode.color:
        return 'Color';
      case BlendMode.luminosity:
        return 'Luminosity';
    }
  }
}