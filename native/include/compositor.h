#ifndef COMPOSITOR_COMPOSITOR_H
#define COMPOSITOR_COMPOSITOR_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  BLEND_NORMAL = 0,
  BLEND_DARKEN = 1,
  BLEND_MULTIPLY = 2,
  BLEND_COLOR_BURN = 3,
  BLEND_LINEAR_BURN = 4,
  BLEND_LIGHTEN = 5,
  BLEND_SCREEN = 6,
  BLEND_COLOR_DODGE = 7,
  BLEND_LINEAR_DODGE = 8,
  BLEND_OVERLAY = 9,
  BLEND_SOFT_LIGHT = 10,
  BLEND_HARD_LIGHT = 11,
  BLEND_VIVID_LIGHT = 12,
  BLEND_LINEAR_LIGHT = 13,
  BLEND_PIN_LIGHT = 14,
  BLEND_HARD_MIX = 15,
  BLEND_DIFFERENCE = 16,
  BLEND_EXCLUSION = 17,
  BLEND_SUBTRACT = 18,
  BLEND_DIVIDE = 19,
  BLEND_HUE = 20,
  BLEND_SATURATION = 21,
  BLEND_COLOR = 22,
  BLEND_LUMINOSITY = 23
} BlendMode;

void compositor_blend_pixel(uint8_t *dst_rgba, const uint8_t *src_rgba, BlendMode mode);
void compositor_composite_layer(const uint8_t *src, size_t src_stride,
                                uint8_t *dst, size_t dst_stride,
                                size_t width, size_t height,
                                float opacity, BlendMode mode,
                                const uint8_t *mask, size_t mask_stride);

#ifdef __cplusplus
}
#endif

#endif