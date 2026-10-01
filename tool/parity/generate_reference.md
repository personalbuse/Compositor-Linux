# Generating Parity References (macOS)

This document describes how to generate reference PNG renders from the original macOS Compositor app for parity testing.

## Prerequisites

- macOS machine with the original Compositor app built from source
- Access to the original repo at `../Compositor` (relative to Compositor-Linux)
- Test fixtures in `test/fixtures/` (`.comp` files)

## Procedure

### 1. Enable CPU Canvas Path

The original app has a hidden preference to force the CPU rendering path (which is the reference implementation):

```bash
defaults write com.compositor.Compositor CompositorCPUCanvas -bool YES
```

### 2. Build and Run Original App

```bash
cd ../Compositor
# Open in Xcode and build, or use xcodebuild
xcodebuild -scheme Compositor -configuration Release build
```

### 3. Export Reference PNGs

For each fixture in `test/fixtures/`:

1. Open the `.comp` file in the Compositor app
2. Choose **File → Export PNG...**
3. Save as `test/parity/expected/<fixture-name>.png`

### 4. Automated Generation (Recommended)

Add a temporary XCTest to the original CompositorTests target:

```swift
// In CompositorTests/ParityReferenceGeneratorTests.swift
import XCTest
@testable import Compositor

class ParityReferenceGeneratorTests: XCTestCase {
    func testGenerateReferences() throws {
        let fixturesDir = URL(fileURLWithPath: "/path/to/Compositor-Linux/test/fixtures")
        let outputDir = URL(fileURLWithPath: "/path/to/Compositor-Linux/test/parity/expected")
        
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let fixtureFiles = try FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "comp" }
        
        for fixtureURL in fixtureFiles {
            let doc = try CanvasDocument(contentsOf: fixtureURL)
            let renderer = CompositorCPUCanvas()  // Forces CPU path
            let image = try renderer.render(document: doc, viewport: .fit)
            
            let outputURL = outputDir.appendingPathComponent(fixtureURL.deletingPathExtension().lastPathComponent + ".png")
            try image.pngData()?.write(to: outputURL)
            print("Generated: \(outputURL.lastPathComponent)")
        }
    }
}
```

Run this test to generate all references automatically.

### 5. Verify References

After generating, copy the `test/parity/expected/` directory to the Compositor-Linux repo and commit.

### 6. Disable CPU Canvas (Optional)

```bash
defaults delete com.compositor.Compositor CompositorCPUCanvas
```

## Tolerances

The parity test harness (`test/parity/parity_test.dart`) compares against these references with the following tolerances:

| Fixture Type | Max Channel Diff | Mean Abs Diff | % Pixels > 2 |
|--------------|------------------|---------------|--------------|
| Layers + blend + opacity + mask | ≤ 2 | ≤ 0.5 | ≤ 1% |
| Transforms + resampling | ≤ 4 | ≤ 1.0 | ≤ 3% |
| Adjustments/filters/blur (M4) | ≤ 8 | ≤ 2.0 | ≤ 5% |

## Known Divergences

Document any known divergences in `test/parity/known_divergences.md`:
- CoreGraphics vs Skia resampling differences
- CoreImage blend mode variants (Soft Light, Color Burn, etc.)
- Text rendering (HarfBuzz vs CoreText) - not in MVP