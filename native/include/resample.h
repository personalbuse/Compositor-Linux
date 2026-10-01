#ifndef COMPOSITOR_RESAMPLE_H
#define COMPOSITOR_RESAMPLE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  RESAMPLE_NEAREST = 0,
  RESAMPLE_BILINEAR = 1,
  RESAMPLE_LANCZOS3 = 2
} ResampleMethod;

int compositor_halving_rgba(const uint8_t *src, size_t src_w, size_t src_h, size_t src_stride,
                            uint8_t *dst, size_t dst_stride);

int compositor_halving_gray(const uint8_t *src, size_t src_w, size_t src_h, size_t src_stride,
                            uint8_t *dst, size_t dst_stride);

int compositor_resample_rgba(const uint8_t *src, size_t src_w, size_t src_h, size_t src_stride,
                             uint8_t *dst, size_t dst_w, size_t dst_h, size_t dst_stride,
                             ResampleMethod method);

int compositor_resample_gray(const uint8_t *src, size_t src_w, size_t src_h, size_t src_stride,
                             uint8_t *dst, size_t dst_w, size_t dst_h, size_t dst_stride,
                             ResampleMethod method);

void compositor_rgba_clamp_premultiplied(uint8_t *rgba, size_t count);

#ifdef __cplusplus
}
#endif

#endif