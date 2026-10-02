import 'dart:io';
import 'dart:typed_data';

import 'package:compositor/core/model.dart';
import 'package:compositor/io/comp.dart';

/// Generates the MVP parity fixtures as `.comp` packages under `test/fixtures/`.
///
/// Usage:
///   dart run tool/parity/generate_fixtures.dart [--large]
///
/// The `--large` flag additionally generates the 10 MP performance fixture
/// (excluded by default to keep the repository small).
Future<void> main(List<String> args) async {
  final generateLarge = args.contains('--large');
  final root = Directory('test/fixtures');
  if (!root.existsSync()) {
    root.createSync(recursive: true);
  }

  final fixtures = <String, CanvasDocument Function()>{
    'single_layer': _singleLayer,
    'offset_scaled': _offsetScaled,
    'rotated': _rotated,
    'flipped_x': _flippedX,
    'flipped_y': _flippedY,
    'sampling_nearest': () => _samplingFixture(TransformSampling.nearest),
    'sampling_smooth': () => _samplingFixture(TransformSampling.smooth),
    'sampling_high_quality': () => _samplingFixture(TransformSampling.highQuality),
    'blend_normal_opacity': _blendNormalOpacity,
    'blend_darken_group': () => _blendGroup([
          BlendMode.darken,
          BlendMode.multiply,
          BlendMode.colorBurn,
          BlendMode.linearBurn,
        ]),
    'blend_lighten_group': () => _blendGroup([
          BlendMode.lighten,
          BlendMode.screen,
          BlendMode.colorDodge,
          BlendMode.linearDodge,
        ]),
    'blend_contrast_group': () => _blendGroup([
          BlendMode.overlay,
          BlendMode.softLight,
          BlendMode.hardLight,
          BlendMode.vividLight,
          BlendMode.linearLight,
          BlendMode.pinLight,
          BlendMode.hardMix,
        ]),
    'blend_comparison_group': () => _blendGroup([
          BlendMode.difference,
          BlendMode.exclusion,
          BlendMode.subtract,
          BlendMode.divide,
        ]),
    'blend_component_group': () => _blendGroup([
          BlendMode.hue,
          BlendMode.saturation,
          BlendMode.color,
          BlendMode.luminosity,
        ]),
    'mask_basic': _maskBasic,
    'groups_nested': _groupsNested,
    'group_mask': _groupMask,
    'transparent_edges': _transparentEdges,
    'checker_10px': _checker,
    'gradient_overlay': _gradientOverlay,
  };

  if (generateLarge) {
    fixtures['large_10mp'] = _large10mp;
  }

  for (final entry in fixtures.entries) {
    final dir = Directory('${root.path}/${entry.key}.comp');
    final doc = entry.value();
    await ProjectStore.writeComp(doc, dir, overwrite: true);
    stdout.writeln('Generated ${dir.path}');
  }

  stdout.writeln('${fixtures.length} fixture(s) written to ${root.path}');
}

String _uuid(int index) {
  final suffix = index.toRadixString(16).padLeft(12, '0').toUpperCase();
  return '00000000-0000-0000-0000-$suffix';
}

CanvasDocument _doc(String id, int width, int height, List<ImageLayer> layers) {
  return CanvasDocument(
    id: _uuid(id.hashCode & 0xFFF),
    width: width,
    height: height,
    layers: layers,
    activeLayerID: layers.isEmpty ? null : layers.last.id,
  );
}

ImageLayer _layer({
  required String id,
  required String name,
  required ImportedImage asset,
  required int canvasWidth,
  required int canvasHeight,
  double originX = 0,
  double originY = 0,
  double? sizeWidth,
  double? sizeHeight,
  double rotation = 0,
  bool flipX = false,
  bool flipY = false,
  TransformSampling sampling = TransformSampling.highQuality,
  double opacity = 1.0,
  BlendMode blendMode = BlendMode.normal,
  bool isVisible = true,
  bool isGroup = false,
  String? parentID,
  LayerMask? mask,
}) {
  return ImageLayer(
    id: id,
    name: name,
    asset: isGroup ? null : asset,
    transform: LayerTransform(
      originX: originX,
      originY: originY,
      sizeWidth: sizeWidth ?? canvasWidth.toDouble(),
      sizeHeight: sizeHeight ?? canvasHeight.toDouble(),
      rotation: rotation,
      flipX: flipX,
      flipY: flipY,
      sampling: sampling,
    ),
    isVisible: isVisible,
    isGroup: isGroup,
    parentID: parentID,
    opacity: opacity,
    blendMode: blendMode,
    mask: mask,
  );
}

// ---------------------------------------------------------------------------
// Image builders
// ---------------------------------------------------------------------------

Uint8List _solid(int w, int h, int r, int g, int b, int a) {
  final data = Uint8List(w * h * 4);
  for (int i = 0; i < data.length; i += 4) {
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
    data[i + 3] = a;
  }
  return data;
}

ImportedImage _solidImage(String name, int w, int h, int r, int g, int b, [int a = 255]) {
  return ImportedImage(name: name, rgba: _solid(w, h, r, g, b, a), width: w, height: h);
}

/// Horizontal gradient with premultiplied alpha.
ImportedImage _gradientImage(String name, int w, int h, {bool alphaRamp = false}) {
  final data = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final t = w <= 1 ? 0.0 : x / (w - 1);
      final a = alphaRamp ? (t * 255).round() : 255;
      final r = (255 * t).round();
      final g = (255 * (1 - t)).round();
      const b = 128;
      final idx = (y * w + x) * 4;
      // Premultiply
      data[idx] = (r * a / 255).round();
      data[idx + 1] = (g * a / 255).round();
      data[idx + 2] = (b * a / 255).round();
      data[idx + 3] = a;
    }
  }
  return ImportedImage(name: name, rgba: data, width: w, height: h);
}

ImportedImage _checkerImage(String name, int w, int h, int cell) {
  final data = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final light = ((x ~/ cell) + (y ~/ cell)) % 2 == 0;
      final v = light ? 220 : 40;
      final idx = (y * w + x) * 4;
      data[idx] = v;
      data[idx + 1] = v;
      data[idx + 2] = v;
      data[idx + 3] = 255;
    }
  }
  return ImportedImage(name: name, rgba: data, width: w, height: h);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

CanvasDocument _singleLayer() {
  return _doc('single_layer', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Background',
      asset: _gradientImage('bg', 256, 256),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
  ]);
}

CanvasDocument _offsetScaled() {
  return _doc('offset_scaled', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Background',
      asset: _solidImage('bg', 256, 256, 200, 200, 200),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
    _layer(
      id: _uuid(2),
      name: 'Inset',
      asset: _gradientImage('inset', 128, 128),
      canvasWidth: 256,
      canvasHeight: 256,
      originX: 64,
      originY: 64,
      sizeWidth: 128,
      sizeHeight: 128,
    ),
  ]);
}

CanvasDocument _rotated() {
  return _doc('rotated', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Background',
      asset: _solidImage('bg', 256, 256, 30, 30, 30),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
    _layer(
      id: _uuid(2),
      name: 'Rotated',
      asset: _checkerImage('rot', 128, 128, 16),
      canvasWidth: 256,
      canvasHeight: 256,
      originX: 64,
      originY: 64,
      sizeWidth: 128,
      sizeHeight: 128,
      rotation: 30,
    ),
  ]);
}

CanvasDocument _flippedX() {
  return _doc('flipped_x', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Flipped',
      asset: _gradientImage('flip', 256, 256),
      canvasWidth: 256,
      canvasHeight: 256,
      flipX: true,
    ),
  ]);
}

CanvasDocument _flippedY() {
  return _doc('flipped_y', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Flipped',
      asset: _checkerImage('flip', 256, 256, 16),
      canvasWidth: 256,
      canvasHeight: 256,
      flipY: true,
    ),
  ]);
}

CanvasDocument _samplingFixture(TransformSampling sampling) {
  final name = 'sampling_${sampling.name}';
  return _doc(name, 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Backdrop',
      asset: _solidImage('bg', 256, 256, 90, 90, 90),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
    _layer(
      id: _uuid(2),
      name: 'Downscaled',
      asset: _checkerImage('src', 256, 256, 4),
      canvasWidth: 256,
      canvasHeight: 256,
      originX: 48,
      originY: 48,
      sizeWidth: 160,
      sizeHeight: 160,
      sampling: sampling,
    ),
  ]);
}

CanvasDocument _blendNormalOpacity() {
  return _doc('blend_normal_opacity', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Backdrop',
      asset: _gradientImage('bg', 256, 256),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
    _layer(
      id: _uuid(2),
      name: 'Overlay 50%',
      asset: _solidImage('ov', 256, 256, 0, 80, 255),
      canvasWidth: 256,
      canvasHeight: 256,
      opacity: 0.5,
    ),
  ]);
}

CanvasDocument _blendGroup(List<BlendMode> modes) {
  final name = 'blend_${modes.first.name}_group';
  final layers = <ImageLayer>[
    _layer(
      id: _uuid(1),
      name: 'Backdrop',
      asset: _gradientImage('bg', 256, 256),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
  ];

  final rows = modes.length;
  final rowHeight = (256 / rows).floor();
  for (int i = 0; i < rows; i++) {
    layers.add(_layer(
      id: _uuid(10 + i),
      name: modes[i].displayName,
      asset: _gradientImage('src$i', 256, rowHeight, alphaRamp: true),
      canvasWidth: 256,
      canvasHeight: 256,
      originX: 0,
      originY: (i * rowHeight).toDouble(),
      sizeWidth: 256,
      sizeHeight: rowHeight.toDouble(),
      blendMode: modes[i],
    ));
  }

  return _doc(name, 256, 256, layers);
}

CanvasDocument _maskBasic() {
  return _doc('mask_basic', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Backdrop',
      asset: _solidImage('bg', 256, 256, 20, 20, 20),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
    _layer(
      id: _uuid(2),
      name: 'Masked',
      asset: _gradientImage('masked', 256, 256),
      canvasWidth: 256,
      canvasHeight: 256,
      mask: LayerMask(
        maskFile: '${_uuid(2)}.mask.png',
        maskEnabled: true,
      ),
    ),
  ]);
}

CanvasDocument _groupsNested() {
  final groupId = _uuid(2);
  final innerGroupId = _uuid(3);
  return _doc('groups_nested', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Background',
      asset: _solidImage('bg', 256, 256, 15, 15, 15),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
    _layer(
      id: groupId,
      name: 'Group',
      asset: ImportedImage(name: 'group', rgba: Uint8List(0), width: 0, height: 0),
      canvasWidth: 256,
      canvasHeight: 256,
      isGroup: true,
      opacity: 0.9,
    ),
    _layer(
      id: innerGroupId,
      name: 'Inner Group',
      asset: ImportedImage(name: 'inner', rgba: Uint8List(0), width: 0, height: 0),
      canvasWidth: 256,
      canvasHeight: 256,
      isGroup: true,
      parentID: groupId,
      opacity: 0.8,
    ),
    _layer(
      id: _uuid(4),
      name: 'Child A',
      asset: _gradientImage('childA', 256, 256),
      canvasWidth: 256,
      canvasHeight: 256,
      parentID: innerGroupId,
    ),
    _layer(
      id: _uuid(5),
      name: 'Child B',
      asset: _checkerImage('childB', 256, 256, 32),
      canvasWidth: 256,
      canvasHeight: 256,
      parentID: groupId,
      opacity: 0.6,
    ),
  ]);
}

CanvasDocument _groupMask() {
  final groupId = _uuid(2);
  return _doc('group_mask', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Background',
      asset: _solidImage('bg', 256, 256, 0, 0, 0),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
    _layer(
      id: groupId,
      name: 'Masked Group',
      asset: ImportedImage(name: 'group', rgba: Uint8List(0), width: 0, height: 0),
      canvasWidth: 256,
      canvasHeight: 256,
      isGroup: true,
      mask: LayerMask(maskFile: '$groupId.mask.png', maskEnabled: true),
    ),
    _layer(
      id: _uuid(3),
      name: 'Child',
      asset: _gradientImage('child', 256, 256),
      canvasWidth: 256,
      canvasHeight: 256,
      parentID: groupId,
    ),
  ]);
}

CanvasDocument _transparentEdges() {
  return _doc('transparent_edges', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Radial Alpha',
      asset: _gradientImage('radial', 256, 256, alphaRamp: true),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
  ]);
}

CanvasDocument _checker() {
  return _doc('checker_10px', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Checker',
      asset: _checkerImage('checker', 256, 256, 10),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
  ]);
}

CanvasDocument _gradientOverlay() {
  return _doc('gradient_overlay', 256, 256, [
    _layer(
      id: _uuid(1),
      name: 'Base',
      asset: _solidImage('base', 256, 256, 240, 240, 240),
      canvasWidth: 256,
      canvasHeight: 256,
    ),
    _layer(
      id: _uuid(2),
      name: 'Gradient Multiply',
      asset: _gradientImage('grad', 256, 256, alphaRamp: true),
      canvasWidth: 256,
      canvasHeight: 256,
      blendMode: BlendMode.multiply,
      opacity: 0.8,
    ),
  ]);
}

CanvasDocument _large10mp() {
  const w = 3872; // ~10 MP (3872 x 2592)
  const h = 2592;
  return _doc('large_10mp', w, h, [
    _layer(
      id: _uuid(1),
      name: 'Background',
      asset: _gradientImage('bg', w, h),
      canvasWidth: w,
      canvasHeight: h,
    ),
    _layer(
      id: _uuid(2),
      name: 'Overlay',
      asset: _checkerImage('ov', 512, 512, 16),
      canvasWidth: w,
      canvasHeight: h,
      originX: 400,
      originY: 300,
      sizeWidth: 512,
      sizeHeight: 512,
      blendMode: BlendMode.overlay,
      opacity: 0.75,
    ),
  ]);
}
