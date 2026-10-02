// ignore_for_file: avoid_print
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

void main() {
  print('=== FFI Smoke Test ===');
  
  final libPath = _resolveLibrary();
  print('Loading library: $libPath');
  
  final dylib = DynamicLibrary.open(libPath);
  print('Library loaded successfully');
  
  _testBrushAlphaBounds(dylib);
  _testRgbaClampPremultiplied(dylib);
  _testCompositorBlend(dylib);
  _testResampleHalving(dylib);
  
  print('\n=== All tests passed! ===');
}

String _resolveLibrary() {
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  final buildDir = Directory('$scriptDir/../../build').absolute;
  
  if (Platform.isLinux) {
    final candidates = [
      '$buildDir/linux/x64/debug/bundle/lib/libcompositor_core.so',
      '$buildDir/linux/x64/release/bundle/lib/libcompositor_core.so',
      '$buildDir/debug/libcompositor_core.so',
      '$buildDir/release/libcompositor_core.so',
      '/home/daviuk/Documentos/Work/Compositor-Linux/build/linux/x64/debug/bundle/lib/libcompositor_core.so',
      '/home/daviuk/Documentos/Work/Compositor-Linux/build/linux/x64/release/bundle/lib/libcompositor_core.so',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return 'libcompositor_core.so';
  } else if (Platform.isWindows) {
    final candidates = [
      '$buildDir/windows/x64/runner/Debug/compositor_core.dll',
      '$buildDir/windows/x64/runner/Release/compositor_core.dll',
      '$buildDir/Debug/compositor_core.dll',
      '$buildDir/Release/compositor_core.dll',
      'compositor_core.dll',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return 'compositor_core.dll';
  }
  throw UnsupportedError('Platform not supported');
}

void _testBrushAlphaBounds(DynamicLibrary dylib) {
  print('\n--- Test: brush_alpha_bounds ---');
  
  final func = dylib
      .lookup<NativeFunction<Void Function(Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Pointer<IntPtr>)>>('brush_alpha_bounds')
      .asFunction<void Function(Pointer<Uint8>, int, int, int, Pointer<IntPtr>)>();
  
  const width = 16;
  const height = 16;
  const stride = width * 4;
  final buffer = calloc<Uint8>(height * stride);
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      int alpha = 0;
      if (x >= 4 && x < 12 && y >= 4 && y < 12) alpha = 255;
      buffer[y * stride + x * 4 + 3] = alpha;
    }
  }
  
  final bounds = calloc<IntPtr>(4);
  func(buffer, width, height, stride, bounds);
  
  final left = bounds[0];
  final top = bounds[1];
  final right = bounds[2];
  final bottom = bounds[3];
  
  print('Bounds: left=$left, top=$top, right=$right, bottom=$bottom');
  
  assert(left == 4, 'left expected 4 got $left');
  assert(top == 4, 'top expected 4 got $top');
  assert(right == 11, 'right expected 11 got $right');
  assert(bottom == 11, 'bottom expected 11 got $bottom');
  
  calloc.free(buffer);
  calloc.free(bounds);
  print('PASSED');
}

void _testRgbaClampPremultiplied(DynamicLibrary dylib) {
  print('\n--- Test: compositor_rgba_clamp_premultiplied ---');
  
  final func = dylib
      .lookup<NativeFunction<Void Function(Pointer<Uint8>, IntPtr)>>('compositor_rgba_clamp_premultiplied')
      .asFunction<void Function(Pointer<Uint8>, int)>();
  
  final buffer = calloc<Uint8>(4 * 4);
  
  buffer[0] = 200; buffer[1] = 100; buffer[2] = 50; buffer[3] = 128;
  buffer[4] = 255; buffer[5] = 255; buffer[6] = 255; buffer[7] = 0;
  buffer[8] = 0;   buffer[9] = 0;   buffer[10] = 0;  buffer[11] = 255;
  buffer[12] = 100; buffer[13] = 150; buffer[14] = 200; buffer[15] = 200;
  
  func(buffer, 4);
  
  assert(buffer[0] <= buffer[3], 'R should be <= alpha after clamp');
  assert(buffer[1] <= buffer[3], 'G should be <= alpha after clamp');
  assert(buffer[2] <= buffer[3], 'B should be <= alpha after clamp');
  
  assert(buffer[4] == 0 && buffer[5] == 0 && buffer[6] == 0, 'Zero alpha should zero RGB');
  
  print('Pixel 0: R=${buffer[0]} G=${buffer[1]} B=${buffer[2]} A=${buffer[3]}');
  print('Pixel 1: R=${buffer[4]} G=${buffer[5]} B=${buffer[6]} A=${buffer[7]} (zero alpha -> zero RGB)');
  print('Pixel 2: R=${buffer[8]} G=${buffer[9]} B=${buffer[10]} A=${buffer[11]}');
  print('Pixel 3: R=${buffer[12]} G=${buffer[13]} B=${buffer[14]} A=${buffer[15]}');
  
  calloc.free(buffer);
  print('PASSED');
}

void _testCompositorBlend(DynamicLibrary dylib) {
  print('\n--- Test: compositor_blend_pixel (Normal) ---');
  
  final func = dylib
      .lookup<NativeFunction<Void Function(Pointer<Uint8>, Pointer<Uint8>, Int32)>>('compositor_blend_pixel')
      .asFunction<void Function(Pointer<Uint8>, Pointer<Uint8>, int)>();
  
  final dst = calloc<Uint8>(4);
  final src = calloc<Uint8>(4);
  
  dst[0] = 100; dst[1] = 150; dst[2] = 200; dst[3] = 255;
  src[0] = 255; src[1] = 0;   src[2] = 0;   src[3] = 128;
  
  func(dst, src, 0);
  
  print('Result: R=${dst[0]} G=${dst[1]} B=${dst[2]} A=${dst[3]}');
  
  assert(dst[3] > 0, 'Alpha should be > 0');
  
  calloc.free(dst);
  calloc.free(src);
  print('PASSED');
}

void _testResampleHalving(DynamicLibrary dylib) {
  print('\n--- Test: compositor_halving_rgba ---');
  
  final func = dylib
      .lookup<NativeFunction<Int32 Function(Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Pointer<Uint8>, IntPtr)>>('compositor_halving_rgba')
      .asFunction<int Function(Pointer<Uint8>, int, int, int, Pointer<Uint8>, int)>();
  
  const srcW = 8, srcH = 8, srcStride = 32;
  const dstW = 4, dstH = 4, dstStride = 16;
  
  final src = calloc<Uint8>(srcH * srcStride);
  final dst = calloc<Uint8>(dstH * dstStride);
  
  for (int y = 0; y < srcH; y++) {
    for (int x = 0; x < srcW; x++) {
      int idx = y * srcStride + x * 4;
      src[idx] = (x * 32).toUnsigned(8);
      src[idx + 1] = (y * 32).toUnsigned(8);
      src[idx + 2] = 128;
      src[idx + 3] = 255;
    }
  }
  
  int result = func(src, srcW, srcH, srcStride, dst, dstStride);
  assert(result == 0, 'Halving failed with code $result');
  
  print('Halved 8x8 -> 4x4');
  for (int y = 0; y < dstH; y++) {
    for (int x = 0; x < dstW; x++) {
      int idx = y * dstStride + x * 4;
      print('  [$x,$y] R=${dst[idx]} G=${dst[idx+1]} B=${dst[idx+2]} A=${dst[idx+3]}');
    }
  }
  
  calloc.free(src);
  calloc.free(dst);
  print('PASSED');
}