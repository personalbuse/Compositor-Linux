import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:compositor/core/model.dart';
import 'package:compositor/core/native_bindings.dart';
import 'package:compositor/io/comp.dart';
import 'package:compositor/render.dart';

/// Parity harness comparing the port's CPU render against macOS reference PNGs.
///
/// Run normal suite:      flutter test
/// Run parity comparison: flutter test test/parity --dart-define=PARITY=1
///
/// Reference PNGs live in `test/parity/expected/<fixture>.png` and are produced
/// on macOS per `tool/parity/generate_reference.md`. When a reference is
/// missing the harness falls back to a render-determinism check and reports it
/// as skipped (so CI stays green until references are committed).
const bool _parityEnabled = bool.fromEnvironment('PARITY');

const String _fixturesDir = 'test/fixtures';
const String _expectedDir = 'test/parity/expected';
const String _diffDir = 'test/parity/diff';

class _Tolerance {
  final int maxChannelDiff;
  final double meanAbsDiff;
  final double percentAbove2;

  const _Tolerance({
    required this.maxChannelDiff,
    required this.meanAbsDiff,
    required this.percentAbove2,
  });

  static const layers = _Tolerance(
    maxChannelDiff: 2,
    meanAbsDiff: 0.5,
    percentAbove2: 1.0,
  );

  static const resampling = _Tolerance(
    maxChannelDiff: 4,
    meanAbsDiff: 1.0,
    percentAbove2: 3.0,
  );
}

_Tolerance _toleranceFor(String fixture) {
  if (fixture.startsWith('rotated') ||
      fixture.startsWith('flipped') ||
      fixture.startsWith('offset_scaled') ||
      fixture.startsWith('sampling_')) {
    return _Tolerance.resampling;
  }
  return _Tolerance.layers;
}

Future<Uint8List?> _renderFixture(String compPath) async {
  final document = await ProjectStore.readComp(Directory(compPath));
  final assets = <String, ImportedImage>{};
  for (final layer in document.layers) {
    if (layer.asset != null) {
      assets[layer.id] = layer.asset!;
    }
  }
  final renderer = DocumentRenderer(document: document, assets: assets);
  final context = RenderContext(
    canvasWidth: document.width,
    canvasHeight: document.height,
    devicePixelRatio: 1.0,
    zoom: 1.0,
    panX: 0,
    panY: 0,
  );
  return renderer.renderToPngBytes(context);
}

img.Image? _decode(Uint8List bytes) => img.decodePng(bytes);

class _DiffResult {
  final int maxChannelDiff;
  final double meanAbsDiff;
  final double percentAbove2;
  final bool sizeMismatch;

  _DiffResult({
    required this.maxChannelDiff,
    required this.meanAbsDiff,
    required this.percentAbove2,
    required this.sizeMismatch,
  });

  bool passes(_Tolerance tol) {
    if (sizeMismatch) return false;
    return maxChannelDiff <= tol.maxChannelDiff &&
        meanAbsDiff <= tol.meanAbsDiff &&
        percentAbove2 <= tol.percentAbove2;
  }

  @override
  String toString() =>
      'max=$maxChannelDiff mean=${meanAbsDiff.toStringAsFixed(3)} '
      'pct>2=${percentAbove2.toStringAsFixed(2)}%'
      '${sizeMismatch ? ' SIZE_MISMATCH' : ''}';
}

_DiffResult _compare(img.Image a, img.Image b) {
  if (a.width != b.width || a.height != b.height) {
    return _DiffResult(
      maxChannelDiff: 255,
      meanAbsDiff: 255,
      percentAbove2: 100,
      sizeMismatch: true,
    );
  }

  final pa = a.getBytes(order: img.ChannelOrder.rgba);
  final pb = b.getBytes(order: img.ChannelOrder.rgba);

  int maxDiff = 0;
  double sum = 0;
  int above2 = 0;
  int channelCount = 0;

  for (int i = 0; i < pa.length; i++) {
    // Compare RGB only when both fully transparent (avoid alpha noise).
    final diff = (pa[i] - pb[i]).abs();
    if (diff > maxDiff) maxDiff = diff;
    sum += diff;
    if (diff > 2) above2++;
    channelCount++;
  }

  return _DiffResult(
    maxChannelDiff: maxDiff,
    meanAbsDiff: channelCount == 0 ? 0 : sum / channelCount,
    percentAbove2: channelCount == 0 ? 0 : 100 * above2 / channelCount,
    sizeMismatch: false,
  );
}

void main() {
  final fixturesRoot = Directory(_fixturesDir);

  setUpAll(() {
    NativeBindings.initialize();
  });

  group('Parity fixtures', () {
    if (!fixturesRoot.existsSync()) {
      test('fixtures generated', () {
        fail('No fixtures found. Run: dart run tool/parity/generate_fixtures.dart');
      });
      return;
    }

    final comps = fixturesRoot
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.endsWith('.comp'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    test('at least 20 fixtures available', () {
      expect(comps.length, greaterThanOrEqualTo(20));
    });

    for (final comp in comps) {
      final name = comp.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last
          .replaceAll('.comp', '');

      test('$name renders', () async {
        final bytes = await _renderFixture(comp.path);
        expect(bytes, isNotNull, reason: 'render returned null');
        expect(bytes!.length, greaterThan(0));
      });

      test('$name deterministic', () async {
        final first = await _renderFixture(comp.path);
        final second = await _renderFixture(comp.path);
        expect(first, isNotNull);
        expect(second, isNotNull);
        expect(
          _bytesEqual(first!, second!),
          isTrue,
          reason: 'render must be deterministic across runs',
        );
      });

      test('$name matches reference', () async {
        if (!_parityEnabled) {
          markTestSkipped('PARITY=1 not set');
          return;
        }

        final expectedFile = File('$_expectedDir/$name.png');
        if (!expectedFile.existsSync()) {
          markTestSkipped('no reference at ${expectedFile.path}');
          return;
        }

        final renderedBytes = await _renderFixture(comp.path);
        final rendered = _decode(renderedBytes!);
        final expected = _decode(await expectedFile.readAsBytes());

        expect(rendered, isNotNull, reason: 'failed to decode port render');
        expect(expected, isNotNull, reason: 'failed to decode reference');

        final result = _compare(expected!, rendered!);
        final tolerance = _toleranceFor(name);

        if (!result.passes(tolerance)) {
          _writeDiff(name, expected, rendered);
        }

        expect(
          result.passes(tolerance),
          isTrue,
          reason: '$name divergence $result '
              '(tol max=${tolerance.maxChannelDiff} '
              'mean=${tolerance.meanAbsDiff} '
              'pct=${tolerance.percentAbove2}%)',
        );
      });
    }
  });
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void _writeDiff(String name, img.Image expected, img.Image rendered) {
  try {
    final dir = Directory(_diffDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final composite = img.Image(
      width: expected.width + rendered.width,
      height: expected.height > rendered.height ? expected.height : rendered.height,
    );
    img.compositeImage(composite, expected, dstX: 0, dstY: 0);
    img.compositeImage(composite, rendered, dstX: expected.width, dstY: 0);
    File('$_diffDir/$name.png').writeAsBytesSync(img.encodePng(composite));
  } catch (_) {
    // Diagnostics only; never fail the test because of diff output.
  }
}
