# Native Kernels

This directory contains the C pixel kernels copied verbatim from the original macOS **Compositor** app.

## Provenance

- **Source**: `/home/daviuk/Documentos/Work/Compositor/Compositor/Rendering/`
- **Original repo**: `Compositor` (macOS, Swift + C, MIT license)
- **License**: MIT (Copyright © 2026 Wonder Assembly LLC)
- **Commit copied from**: Original repository at time of port initialization

## Files

### Headers (in `include/`)
- `AdjustPixels.h`
- `BrushPixels.h`
- `ContentFill.h`
- `DitherPixels.h`
- `HealPixels.h`
- `LensPixels.h`
- `LevelsPixels.h`
- `NoisePixels.h`
- `WandPixels.h`

### Sources (in `src/`)
- `AdjustPixels.c`
- `BrushPixels.c`
- `ContentFill.c`
- `DitherPixels.c`
- `HealPixels.c`
- `LensPixels.c`
- `LevelsPixels.c`
- `NoisePixels.c`
- `WandPixels.c`

### New files (added for the port)
- `compositor.h` / `compositor.c` — blend/composite per pixel
- `resample.h` / `resample.c` — halving (Lanczos-3) and final resample (bilinear/nearest)
- `surface.h` / `surface.c` — Surface helpers (alloc/free/fill/copy/blit/resize)
- `blend.h` / `blend.c` — 24 blend modes + alpha compositing

## Build

Built as a shared library `compositor_core` via CMake. Linked into the Flutter runner on Linux and Windows.

## MIT License

```
Copyright © 2026 Wonder Assembly LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```