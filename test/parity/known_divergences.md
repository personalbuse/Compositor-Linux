# Known Parity Divergences

This document tracks known visual differences between the macOS original (CPU path) and the Linux/Windows port that are within accepted tolerances or deferred to later milestones.

## MVP (Phases 0-4) - Accepted Divergences

### Resampling
- **Lanczos-3 halving**: Minor differences at image edges due to padding strategy (original uses 8px transparent padding, port replicates but edge handling may differ by ≤1 pixel value)
- **Bilinear final resample**: Sub-pixel differences in gradient areas (≤2 channel values)
- **Final resample uses bilinear/nearest, not Lanczos**: when `transform.size` differs from the
  asset's pixel size (or after the downsample cache), the source is now resampled to the
  destination rectangle with bilinear (`Smooth`/`High quality`) or nearest (`Nearest`). High
  quality uses Lanczos-3 only for the halving steps, with a bilinear final step; a full Lanczos
  final resample is deferred to M2.

### Layer Masks
- Mask PNG pixels are round-tripped but **not yet loaded into the render pipeline**; the
  renderer looks up a mask asset by `maskFile` which is not populated on read. Masks are
  preserved on save but currently render as if fully enabled. (Follow-up.)

### Blend Modes
- **Soft Light**: Original uses CoreImage/Photoshop variant; port uses W3C formula. Difference typically ≤3 channel values in midtones. To be validated against golden references.
- **Color Burn / Color Dodge**: CoreImage implementation vs port's sRGB formula. Acceptable if within tolerance.

### Color Space
- All operations in sRGB (non-linear) matching original. No linear-space conversion.

## Post-MVP (M2-M7) - To Be Addressed

### M2: Clipping Masks
- `maskSourceID` (v5) not implemented in MVP - renders without clipping
- Group masks (v6) implemented

### M3: Selection Tools
- Marquee, Lasso, Wand, Object selection not in MVP
- Copy/paste of pixel data not in MVP

### M4: Adjustments & Filters
- Adjustment layers (12 kinds) - metadata preserved, not rendered
- Camera Raw - kernels ported but UI not connected
- Layer effects (drop shadow, glow, etc.) - metadata preserved

### M5: PSD / RAW
- PSD import/export - not in MVP
- RAW (LibRaw) - not in MVP

### M6: GPU Rendering
- Impeller/Flutter shaders for compositor - CPU only in MVP
- Tiled rendering for large documents

### M7: Distribution
- Flatpak, MSIX, auto-update
- Accessibility

## Tolerance Validation

Run parity tests with:
```bash
flutter test test/parity --dart-define=PARITY=1
```

Failed comparisons output diff images to `test/parity/diff/`.