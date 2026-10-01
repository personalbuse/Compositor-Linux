# PLAN.md — Compositor para Linux y Windows

> Especificación de portabilidad para agentes. Este documento es la **fuente de verdad** del
> proyecto `Compositor-Linux`. Cualquier agente que trabaje aquí debe leerlo entero antes de
> tocar código y seguir sus reglas (sección 11).

| Campo | Valor |
|---|---|
| Estado | Aprobado para Fase 0 |
| Objetivo | Reimplementar la app macOS **Compositor** para **Linux y Windows** con el mismo frontend (misma UX) |
| Stack | **Flutter/Dart 3** + kernels **C** reutilizados vía `dart:ffi` + canvas **Skia** (Flutter) |
| Primer entregable | **MVP vertical** (sección 7, fases 0–4) |
| Compatibilidad | **Obligatoria**: leer/escribir `.comp` v11 y round-trip PSD |
| Repositorio original | `/home/daviuk/Documentos/Work/Compositor` (macOS, Swift + C, licencia MIT) |
| Este repositorio | `/home/daviuk/Documentos/Work/Compositor-Linux` |

---

## 1. Objetivo

Construir un editor de imagen de escritorio para Linux y Windows que:

1. **Abra y renderice** cualquier proyecto `.comp` (formato v11 y anteriores v1–v11) con la
   misma semántica visual que la app macOS.
2. **Permita editar** (pincel, capas, opacidad, blend, transformaciones, export) sin corromper
   ningún metadato que aún no se soporte (texto, efectos, ajustes, clipping, shapes).
3. Reproduzca la **misma idea de frontend**: ventana única oscura, toolbar superior, rail de
   herramientas a la izquierda, cabecera contextual por herramienta, canvas central con overlays,
   panel de capas a la derecha, barra de estado inferior, paneles flotantes para diálogos.
4. Mantenga **paridad de píxeles verificable** con la app macOS en el subconjunto soportado,
   medida con goldens y tolerancias (sección 8).

La paridad total es un proyecto de varios meses; el MVP es un corte vertical que valida la
arquitectura completa (formato → modelo → render → UI → edición → guardado).

---

## 2. Fuentes de verdad

Leer primero, en este orden:

1. `../Compositor/docs/writing-comp-files.md` — cómo escribir `.comp` correctamente (ejemplos,
   reglas, escritura atómica). **Imprescindible.**
2. `../Compositor/docs/project-format.md` — esquema completo v1–v11.
3. `../Compositor/AGENTS.md` — convenciones del repo original.
4. Código original; el mapa de archivos está en la sección 12.4.

El repo original **no se modifica**. Solo se leen archivos y se copian los kernels C (sección 6.1).
La licencia es MIT (Copyright © 2026 Wonder Assembly LLC); conservar el aviso al copiar los `.c`.

---

## 3. El original: arquitectura y qué se reutiliza

### 3.1 Inventario (medido)

| Componente | Líneas | Tecnología | Destino en el port |
|---|---|---|---|
| Kernels de píxeles (`Rendering/*.c/.h`) | 2,537 | C99 + libm | **Se copian verbatim** a `native/` |
| Dominio (`Document/`, 54 archivos) | 13,617 | Swift + CoreGraphics/CoreImage/AppKit | **Se traduce** a Dart (sección 6.4–6.9) |
| Render (`Rendering/`, 21 archivos) | 7,437 | AppKit + CoreGraphics + Metal/CoreImage | **Se reescribe** en Dart/C (compositor CPU; GPU post-MVP) |
| UI (`UI/`, 46 archivos + `ContentView`/`CompositorApp`) | 8,959 | SwiftUI + AppKit | **Se reescribe** en Flutter (sección 6.10) |
| IO (`IO/` + `IO/PSD/`) | ~3,645 | Foundation + ImageIO + UTIs + CIRAWFilter | **Se traduce**: `.comp` y PNG (MVP), PSD (M5), RAW (M5) |
| Tests (`CompositorTests/`, 50+ archivos) | ~14,000 | XCTest | **Especificación de comportamiento**; se portan los relevantes |

### 3.2 Hallazgos clave del análisis

- **Los kernels C son 100% portables**: no usan Metal, CoreGraphics ni Accelerate. Solo `libc`/`libm`.
- **Todo el render GPU tiene fallback CPU completo**:
  - Canvas: ajuste `CompositorCPUCanvas` dibuja todo con CoreGraphics (`EditorCanvas.draw`)
    como referencia; `GPUCanvas.swift` (Metal/CoreImage) es solo optimización.
  - Efectos de capa: `MetalLayerEffects.swift` tiene su gemelo CPU en `LayerEffectsRenderer`.
  - Pincel: `BrushStroke` tiene path software ("software fallback lays actual dabs").
  - Smudge/Liquify: `WarpStroke` tiene los dabs CPU que `MetalWarp` porta.
  - Ruido: `NoisePixels.c` es la versión CPU de `GPUNoise.swift`.
  → **El port implementa primero el camino CPU y verifica contra él.** GPU = M6.
- **Convención de píxeles**: RGBA8888 **premultiplicado**, sRGB, filas top-down,
  `stride = width*4`. Máscaras: gris 8-bit sin alfa, `stride = width`, blanco = visible.
- **Formato `.comp`** = carpeta (package) con `manifest.json` + `images/*.png`. Basado en JSON;
  portable sin cambios.
- **Fuentes de imprecisión aceptadas** (documentar): CoreGraphics/CoreImage vs Skia en
  resampling/antialiasing, CoreText vs HarfBuzz en texto, CIRAWFilter vs LibRaw en RAW.
  Se gestionan con tolerancias de golden (sección 8), no con fidelidad bit a bit.

### 3.3 Regla de oro

> Al guardar, **todo campo desconocido o no soportado se conserva intacto** (round-trip).
> Un `.comp` editado en Linux/Windows debe seguir abriendo en macOS sin pérdidas.

---

## 4. Decisiones fijadas

| Decisión | Elección | Motivo |
|---|---|---|
| UI + lógica nueva | **Flutter/Dart** | Swift→Dart es la traducción más fiel; Skia = mismo motor en Linux y Windows |
| Kernels de píxeles | **C original vía `dart:ffi`** | Reutilización literal, cero reescritura de algoritmos |
| Render inicial | **Compositor CPU propio** (Dart + C) | Independiente de GPU → paridad verificable; Skia solo presenta |
| Render GPU | **Post-MVP (M6)** con shaders de Flutter/Impeller | No bloquea el MVP |
| Formato | **.comp v11** lecto-escritura completa + v1–v11 lectura | Requisito del usuario |
| PSD | Round-trip en **M5** | Requisito del usuario, fuera del MVP |
| Plataformas | **Linux + Windows** (código único) | Requisito del usuario |
| Ventanas | Ventana única con paneles flotantes internos | Sustituye `NSPanel`/`NSWindow`; mejor integración multiplataforma |
| Estado/UI | `ChangeNotifier` + `ListenableBuilder` (sin frameworks de estado externos) | Suficiente y de cero dependencia |

Dependencias permitidas en `pubspec.yaml` (no añadir otras sin justificarlo en el PR):

```yaml
dependencies:
  ffi: ^2.1.0            # utilidades dart:ffi
  path: ^1.9.0
  file_selector: ^1.0.0  # diálogos nativos de archivo
  image: ^4.2.0          # JPEG encode/decode (temporal; PNG va por dart:ui)
  uuid: ^4.4.0
  collection: ^1.18.0
dev_dependencies:
  flutter_test: { sdk: flutter }
  flutter_lints: ^4.0.0
```

---

## 5. Arquitectura del port

### 5.1 Estructura del repositorio

```
Compositor-Linux/
├── PLAN.md                     # este documento
├── README.md                   # estado, cómo compilar, features soportadas
├── pubspec.yaml
├── native/                     # C original copiado + build
│   ├── CMakeLists.txt
│   ├── include/                # *.h originales (sin tocar)
│   ├── src/                    # *.c originales (sin tocar) + NUEVOS: compositor.c, blend.c, resample.c
│   └── README.md               # procedencia y licencia MIT
├── lib/
│   ├── main.dart               # entrada + atajos globales
│   ├── core/                   # dominio (port de Document/)
│   │   ├── model/              # canvas_document, image_layer, layer_transform, blend_mode, mask...
│   │   ├── history/            # undo/redo
│   │   ├── brush/              # brush stroke, dabs, tiles
│   │   ├── ops/                # selección, crop, transform (post-MVP)
│   │   └── session/            # editor_session, project_workspace
│   ├── render/                 # compositor, downsample, viewport, surfaces
│   ├── io/
│   │   ├── comp/               # project_store (.comp)
│   │   ├── png/ jpeg/          # export
│   │   ├── psd/                # (M5)
│   │   └── raw/                # (M5)
│   ├── ui/
│   │   ├── theme/              # colores, tipografía, densidad
│   │   ├── shell/              # ventana, toolbar, status bar, tabs
│   │   ├── canvas/             # widget del canvas + overlays + input
│   │   ├── panels/             # layers panel, floating panel host, sheets
│   │   └── widgets/            # sliders, numeric fields, blend picker, color picker
│   └── platform/               # diálogos, clipboard, drag&drop, shortcuts, settings
├── test/
│   ├── unit/                   # puertos de tests del original
│   ├── parity/                 # goldens vs referencias macOS
│   └── fixtures/               # *.comp de prueba + expected/*.png
├── tool/
│   ├── parity/generate_reference.md   # cómo generar referencias en macOS
│   └── ffi_check.dart                 # smoke test de bindings
├── linux/ · windows/           # generados por flutter create; hooks CMake
└── .github/workflows/ci.yml    # ubuntu + windows
```

### 5.2 Capas y flujo de datos

```
.ui.Image (Skia)  ←── decode png ──┐
                                   │
[Widget CanvasView] ── presenta ── [Compositor] ── produce ── [Surface RGBA8 premult.]
        │                                │                        ▲
   eventos input                  CanvasDocument              kernels C (FFI)
        │                                │
   [Herramientas] ── mutan ──> [EditorSession] ── undo ──> [History]
                                        │
                                   [ProjectStore] ── escribe ──> .comp
```

- El **canvas nunca dibuja capa por capa en Skia**: se compone un buffer RGBA8 propio
  (determinista) y se sube como una sola imagen. Esto garantiza paridad Linux/Windows.
- Los **kernels C** operan directamente sobre esos buffers (sin copias).

---

## 6. Especificaciones técnicas

### 6.1 Kernels C + FFI

**Copiar verbatim** desde `../Compositor/Compositor/Rendering/` a `native/`:

```
BrushPixels.{c,h}   HealPixels.{c,h}    LevelsPixels.{c,h}   WandPixels.{c,h}
NoisePixels.{c,h}   LensPixels.{c,h}    ContentFill.{c,h}    DitherPixels.{c,h}
AdjustPixels.{c,h}
```

API disponible (ver headers para comentarios de semántica):

```c
// BrushPixels.h
void brush_alpha_bounds(const uint8_t*, size_t w, size_t h, size_t stride, size_t bounds[4]);
void layer_extract_alpha(const uint8_t *rgba, size_t rgbaStride, uint8_t *gray, size_t grayStride, size_t w, size_t h);
void layer_unpremultiply_opaque(uint8_t *rgba, size_t stride, size_t w, size_t h);
void layer_restore_alpha(uint8_t *rgba, size_t stride, const uint8_t *alpha, size_t alphaStride, size_t w, size_t h);

// HealPixels.h
int  spot_heal(uint8_t *rgba, const uint8_t *coverage, size_t w, size_t h, size_t stride,
               float opacity, int mode, uint32_t seed);            // modes: 0 content-aware, 1 texture, 2 proximity

// LevelsPixels.h
void levels_apply(uint8_t *pixels, size_t count, const float *tables);
void levels_histogram(const uint8_t *pixels, const uint8_t *coverage, size_t count, double *bins);
void cube_apply(uint8_t *pixels, size_t count, const float *cube, int dimension);

// WandPixels.h
long wand_mask(const uint8_t *rgba, size_t w, size_t h, size_t stride, size_t seedX, size_t seedY,
               size_t radius, int tolerance, int contiguous, uint8_t *mask);
long color_range_mask(const uint8_t *rgba, size_t w, size_t h, size_t stride,
                      const uint8_t *include, int includeCount, const uint8_t *exclude, int excludeCount,
                      int fuzziness, int invert, uint8_t *mask);
int  wand_trace(const uint8_t *mask, size_t w, size_t h, int32_t **points, size_t *pointCount,
                int32_t **loops, size_t *loopCount);

// NoisePixels.h
void noise_add(uint8_t*, size_t w, size_t h, size_t stride, float amount, int gaussian,
               int monochromatic, uint32_t seed);

// LensPixels.h
void lens_distort(const uint8_t *src, uint8_t *dst, size_t w, size_t h, size_t stride, double k);

// ContentFill.h
int content_fill(uint8_t *rgba, size_t stride, const uint8_t *mask, size_t maskStride, int w, int h);

// DitherPixels.h  — enum de estilos + struct DitherParams + dither_apply/dither_dots/dither_glow

// AdjustPixels.h — Camera Raw completo (light, color, effects, detail, optics, calibration),
//                  gradient map, grain, black&white, color balance, tonal contrast, clip overlay…
```

**Bindings** (`lib/core/native_bindings.dart`):

- Usar `dart:ffi` con `DynamicLibrary.open('libcompositor_core.so')` (Linux) /
  `DynamicLibrary.open('compositor_core.dll')` (Windows). Resolver rutas junto al ejecutable.
- Exponer wrappers tipados Dart (`Pointer<Uint8>` → `Uint8List` con `asTypedList`).
- **Propiedad de memoria**: los buffers de imagen los asigna Dart (`Uint8List`/`calloc`);
  C nunca retiene punteros. Las funciones que devuelven memoria (`wand_trace`) se liberan con
  `malloc.free` (usar `package:ffi`'s `calloc`/`malloc`).
- **Nunca** llamar kernels en el hilo de UI para imágenes grandes: usar `Isolate.run` con
  `TransferableTypedData` cuando el trabajo supere ~20 ms (p. ej. filtros).

**Nuevo C propio** (`native/src/`), con tests unitarios:

- `compositor.c` — blend/composición por píxel de una capa sobre el backdrop (sección 6.6).
- `resample.c` — reducción a la mitad (halving) y resample final bilineal/nearest.
- `surface.c` — helpers de Surface (alloc/free/fill/copy/blit con recorte).

**Build**: `flutter` no compila C por defecto. Añadir en `linux/CMakeLists.txt` y
`windows/CMakeLists.txt`:

```cmake
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../native" compositor_core)
target_link_libraries(${BINARY_NAME} PRIVATE compositor_core)
```

`native/CMakeLists.txt` construye una librería (`compositor_core`) con los `.c` de `src/`,
`include/` en el include path, `-O2` (Release) y `m` en Linux.

*Criterio de aceptación*: `tool/ffi_check.dart` llama `brush_alpha_bounds` y
`rgba_clamp_premultiplied` con buffers conocidos y valida el resultado en Linux y Windows.

### 6.2 Formato `.comp` v11

Package (carpeta) con esta forma exacta:

```
Nombre.comp/
├── manifest.json
├── images/
│   ├── <UUID>.png            # píxeles de capa (RGBA 8-bit)
│   └── <UUID>.mask.png       # máscara (gris 8-bit, blanco revela)
└── QuickLook/Preview.jpg     # opcional (Finder); el port puede ignorarlo o escribirlo (M2)
```

Manifest mínimo (de `docs/writing-comp-files.md`):

```json
{
  "format": "com.compositor.project",
  "version": 11,
  "colorSpace": "sRGB",
  "documentID": "0C5E7A91-3B2D-4F6A-8E1C-9D0B7A6F5E4D",
  "width": 1920,
  "height": 1080,
  "resolution": 72,
  "activeLayerID": "6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F",
  "layers": [
    {
      "id": "6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F",
      "name": "Background",
      "imageFile": "6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F.png",
      "isVisible": true,
      "isGroup": false,
      "opacity": 1,
      "blendMode": "Normal",
      "transform": {
        "origin": [0, 0],
        "size": [1920, 1080],
        "rotation": 0,
        "flipX": false,
        "flipY": false,
        "sampling": "High quality"
      }
    }
  ]
}
```

Campos de capa (esquema completo en `docs/project-format.md`):

| Campo | Tipo | Desde | MVP |
|---|---|---|---|
| `id`, `name`, `isVisible`, `transform` | — | v1 | ✅ |
| `parentID`, `isGroup` | UUID/bool | v2 | ✅ render |
| `opacity` (0–1), `blendMode` | Double/String | v3 | ✅ render |
| `maskFile`, `maskEnabled` | String/bool | v4 | ✅ render |
| `maskSourceID` (clipping mask) | UUID | v5 | ⛔ no-op, preservar |
| `maskPlacement`, `maskLinked` | — | aditivo | ⛔ preservar |
| `adjustment` | objeto | v7/v9 | ⛔ no-op, preservar |
| `guides` (top-level) | array | v8 | ⛔ preservar |
| `shape`, `effects`, `text` | objetos | v7/v10/v11 | ⛔ preservar |

**Reglas duras de escritura** (si se rompen, macOS rechaza el archivo en silencio):

1. `imageFile` de una capa **debe** ser `<id>.png` con el UUID **en mayúsculas** tal como está
   en el manifest; máscara `<id>.mask.png`.
2. PNGs de capa RGBA 8-bit; máscaras gris 8-bit sin alfa.
3. `layers` va **de abajo hacia arriba** (el último dibuja encima).
4. `blendMode` con las cadenas exactas de la sección 6.6.
5. No dejar referencias a imágenes inexistentes.
6. **Escritura atómica**: escribir PNGs nuevos primero; luego `manifest.json.tmp` y `rename`
   sobre `manifest.json`. Nunca dejar el package a medias.
7. Conservar `documentID`. No borrar campos que el port no entiende (round-trip).
8. Al guardar, **re-encodear los PNGs solo si sus píxeles cambiaron**; si no, copiarlos byte a byte.

**Límites** (mantener los mismos, de `DocumentLimits.swift`):
`maxSide = 30_000`; superficie única ≤ `200_000_000` px; presupuesto del documento
`min(800_000_000, max(200_000_000, RAM/16))` px; manifest ≤ 4 MiB; asset ≤ 512 MiB;
≤ 10_000 capas; ≤ 1_000 guías; anidamiento ≤ 64.

**Versiones**: aceptar versiones `1...11`; rechazar el resto con error legible. Al guardar,
escribir siempre `version: 11`. Los tests de round-trip deben abrir todos los fixtures v1–v11.

*Criterio de aceptación*: round-trip byte-equivalente del manifest para fixtures sin edición
(salvo reordenación de claves JSON permitida); la app macOS abre sin quejas los `.comp`
guardados por el port.

### 6.3 Modelo de documento (Dart)

Port de `Document/EditorSession.swift`, `CanvasDocument`, `ImageLayer` a
`lib/core/model/`:

```dart
class CanvasDocument {
  final String id;            // UUID
  final int width, height;
  double resolution = 72;
  List<ImageLayer> layers = [];   // abajo → arriba
  List<CanvasGuide> guides = [];
  DocumentSelection? selection;   // no se guarda
}

class ImageLayer {
  final String id;            // UUID string en mayúsculas
  ImportedImage? asset;       // píxeles RGBA premultiplicados + nombre
  LayerTransform transform;
  String name;
  bool isVisible = true;
  String? parentID;           // grupo
  bool isGroup = false;
  double opacity = 1;
  BlendMode blendMode = BlendMode.normal;
  String? maskSourceID;
  LayerMask? mask;
  LayerAdjustment? adjustment; // preservar
  LayerShapeStyle? shape;      // preservar
  LayerEffects? effects;       // preservar
  LayerTextStyle? text;        // preservar
  Map<String, dynamic> unknown = {}; // campos no reconocidos → round-trip
}
```

- `ImageLayer.unknown`: **capturar todo campo JSON no modelado** para reescribirlo al guardar.
- Igual a nivel manifest (`unknown` top-level) y en `transform`, `mask`, etc.
- `ImportedImage`: `{ String name; Uint8List rgba; int width, height; String? sourcePath; }`
  con `rgba` en el formato de la sección 3.2.

### 6.4 Transformaciones, sampling y viewport

**`LayerTransform`** (port de `LayerTransform.swift`) — codificación JSON:
`origin`, `size` en píxeles de documento (y hacia abajo), `rotation` en grados **horario**,
`flipX`, `flipY`, `sampling` = `"Nearest" | "Smooth" | "High quality"`.

Matriz píxel‑de‑capa → documento (idéntica a `BrushRaster.pixelToDocument`):

```
M = T(center) · R(radians) · S(size.w / width · (flipX ? -1 : 1),
                              size.h / height · (flipY ? -1 : 1)) · T(-width/2, -height/2)
```

donde `center = origin + size/2` y `radians = rotation * π/180`. La inversa es
`screenPoint → layerPixel`.

**Viewport** (port de `CanvasViewport.swift`):

- `zoom ∈ [0.001, 32]`, `pointsPerPixel = zoom / backingScale` (backingScale = DPR de la pantalla).
- Niveles de zoom de teclado: `[0.125, 1/6, 0.25, 1/3, 0.5, 2/3, 1, 1.25, 1.5, 2, 3, 4, 5, 6, 8, 12, 16]`.
- `fit()`: `zoom = clamp(min(max(1, viewW-96)/docW, max(1, viewH-96)/docH) * backingScale)`, pan = 0.
- `setZoom(anchoredAt:)` debe conservar el punto de documento bajo el cursor.
- El canvas dibuja: fondo `#1B1B1B` (0.105), sombra del documento (±3 px, blur 7, negro 35 %),
  checkerboard de 10 pt (grises 0.35/0.30), borde de 1 px blanco al 13 %.

**Sampling**:

- `Nearest`: resample más cercano, sin antialias.
- `Smooth`: bilineal.
- `High quality`: cadena de halvings **Lanczos-3** + bilineal final (sección 6.5).
- `DownsampleCache.level(for factor)`: `0` si `factor >= 0.5` o inválido; si no,
  `min(6, floor(log2(1/factor)))`. `factor` = píxeles de destino por píxel de imagen.

### 6.5 Pipeline de render (compositor CPU)

Referencia: camino CPU del original (`LayerRenderer`, `TiledLayerRenderer`,
`DownsampleCache`, `CanvasView.gpuFrame` como espejo). El compositor del port:

1. **Surface**: buffer RGBA8 premultiplicado, filas top-down, `stride = w*4`, + variante gris 8-bit.
   Implementar en `native/src/surface.c` con: `alloc/free/fill/clear/copy/blit(rect)/resize`.
2. **Composición de un frame visible**:
   - Entrada: `CanvasDocument`, viewport (zoom/pan/DPR), rect visible.
   - Salida: Surface al tamaño en píxeles de pantalla del viewport.
   - Para cada capa en orden bottom→top (recursión de grupos, `effectiveVisibleIDs`):
     a. Calcular `M` (6.4) y `factor = scaleDestino` (píxeles de pantalla por píxel de capa).
     b. Elegir nivel de downsample (`6.4`) y resamplear la imagen de la capa a un scratch
        (Lanczos para halvings; bilineal/nearest para el paso final).
     c. Aplicar máscara raster (multiplicar alfa por `mask/255`) si `maskEnabled`.
     d. Aplicar máscaras de grupos ancestros (multiplicador de cobertura).
     e. Aplicar `opacity` (alfa ×= opacity).
     f. **Blend** sobre el backdrop con `blendMode` (6.6). Capa oculta = no se dibuja;
        grupo oculto = sus hijos no se dibujan.
3. **Cachés**:
   - `DownsampleCache`: cadena de halvings por imagen, presupuesto de píxeles, LRU.
   - `CompositeCache`: resultado del frame actual; invalidar por revisión de documento /
     viewport. Pan/zoom recompone (MVP); optimización en M6.
4. **Presentación**: convertir la Surface a `ui.Image` con
   `ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, callback)` y pintarla en
   `CustomPaint` con `canvas.drawImage`. Los overlays (marco, guías, cursor de pincel) se
   dibujan encima con Skia.
5. **Export PNG**: componer a escala 1 sobre el rect completo del documento; aplanar en
   `package:image` o encoder nativo; respetar `resolution` en el chunk pHYs (M2).

**Reducción a la mitad (halving)** — semántica del original:

- Tamaño: `ceil(w/2) x ceil(h/2)`.
- Colores: padding transparente de 8 px, resample Lanczos-3, `rgba_clamp_premultiplied` al final,
  recorte del padding/2.
- Máscaras: sin padding; se repite la última fila/columna cuando falta; resample Lanczos-3 en gris.
- Implementar en `native/src/resample.c`; los tests comparan contra valores de referencia
  generados por macOS con tolerancia (sección 8).

**Pincel** (MVP): port del path software de `BrushStroke` — dabs a lo largo del segmento con
espaciado `0.25 * diámetro` (ajustable por dureza; ver `spacingFraction` en el original),
falloff gaussiano normalizado:

```
falloff(u) = max(0, (exp(-2.5·u²) - exp(-2.5)) / (1 - exp(-2.5)))   // u = distancia / radio
```

Hardness = 1 → disco con antialias de 1 px. Cada dab se compone con `source-over` sobre la
capa, con color de frente/borrado. El trazo se confirma al soltar el ratón como **una sola
entrada de undo**. Pintar sobre máscaras: misma fórmula con valor 0/255.

### 6.6 Blend modes

24 modos, cadenas exactas y agrupación (de `LayerAppearance.swift`):

| Grupo | Modos | Fórmula (canal, sRGB no lineal) |
|---|---|---|
| normal | `Normal` | `B = Cs` |
| oscurecer | `Darken` | `min(Cb, Cs)` |
| | `Multiply` | `Cb·Cs` |
| | `Color Burn` | `Cb == 0 ? 0 : 1 - min(1, (1-Cb)/Cs)` |
| | `Linear Burn` | `Cb + Cs - 1` |
| aclarar | `Lighten` | `max(Cb, Cs)` |
| | `Screen` | `Cb + Cs - Cb·Cs` |
| | `Color Dodge` | `Cb == 1 ? 1 : min(1, Cb/(1-Cs))` |
| | `Linear Dodge (Add)` | `min(1, Cb + Cs)` |
| contraste | `Overlay` | `HardLight(Cs, Cb)` |
| | `Soft Light` | W3C/PDF: `(1-2Cs)·Cb² + 2·Cs·Cb` (Cs≤0.5) / `(1-2Cs)·Cb + (2Cs-1)·√Cb`… ver nota |
| | `Hard Light` | `Cs ≤ 0.5 ? Multiply(Cb, 2Cs) : Screen(Cb, 2Cs-1)` |
| | `Vivid Light` | `Cs ≤ 0.5 ? ColorBurn(Cb, 2Cs) : ColorDodge(Cb, 2Cs-1)` |
| | `Linear Light` | `Cs ≤ 0.5 ? LinearBurn(Cb, 2Cs) : LinearDodge(Cb, 2Cs-1)` |
| | `Pin Light` | `Cs ≤ 0.5 ? Darken(Cb, 2Cs) : Lighten(Cb, 2Cs-1)` |
| | `Hard Mix` | `(VividLight(Cb, Cs) < 0.5) ? 0 : 1` |
| comparación | `Difference` | `|Cb - Cs|` |
| | `Exclusion` | `Cb + Cs - 2·Cb·Cs` |
| | `Subtract` | `max(0, Cb - Cs)` |
| | `Divide` | `Cs == 0 ? 1 : min(1, Cb/Cs)` |
| componente | `Hue`, `Saturation`, `Color`, `Luminosity` | No separables: Lum/Sat/Hue con `SetLum`, `SetSat`, `ClipColor` (W3C) |

**Composición con alfa** (todo el cálculo en premultiplicado; para los modos no separables,
des-premultiplicar, aplicar B, re-premultiplicar):

```
// Cs, Cb = color recto (des-premultiplicado) del source y backdrop; as, ab = alfa 0..1
B  = blend(Cb, Cs)
co = as·(1-ab)·Cs + as·ab·B + (1-as)·ab·Cb      // color premultiplicado de salida
ao = as + ab·(1-as)                             // alfa de salida
```

Notas de paridad:

- El original usa CoreImage para 8 modos (`Color Burn`, `Color Dodge`, `Soft Light`,
  `Linear Burn`, `Linear Dodge`, `Vivid Light`, `Linear Light`, `Pin Light`, `Hard Mix`,
  `Subtract`, `Divide`) y CoreGraphics para el resto; **siempre en sRGB**, nunca lineal
  (documentado en `SeparableBlend.swift`). Nuestra implementación debe ser sRGB.
- `Soft Light` del original sigue la fórmula de CoreImage/Photoshop. Usar la fórmula W3C por
  defecto y validar contra golden; si difiere > tolerancia en el fixture, ajustar a la variante
  de Photoshop (`D(Cb) = ((16·Cb - 12)·Cb + 4)·Cb` para Cs ≤ 0.25, etc.).
- Implementar en `native/src/blend.c`; tests unitarios con vectores conocidos (0, 0.5, 1).

### 6.7 Máscaras, grupos y clipping

- **Máscara raster**: imagen gris del mismo tamaño en píxeles que la capa; multiplica el alfa
  de la capa por `mask[y*w+x]/255`. `maskEnabled: false` → conservar pero no aplicar.
- **Grupos**: pass-through. `isGroup: true` no tiene imagen. Orden de hijos = subárbol contiguo
  en `layers` (abajo→top). La opacidad del grupo multiplica la de cada descendiente. La máscara
  del grupo (v6) multiplica la cobertura de todos los descendientes.
- **Visibilidad**: heredada; ocultar un grupo oculta su contenido sin cambiar flags.
- **Clipping (`maskSourceID`, v5)**: **MVP = preservar en JSON y renderizar sin clipping**
  (divergencia documentada). M2: implementar — la cobertura del layer fuente (alfa tras su
  máscara/opacidad/transform; sin color) multiplica el alfa del destino.
- **Ajustes (v7/v9)**: MVP = no-op (preservar). M4.

### 6.8 Pincel y edición de píxeles (MVP)

- Herramientas activas en MVP: **Move** (mover capa), **Hand**, **Zoom**, **Brush** (paint/erase),
  **Eyedropper** (lectura simple). El resto del rail se muestra deshabilitado.
- Pincel: tamaño 1–2000, dureza 0–1, opacidad 0–1, color frontal. Atajos `B`/`E`, `[`/`]`
  tamaño, `Shift+[`/`]` dureza, `1–0` opacidad.
- Mutación: los dabs se aplican sobre un buffer scratch por tiles de 256 px; al confirmar, se
  escribe en el asset de la capa (PNG en memoria). Undo = reemplazo del asset previo + revisión.
- Erase: `layer_unpremultiply_opaque` + pintar alfa + `layer_restore_alpha` (kernels existentes)
  o matemática directa `dst.a *= (1 - dab)`.

### 6.9 Undo/redo

- Port de `DocumentHistory.swift`. Comandos por **snapshot diferencial**:
  - Propiedades de capa: guardar valor anterior/nuevo.
  - Píxeles (pincel, filtros): guardar buffers previos por tiles tocados (presupuesto LRU).
  - Estructura (añadir/borrar/reordenar/grupos): guardar índices y capas afectadas.
- Cada entrada: `name` (p. ej. `"Brush"`, `"Layer Opacity"`), `undo()`, `redo()`.
- Límite de memoria configurable (default: 512 MB de snapshots).
- MVP: undo de pincel, opacidad, visibilidad, reordenar, mover.
- La selección forma parte del undo en el original; en el port M2.

### 6.10 UI/UX

**Layout** (réplica del original):

```
┌──────────────────────────────────────────────────────────────────────┐
│ Toolbar: [New] [tabs…] [Fit] [100%] [−][+]                          │
├──────┬────────────────────────────────────────────────┬──────────────┤
│      │ Cabecera de herramienta (contextual)           │              │
│ Rail ├────────────────────────────────────────────────┤ Layers Panel │
│ 56px │ Rulers (M2)                                     │  (252px,     │
│      │                                                 │  redimension.)│
│      │                 CANVAS                          │              │
│      │                                                 │              │
├──────┴────────────────────────────────────────────────┴──────────────┤
│ Status bar: zoom % · WxH px · sRGB · Transparent · [Working…]        │
└──────────────────────────────────────────────────────────────────────┘
```

**Tema** (valores de `ContentView.swift`):

- Fondo de la ventana/canvas: `Color(white: 0.14)` / canvas `0.105`.
- Botón activo del rail: blanco 12 % en rounded rect 7 px + borde blanco 14 %.
- Modo oscuro fijo (`preferredColorScheme(.dark)` en el original).
- Status bar: fuente 11 monoespaciada con dígitos tabulares, color secundario, alto 30 px.
- Rail: ancho 56 px, botones 36×36, separación 10.

**MVP**:

- Ventana única mínima 800×520; título = nombre del proyecto.
- Toolbar: New, Open, Save, Save As, Export PNG; Fit / 100 % / zoom ±.
- Rail: los 15 iconos con tooltips; activos Move/Hand/Zoom/Brush/Eyedropper.
- Cabecera por herramienta: solo Brush (size/hardness/opacity/color) y navegación.
- Canvas: zoom/pan (space, rueda = zoom con Ctrl), fit, 100 %, checkerboard.
- Layers panel: lista con indentación de grupos, miniatura, nombre, ojo de visibilidad,
  slider de opacidad, dropdown de blend, botones subir/bajar, selección múltiple básica.
- Paneles flotantes: host arrastrable dentro de la ventana (base para M2).
- Diálogos: New Canvas, Export PNG (file_selector), confirmación de cambios sin guardar.
- Menú: File (New/Open/Save/Save As/Export/Quit), Edit (Undo/Redo), View (Fit/100 %/Zoom/Pixel
  grid), Layer (visibilidad/subir/bajar/borrar). Resto en M2.
- Atajos MVP: `Ctrl+N/O/S/Shift+S/E`, `Ctrl+Z/Y`, `Ctrl+0/1/+/-`, `B/E/V/H/Z`, `[`/`]`.
- Cursor: flecha, move, mano, zoom, círculo de pincel del tamaño del diámetro.
- Drag & drop de `.comp`/imágenes sobre la ventana: M2.

**M2 (post-MVP)**: paneles Levels/HueSat/Effects/Filter/Color Range, sheets completos,
pestañas de proyectos, menús Select/Image/Filter/Layer completos, guías/grid/rulers,
color picker, numeric scrub, atajos configurables, pantalla de bienvenida (New Canvas).

### 6.11 Plataforma

| Necesidad | Original | Port |
|---|---|---|
| Diálogos de archivo | `NSOpenPanel`/`NSSavePanel` | `file_selector` (GTK/Windows nativos) |
| Portapapeles | `NSPasteboard` | `Clipboard` de Flutter + `pasteboard` para imágenes (M2) |
| Drag & drop | `NSItemProvider`/`onDrop` | `DropTarget` de Flutter (M2) |
| Cursores | `NSCursor` | `MouseRegion.cursor` + cursor custom dibujado |
| Menús | `CommandMenu`/AppDelegate | `MenuBar` de Flutter (in-window) + atajos propios |
| Fuentes del sistema | `NSFont` | `TextStyle` + `google_fonts` opcional (M4) |
| Ventanas flotantes | `NSPanel` | Overlays arrastrables dentro de la ventana |
| Preferencias | `UserDefaults` | JSON en `path_provider` app support |
| Actualizaciones | Sparkle | M7 (GitHub Releases + updater por plataforma) |

### 6.12 IO

**MVP**:

- Leer `.comp`: JSON + PNGs. PNG decode vía `ui.instantiateImageCodec` +
  `toByteData(format: rawRgba)` (premultiplicado, RGBA8888) — verificar el formato en el
  spike; si el orden/alfa no coincide, decodificar con `package:image` y convertir.
- Escribir `.comp`: re-encodear PNG con `ui.Image.toByteData(format: png)` (Skia) o
  `package:image`. **Escritura atómica** (6.2).
- Export PNG: composición aplanada 1:1 del documento.
- Import de imagen suelta (PNG/JPEG) como capa nueva: `package:image` decode → capa centrada.

**M5**: PSD import/export (port de `IO/PSD/*`: reader, channel coder RLE/ZIP, text, vector;
usar `package:archive` para ZIP), RAW (LibRaw por FFI), JPEG export con calidad y metadata EXIF.

---

## 7. Fases

### Fase 0 — Esqueleto y spikes (2–3 semanas)

- [ ] `flutter create --platforms=linux,windows` (org `com.compositor`, proyecto `compositor`).
- [ ] Copiar kernels C a `native/` (verbatim) + `native/README.md` con procedencia y MIT.
- [ ] CMake en Linux y Windows; `tool/ffi_check.dart` verde en ambos SO.
- [ ] Spike A: abrir un `.comp` fixture, decodificar PNGs, verificar formato de píxeles.
- [ ] Spike B: compositar 10 capas 4K en CPU con mediana < 33 ms por frame en hardware objetivo.
- [ ] Spike C: tabla de paridad de blend modes contra valores de referencia.
- [ ] Spike D: `file_selector` + `MenuBar` + panel flotante arrastrable en ambos SO.
- [ ] CI (ubuntu + windows): `flutter analyze`, `flutter test`, `flutter build`.
- [ ] `README.md` inicial con estado y limitaciones.

**Salida**: app que abre un `.comp` y muestra la primera capa en el canvas, con CI verde.

### Fase 1 — Motor y formato (4–6 semanas)

- [ ] `lib/core/model/`: documento, capa, transform, blend, máscara, grupos (con `unknown`).
- [ ] `lib/io/comp/project_store.dart`: leer v1–v11, validar límites, errores legibles.
- [ ] Escritura v11 con round-trip de campos desconocidos + escritura atómica.
- [ ] `lib/render/surface.dart` + `native/surface.c` y `resample.c` (halving Lanczos, bilineal,
      nearest) con tests unitarios.
- [ ] `lib/render/downsample_cache.dart` (fórmula 6.4, presupuesto LRU).
- [ ] `lib/core/history/` con undo/redo de propiedades y de píxeles por tiles.
- [ ] Portar tests del original: `CanvasSizeTests`, `ImageSizeTests`, `HistoryTests`,
      `ProjectWorkspaceTests` (los aplicables) a `test/unit/`.

**Salida**: `dart test` con round-trip v1–v11 y resample verificados; sin UI todavía.

### Fase 2 — Render MVP (6–8 semanas)

- [ ] `native/blend.c` con los 24 modos + composición alfa (6.6) y tests con vectores.
- [ ] `lib/render/compositor.dart`: composición bottom→top, grupos, opacidad, máscaras,
      sampling, caché de frame.
- [ ] Presentación: Surface → `ui.Image` → `CustomPaint`; checkerboard, sombra y borde (6.4).
- [ ] Zoom/pan/fit con `CanvasViewport` portado; rueda/trackpad; cursores.
- [ ] Export PNG aplanado + panel/atajo.
- [ ] Fixtures de paridad y harness de comparación con tolerancias (sección 8).

**Salida**: `.comp` de fixtures renderizado con paridad dentro de tolerancia; export PNG válido.

### Fase 3 — UI y pincel MVP (4–6 semanas)

- [ ] Shell completo (6.10): toolbar, rail, cabecera, layers panel, status bar, tema.
- [ ] Menús y atajos MVP; diálogos New Canvas y Export.
- [ ] Layers panel funcional (visibilidad, opacidad, blend, reordenar, borrar, selección).
- [ ] Pincel paint/erase con commit + undo (6.8); cursor circular; color picker básico.
- [ ] Guardar `.comp` desde la UI; manejo de "cambios sin guardar" al cerrar.

**Salida**: app usable de punta a punta para el flujo de la sección 7 (MVP).

### Fase 4 — Validación y cierre MVP (1–2 semanas)

- [ ] ≥ 20 fixtures (sin features no soportadas) con paridad verificada.
- [ ] Pruebas manuales en Linux (Ubuntu 24.04) y Windows 11 (máquina virtual).
- [ ] Empaquetado preliminar: AppImage/tar.gz y ZIP/Inno Setup.
- [ ] `README.md` con matriz de features soportadas/divergencias conocidas.
- [ ] Tag `v0.1.0-mvp`.

**Criterio de MVP cumplido**: abre cualquier `.comp` v11; renderiza con paridad (sección 8);
pinta y guarda sin corromper metadatos; exporta PNG; CI verde en ambos SO.

### Roadmap post-MVP

| Hito | Contenido |
|---|---|
| **M2** | UI completa (6.10): paneles flotantes, sheets, pestañas, menús completos, guías/grid/rulers, clipping masks, drag&drop |
| **M3** | Todas las herramientas: marquee/lasso/wand/objeto, crop, spot healing, clone stamp, smudge/liquify, gradient, shape, type, selección (expand/contract/feather), portapapeles de píxeles |
| **M4** | Ajustes y filtros: los 12 kinds de adjustment layer, Camera Raw completo (kernels C), Grain, Dither, Vignette, blurs, content-aware fill, subject removal, efectos de capa |
| **M5** | PSD import/export, RAW (LibRaw), JPEG con calidad/metadata, HEIC/TIFF según demanda |
| **M6** | Rendimiento: canvas GPU (shaders de Flutter), tiles de `TiledLayerRenderer`, documentos de 100 MP, pincel con integración continua |
| **M7** | Distribución: Flatpak, MSIX, auto-update, telemetría de crashes, accesibilidad |

---

## 8. Testing y paridad

### 8.1 Estrategia

1. **Tests unitarios portados**: la suite del original (14k líneas) es la especificación.
   Portar por prioridad: formato/modelo → resample/transform → blend → pincel → historial.
2. **Goldens de paridad**: para cada fixture `.comp`, comparar el render del port contra el
   render del camino **CPU** de macOS (`CompositorCPUCanvas = true`), exportado a PNG.
3. **Tests de round-trip**: `.comp` → abrir → guardar → abrir con el original (manual/CI macOS)
   y verificar igualdad semántica (manifest normalizado + mismos píxeles).
4. **UI smoke tests**: `flutter test` con `WidgetTester` para paneles y atajos (sin goldens de
   UI cross-platform, que no son deterministas entre SO).

### 8.2 Generación de referencias (macOS)

En una máquina macOS con el repo original:

```bash
# 1. Copiar los fixtures a una carpeta accesible
# 2. Con la app: activar camino CPU
defaults write com.compositor.Compositor CompositorCPUCanvas -bool YES
# 3. Abrir cada fixture y Export PNG; guardar como test/parity/expected/<fixture>.png
```

Alternativa reproducible (recomendada): añadir un XCTest temporal en el repo original que
renderice cada fixture con el canvas CPU y escriba los PNG en `test/parity/expected/`.
Documentar el procedimiento exacto en `tool/parity/generate_reference.md`.

### 8.3 Tolerancias (imagen completa RGBA8)

| Tipo de fixture | Máx. dif. por canal | Dif. media absoluta | % píxeles con dif > 2 |
|---|---|---|---|
| Capas + blend + opacidad + máscara | ≤ 2 | ≤ 0.5 | ≤ 1 % |
| Transformaciones/resampling | ≤ 4 | ≤ 1.0 | ≤ 3 % |
| Ajustes/filtros/blur (M4) | ≤ 8 | ≤ 2.0 | ≤ 5 % |

El harness (`test/parity/parity_test.dart`) reporta un diff PNG en `test/parity/diff/` cuando
falla. Los fixtures no soportados (texto, efectos, clipping, ajustes) se excluyen del set MVP y
se listan en `test/parity/known_divergences.md`.

---

## 9. CI/CD y empaquetado

```yaml
# .github/workflows/ci.yml (resumen)
jobs:
  test:
    strategy: { matrix: { os: [ubuntu-latest, windows-latest] } }
    steps: [checkout, setup-flutter(3.x stable), flutter pub get,
            flutter analyze, flutter test, flutter build linux|windows]
```

- Cachear `~/.pub-cache`. Ejecutar `flutter test` con goldens locales (no UI).
- Job opcional `parity` en macOS: solo para regenerar referencias (manual / tag).
- Releases: `ubuntu` → `.tar.gz` + AppImage (M7 Flatpak); `windows` → `.zip` + instalador
  Inno Setup (M7 MSIX).

---

## 10. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Diferencias de resampling CG/CI vs nuestro Lanczos | Paridad de bordes | Goldens con tolerancia; si falla, ajustar kernel (padding, clamp) contra referencia |
| Blend Soft Light / Color Burn difieren de CoreImage | Paridad de color | Vectores de prueba del original + variante Photoshop documentada (6.6) |
| `rawRgba` de Flutter no es premultiplicado como se espera | Corrupción sutil | Test de spike que compara un PNG conocido byte a byte; fallback a `package:image` |
| Metadatos desconocidos perdidos al guardar | Proyectos corruptos | Modelo con `unknown` en cada nivel + test de round-trip obligatorio |
| Rendimiento CPU en documentos grandes | UX pobre | Tiles, downsample, caché de frame; GPU en M6 |
| Fuentes/HarfBuzz difieren de CoreText (M4) | Texto distinto | Aceptado; metadatos round-trip; aproximación por píxeles guardados |
| PSD complejo (texto/vectores/CMYK) | M5 se alarga | Portar 1:1 los límites del original; rechazar lo que él rechaza |
| CIRAWFilter no existe en Linux/Windows | RAW distinto | LibRaw con defaults propios; documentar divergencia |
| Scope creep en el MVP | No se termina | El MVP se limita estrictamente a la sección 7 |

---

## 11. Reglas para agentes

1. **Leer este PLAN.md y `docs/writing-comp-files.md` antes de escribir código.**
2. **No modificar** los `.c/.h` copiados del original. Los añadidos propios van en archivos
   nuevos (`compositor.c`, `blend.c`, `resample.c`, `surface.c`) con sus propios headers.
3. **Round-trip siempre**: cualquier campo que no se entienda se guarda tal cual. Test
   obligatorio para cada campo nuevo.
4. **Nada de Skia para píxeles de documento**: el canvas compone buffers propios; Skia solo
   presenta y dibuja overlays. Esto mantiene la paridad Linux/Windows.
5. **Formato de píxeles único**: RGBA8888 premultiplicado, top-down, `stride = w*4`; máscaras
   gris 8-bit. No introducir otros formatos sin justificar.
6. **Tests primero en lo crítico**: blend, resample, formato, history. Cada PR debe pasar
   `flutter analyze` + `flutter test` en ambos SO.
7. **Commits pequeños y temáticos**; mensajes en inglés, estilo Conventional Commits
   (`feat:`, `fix:`, `test:`, `docs:`).
8. **Sin dependencias nuevas** fuera de la lista de la sección 4 sin aprobación explícita.
9. **Rendimiento**: kernels en C para bucles por píxel; Dart para orquestación. Si un bucle
   Dart supera ~5 ms en un frame típico, moverlo a C.
10. **Documentar divergencias** conocidas en `README.md` y `test/parity/known_divergences.md`
    en el mismo PR que las introduce.
11. **No tocar** `../Compositor` (el original) salvo el XCTest de generación de referencias,
    y nunca commitear cambios ahí.
12. Definición de "hecho" por tarea: código + tests + análisis limpio + documentación de la
    spec si cambia comportamiento.

---

## 12. Apéndices

### 12.1 Convenciones de nombres

- Dart: `snake_case.dart`, clases `UpperCamelCase`, miembros `lowerCamelCase`.
- C nuevo: prefijo `compositor_` para funciones globales nuevas.
- Identificadores de formato: nunca renombrar claves JSON ni cadenas de blend/sampling.
- Comentarios y UI en **inglés** (convención del original); este PLAN en español.
- UUIDs en JSON **en mayúsculas** (requisito del formato).

### 12.2 Cadenas exactas de `sampling`

`Nearest` · `Smooth` · `High quality`

### 12.3 Cadenas exactas de `blendMode`

`Normal`, `Darken`, `Multiply`, `Color Burn`, `Linear Burn`, `Lighten`, `Screen`,
`Color Dodge`, `Linear Dodge (Add)`, `Overlay`, `Soft Light`, `Hard Light`, `Vivid Light`,
`Linear Light`, `Pin Light`, `Hard Mix`, `Difference`, `Exclusion`, `Subtract`, `Divide`,
`Hue`, `Saturation`, `Color`, `Luminosity`.

### 12.4 Mapa de archivos original → port

| Original (macOS) | Port (Dart/C) | Fase |
|---|---|---|
| `Rendering/*.c/.h` (9 pares) | `native/src/`, `native/include/` | 0 |
| `IO/ProjectStore.swift` | `lib/io/comp/project_store.dart` | 1 |
| `Document/LayerTransform.swift` | `lib/core/model/layer_transform.dart` | 1 |
| `Document/LayerAppearance.swift` | `lib/core/model/blend_mode.dart` | 1 |
| `Document/DocumentLimits.swift` | `lib/core/model/limits.dart` | 1 |
| `Rendering/CanvasViewport.swift` | `lib/render/viewport.dart` | 1 |
| `Rendering/DownsampleCache.swift` | `lib/render/downsample_cache.dart` + `native/resample.c` | 1 |
| `Document/DocumentHistory.swift` | `lib/core/history/document_history.dart` | 1 |
| `Rendering/LayerRenderer.swift` | `lib/render/layer_renderer.dart` | 2 |
| `Rendering/SeparableBlend.swift` | `native/blend.c` | 2 |
| `Document/BrushStroke.swift` | `lib/core/brush/brush_stroke.dart` | 3 |
| `Document/EditorSession.swift` | `lib/core/session/editor_session.dart` | 3 |
| `Document/ProjectWorkspace.swift` | `lib/core/session/project_workspace.dart` | 3 |
| `Rendering/EditorCanvas.swift` | `lib/ui/canvas/canvas_view.dart` | 3 |
| `UI/LayersPanel.swift` + `UI/NativeLayerList.swift` | `lib/ui/panels/layers_panel.dart` | 3 |
| `Compositor/CompositorApp.swift` | `lib/main.dart` + `lib/ui/shell/` | 3 |
| `ContentView.swift` | `lib/ui/shell/editor_shell.dart` | 3 |
| `IO/ImageImporter.swift`, `IO/ImageExporter.swift` | `lib/io/image/` | 2–3 |
| `Rendering/TiledLayerRenderer.swift` | `lib/render/tiled_renderer.dart` | M6 |
| `Rendering/GPUCanvas.swift`, `MetalLayerEffects.swift`, `GPUNoise.swift`, `MetalBrushCoverage.swift`, `MetalWarp.swift` | `lib/render/gpu/` | M6 |
| `Document/LayerEffects.swift` | `lib/core/effects/layer_effects.dart` | M4 |
| `Document/CameraRaw*.swift` | `lib/core/filters/camera_raw/` | M4 |
| `Document/Filters.swift`, `Levels.swift`, `Curves.swift`, `HueSaturation.swift`, … | `lib/core/filters/` | M4 |
| `Document/Selection*.swift`, `MagicWand.swift`, `ObjectSelection.swift` | `lib/core/ops/selection/` | M3 |
| `Document/Crop.swift`, `ImageTrim.swift`, `CanvasSize.swift`, `ImageResizer.swift` | `lib/core/ops/` | M3 |
| `Document/TypeTool.swift` | `lib/core/text/type_tool.dart` | M4 |
| `IO/PSD/*` | `lib/io/psd/` | M5 |
| `IO/RawImporter.swift` | `lib/io/raw/` | M5 |
| `CompositorTests/*` (selección) | `test/unit/` | 1–4 |

### 12.5 Fixtures mínimos del MVP

| Fixture | Cubre |
|---|---|
| `single_layer.comp` | Capa única a tamaño de canvas |
| `offset_scaled.comp` | `origin`, `size` distintos al canvas |
| `rotated_flip.comp` | `rotation` 30°, `flipX`, `flipY` |
| `sampling_modes.comp` | Reducción con `Nearest`/`Smooth`/`High quality` |
| `opacity_blend.comp` | Pares de capas con los 24 blend modes y opacidades |
| `mask_basic.comp` | Máscara dura y degradada |
| `groups_nested.comp` | Grupos anidados con opacidad |
| `group_mask.comp` | Máscara de grupo (v6) |
| `transparent_edges.comp` | Bordes con alfa parcial y clamp premultiplicado |
| `large_10mp.comp` | Rendimiento y memoria |

### 12.6 Comandos de referencia

```bash
# Desarrollo
flutter run -d linux            # o -d windows
flutter analyze
flutter test

# Paridad (una vez generadas las referencias)
flutter test test/parity --dart-define=PARITY=1

# Build
flutter build linux --release
flutter build windows --release
```

---

*Fin del documento. Cualquier cambio de alcance, stack o formato debe reflejarse aquí antes de
implementarse.*
