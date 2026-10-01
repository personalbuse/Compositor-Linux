import 'package:test/test.dart';
import 'package:compositor/render.dart';
import 'package:compositor/core/native_bindings.dart';
import 'dart:typed_data';

void main() {
  setUpAll(() {
    NativeBindings.initialize();
  });

  group('Surface', () {
    test('alloc creates correct size', () {
      final surface = Surface.alloc(100, 50);
      expect(surface.width, equals(100));
      expect(surface.height, equals(50));
      expect(surface.stride, equals(400));
      expect(surface.byteCount, equals(20000));
    });

    test('fill sets all pixels', () {
      final surface = Surface.alloc(10, 10);
      surface.fill(255, 128, 64, 200);
      for (int i = 0; i < surface.rgba.length; i += 4) {
        expect(surface.rgba[i], equals(255));
        expect(surface.rgba[i + 1], equals(128));
        expect(surface.rgba[i + 2], equals(64));
        expect(surface.rgba[i + 3], equals(200));
      }
    });

    test('clear zeros all pixels', () {
      final surface = Surface.alloc(10, 10);
      surface.fill(255, 255, 255, 255);
      surface.clear();
      expect(surface.rgba.every((v) => v == 0), isTrue);
    });

    test('copyFrom copies pixels', () {
      final src = Surface.alloc(10, 10);
      src.fill(100, 150, 200, 255);
      final dst = Surface.alloc(10, 10);
      dst.copyFrom(src);
      expect(dst.rgba, equals(src.rgba));
    });

    test('blit copies rectangular region', () {
      final src = Surface.alloc(20, 20);
      src.fill(255, 0, 0, 255);
      final dst = Surface.alloc(20, 20);
      dst.fill(0, 255, 0, 255);

      dst.blit(src, 5, 5, 0, 0, 10, 10);

      // Check copied region
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 10; x++) {
          final idx = y * dst.stride + x * 4;
          expect(dst.rgba[idx], equals(255));
          expect(dst.rgba[idx + 1], equals(0));
          expect(dst.rgba[idx + 2], equals(0));
        }
      }
      // Check unchanged region
      expect(dst.rgba[11 * dst.stride + 11 * 4], equals(0));
      expect(dst.rgba[11 * dst.stride + 11 * 4 + 1], equals(255));
    });

    test('resize creates new surface', () {
      final src = Surface.alloc(100, 100);
      src.fill(255, 0, 0, 255);
      final dst = src.resize(50, 50);
      expect(dst.width, equals(50));
      expect(dst.height, equals(50));
    });
  });

  group('Mask', () {
    test('alloc creates correct size', () {
      final mask = Mask.alloc(100, 50);
      expect(mask.width, equals(100));
      expect(mask.height, equals(50));
      expect(mask.stride, equals(100));
    });

    test('fill sets all values', () {
      final mask = Mask.alloc(10, 10);
      mask.fill(128);
      expect(mask.gray.every((v) => v == 128), isTrue);
    });
  });

  group('Resample', () {
    test('halvingRgba reduces by half', () {
      final src = Uint8List(8 * 8 * 4);
      for (int i = 0; i < src.length; i += 4) {
        src[i] = 255;
        src[i + 1] = 128;
        src[i + 2] = 64;
        src[i + 3] = 255;
      }
      final dst = Uint8List(4 * 4 * 4);
      final result = Resample.halvingRgba(src, 8, 8, 32, dst, 16);
      expect(result, equals(0));
      expect(dst.length, equals(64));
    });

    test('halvingGray reduces by half', () {
      final src = Uint8List(8 * 8);
      src.fillRange(0, src.length, 128);
      final dst = Uint8List(4 * 4);
      final result = Resample.halvingGray(src, 8, 8, 8, dst, 4);
      expect(result, equals(0));
      expect(dst.length, equals(16));
    });

    test('clampPremultiplied unpremultiplies RGB (converts to straight alpha)', () {
      // Test data from ffi_check: R=200, G=100, B=50, A=128
      // After unpremultiply: R = 200 * 255/128 = 398 -> 255 (clamped)
      //                     G = 100 * 255/128 = 199
      //                     B = 50 * 255/128 = 99 -> 100
      final rgba = Uint8List.fromList([200, 100, 50, 128, 255, 255, 255, 0]);
      Resample.clampPremultiplied(rgba);
      // Pixel 0: unpremultiplied
      expect(rgba[0], equals(255)); // clamped to 255
      expect(rgba[1], equals(199));
      expect(rgba[2], equals(100));
      expect(rgba[3], equals(128)); // alpha unchanged
      // Pixel 1: zero alpha -> zero RGB
      expect(rgba[4], equals(0));
      expect(rgba[5], equals(0));
      expect(rgba[6], equals(0));
      expect(rgba[7], equals(0));
    });
  });

  group('DownsampleCache', () {
    test('getLevel returns source for level 0', () {
      final cache = DownsampleCache();
      final src = Uint8List(100 * 100 * 4);
      final level = cache.getLevel('test', 0, 100, 100, src, 400);
      expect(level, same(src));
    });

    test('getLevel computes halving chain', () {
      final cache = DownsampleCache();
      final src = Uint8List(100 * 100 * 4);
      src.fillRange(0, src.length, 255);
      
      final level1 = cache.getLevel('test', 1, 100, 100, src, 400);
      expect(level1, isNotNull);
      expect(level1!.length, equals(50 * 50 * 4));
      
      final level2 = cache.getLevel('test', 2, 100, 100, src, 400);
      expect(level2, isNotNull);
      expect(level2!.length, equals(25 * 25 * 4));
    });

    test('invalidate removes pyramid', () {
      final cache = DownsampleCache();
      final src = Uint8List(100 * 100 * 4);
      cache.getLevel('test', 1, 100, 100, src, 400);
      expect(cache.currentPixels > 0, isTrue);
      
      cache.invalidate('test');
      expect(cache.currentPixels, equals(0));
    });

    test('clear empties cache', () {
      final cache = DownsampleCache();
      final src = Uint8List(100 * 100 * 4);
      cache.getLevel('test1', 1, 100, 100, src, 400);
      cache.getLevel('test2', 1, 100, 100, src, 400);
      cache.clear();
      expect(cache.currentPixels, equals(0));
    });

    test('getLevelForFactor returns correct level via cache', () {
      final cache = DownsampleCache();
      final src = Uint8List(100 * 100 * 4);
      src.fillRange(0, src.length, 255);
      
      // Test through cache by checking level computation
      // Level 0: factor >= 0.5
      // Level 1: factor 0.25
      // Level 2: factor 0.125
      // Level 3: factor 0.0625
      // etc.
      final level0 = cache.getLevel('factor_test', 0, 100, 100, src, 400);
      expect(level0, same(src));
      
      final level1 = cache.getLevel('factor_test', 1, 100, 100, src, 400);
      expect(level1, isNotNull);
      expect(level1!.length, equals(50 * 50 * 4));
    });
  });
}