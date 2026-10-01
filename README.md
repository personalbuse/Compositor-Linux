# Compositor-Linux

Port of the macOS **Compositor** image editor to Linux and Windows using Flutter/Dart + C kernels via `dart:ffi`.

## Status

**Phase 0 complete** ✓
- Flutter project created with Linux and Windows support
- Original C kernels copied verbatim from macOS app (MIT license)
- CMake build integration for native library (`compositor_core`)
- FFI bindings and smoke tests passing
- CI workflow configured

## Architecture

- **UI**: Flutter/Dart 3 (Material 3, dark theme)
- **Pixel Kernels**: Original C99 code via `dart:ffi` (zero rewrites)
- **Rendering**: CPU compositor (deterministic, parity-verifiable), Skia for presentation only
- **Format**: `.comp` v11 package (JSON manifest + PNG assets), round-trip guaranteed

## Building

### Linux
```bash
flutter build linux --release
```

### Windows
```bash
flutter build windows --release
```

## Development

```bash
# Install dependencies
flutter pub get

# Run debug build
flutter run -d linux

# Run FFI smoke tests
dart run tool/ffi_check.dart

# Analyze code
flutter analyze

# Run tests
flutter test
```

## Project Structure

```
Compositor-Linux/
├── native/                 # C kernels + build
│   ├── include/            # Headers (verbatim from original)
│   ├── src/                # Sources (verbatim + new compositor.c, blend.c, resample.c, surface.c)
│   └── CMakeLists.txt
├── lib/
│   ├── core/
│   │   └── native_bindings.dart  # FFI bindings
│   └── main.dart           # App entry point
├── tool/
│   └── ffi_check.dart      # FFI smoke tests
├── linux/                  # Flutter Linux config + CMake hooks
├── windows/                # Flutter Windows config + CMake hooks
└── .github/workflows/ci.yml
```

## License

Original C kernels: MIT (Copyright © 2026 Wonder Assembly LLC)
Port: MIT