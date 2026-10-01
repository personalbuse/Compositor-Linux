import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

class NativeBindings {
  static late final DynamicLibrary _lib;
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    _lib = _loadLibrary();
    _initialized = true;
  }

  static DynamicLibrary _loadLibrary() {
    final scriptDir = File(Platform.script.toFilePath()).parent.path;
    final buildDir = Directory('$scriptDir/../../build').absolute;
    final projectDir = Directory('$scriptDir/../..').absolute;

    if (Platform.isLinux) {
      final candidates = <String>[
        // flutter test runs from build directory
        '$buildDir/linux/x64/debug/bundle/lib/libcompositor_core.so',
        '$buildDir/linux/x64/release/bundle/lib/libcompositor_core.so',
        '$buildDir/debug/libcompositor_core.so',
        '$buildDir/release/libcompositor_core.so',
        // flutter run / build
        '$projectDir/build/linux/x64/debug/bundle/lib/libcompositor_core.so',
        '$projectDir/build/linux/x64/release/bundle/lib/libcompositor_core.so',
        // CMake build directory for compositor_core
        '$projectDir/build/linux/x64/debug/compositor_core/libcompositor_core.so',
        '$projectDir/build/linux/x64/release/compositor_core/libcompositor_core.so',
        // Additional test locations
        '/home/daviuk/Documentos/Work/Compositor-Linux/build/linux/x64/debug/compositor_core/libcompositor_core.so',
        '/home/daviuk/Documentos/Work/Compositor-Linux/build/linux/x64/release/compositor_core/libcompositor_core.so',
      ];
      for (final c in candidates) {
        if (File(c).existsSync()) return DynamicLibrary.open(c);
      }
      return DynamicLibrary.open('libcompositor_core.so');
    } else if (Platform.isWindows) {
      final candidates = [
        '$buildDir/windows/x64/runner/Debug/compositor_core.dll',
        '$buildDir/windows/x64/runner/Release/compositor_core.dll',
        '$buildDir/Debug/compositor_core.dll',
        '$buildDir/Release/compositor_core.dll',
        '$projectDir/build/windows/x64/runner/Debug/compositor_core.dll',
        '$projectDir/build/windows/x64/runner/Release/compositor_core.dll',
      ];
      for (final c in candidates) {
        if (File(c).existsSync()) return DynamicLibrary.open(c);
      }
      return DynamicLibrary.open('compositor_core.dll');
    }
    throw UnsupportedError('Platform not supported');
  }

  static Pointer<Uint8> _uint8ListToPointer(Uint8List list) {
    final ptr = calloc<Uint8>(list.length);
    final typedList = ptr.asTypedList(list.length);
    typedList.setAll(0, list);
    return ptr;
  }

  static Pointer<Int32> _int32ListToPointer(Int32List list) {
    final ptr = calloc<Int32>(list.length);
    final typedList = ptr.asTypedList(list.length);
    typedList.setAll(0, list);
    return ptr;
  }

  static void _copyPointerToUint8List(Pointer<Uint8> ptr, Uint8List list) {
    final typedList = ptr.asTypedList(list.length);
    list.setAll(0, typedList);
  }

  static void brushAlphaBounds(Uint8List rgba, int width, int height, int stride, Int32List bounds) {
    final func = _lib
        .lookup<NativeFunction<Void Function(Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Pointer<Int32>)>>('brush_alpha_bounds')
        .asFunction<void Function(Pointer<Uint8>, int, int, int, Pointer<Int32>)>();
    
    final rgbaPtr = _uint8ListToPointer(rgba);
    final boundsPtr = _int32ListToPointer(bounds);
    try {
      func(rgbaPtr, width, height, stride, boundsPtr);
    } finally {
      calloc.free(rgbaPtr);
      calloc.free(boundsPtr);
    }
  }

  static void rgbaClampPremultiplied(Uint8List rgba) {
    final func = _lib
        .lookup<NativeFunction<Void Function(Pointer<Uint8>, IntPtr)>>('compositor_rgba_clamp_premultiplied')
        .asFunction<void Function(Pointer<Uint8>, int)>();
    
    final rgbaPtr = _uint8ListToPointer(rgba);
    try {
      func(rgbaPtr, rgba.length ~/ 4);
      _copyPointerToUint8List(rgbaPtr, rgba);
    } finally {
      calloc.free(rgbaPtr);
    }
  }

  static void blendPixel(Uint8List dst, Uint8List src, int mode) {
    final func = _lib
        .lookup<NativeFunction<Void Function(Pointer<Uint8>, Pointer<Uint8>, Int32)>>('compositor_blend_pixel')
        .asFunction<void Function(Pointer<Uint8>, Pointer<Uint8>, int)>();
    
    final dstPtr = _uint8ListToPointer(dst);
    final srcPtr = _uint8ListToPointer(src);
    try {
      func(dstPtr, srcPtr, mode);
      _copyPointerToUint8List(dstPtr, dst);
    } finally {
      calloc.free(dstPtr);
      calloc.free(srcPtr);
    }
  }

  static int halvingRgba(Uint8List src, int srcW, int srcH, int srcStride, Uint8List dst, int dstStride) {
    final func = _lib
        .lookup<NativeFunction<Int32 Function(Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Pointer<Uint8>, IntPtr)>>('compositor_halving_rgba')
        .asFunction<int Function(Pointer<Uint8>, int, int, int, Pointer<Uint8>, int)>();
    
    final srcPtr = _uint8ListToPointer(src);
    final dstPtr = _uint8ListToPointer(dst);
    try {
      return func(srcPtr, srcW, srcH, srcStride, dstPtr, dstStride);
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
    }
  }

  static int halvingGray(Uint8List src, int srcW, int srcH, int srcStride, Uint8List dst, int dstStride) {
    final func = _lib
        .lookup<NativeFunction<Int32 Function(Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Pointer<Uint8>, IntPtr)>>('compositor_halving_gray')
        .asFunction<int Function(Pointer<Uint8>, int, int, int, Pointer<Uint8>, int)>();
    
    final srcPtr = _uint8ListToPointer(src);
    final dstPtr = _uint8ListToPointer(dst);
    try {
      return func(srcPtr, srcW, srcH, srcStride, dstPtr, dstStride);
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
    }
  }

  static int resampleRgba(Uint8List src, int srcW, int srcH, int srcStride,
                          Uint8List dst, int dstW, int dstH, int dstStride, int method) {
    final func = _lib
        .lookup<NativeFunction<Int32 Function(Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Int32)>>('compositor_resample_rgba')
        .asFunction<int Function(Pointer<Uint8>, int, int, int, Pointer<Uint8>, int, int, int, int)>();
    
    final srcPtr = _uint8ListToPointer(src);
    final dstPtr = _uint8ListToPointer(dst);
    try {
      return func(srcPtr, srcW, srcH, srcStride, dstPtr, dstW, dstH, dstStride, method);
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
    }
  }

  static int resampleGray(Uint8List src, int srcW, int srcH, int srcStride,
                          Uint8List dst, int dstW, int dstH, int dstStride, int method) {
    final func = _lib
        .lookup<NativeFunction<Int32 Function(Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Int32)>>('compositor_resample_gray')
        .asFunction<int Function(Pointer<Uint8>, int, int, int, Pointer<Uint8>, int, int, int, int)>();
    
    final srcPtr = _uint8ListToPointer(src);
    final dstPtr = _uint8ListToPointer(dst);
    try {
      return func(srcPtr, srcW, srcH, srcStride, dstPtr, dstW, dstH, dstStride, method);
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
    }
  }

  static void compositeLayer(Uint8List src, int srcStride,
                             Uint8List dst, int dstStride,
                             int width, int height,
                             double opacity, int mode,
                             Uint8List? mask, int maskStride) {
    final func = _lib
        .lookup<NativeFunction<Void Function(Pointer<Uint8>, IntPtr, Pointer<Uint8>, IntPtr, IntPtr, IntPtr, Double, Int32, Pointer<Uint8>, IntPtr)>>('compositor_composite_layer')
        .asFunction<void Function(Pointer<Uint8>, int, Pointer<Uint8>, int, int, int, double, int, Pointer<Uint8>, int)>();
    
    final srcPtr = _uint8ListToPointer(src);
    final dstPtr = _uint8ListToPointer(dst);
    final maskPtr = mask != null ? _uint8ListToPointer(mask) : nullptr;
    try {
      func(srcPtr, srcStride, dstPtr, dstStride, width, height, opacity, mode, maskPtr, maskStride);
      _copyPointerToUint8List(dstPtr, dst);
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
      if (mask != null) calloc.free(maskPtr);
    }
  }
}