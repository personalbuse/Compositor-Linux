#include "surface.h"
#include <stdlib.h>
#include <string.h>

CompositorSurface *compositor_surface_alloc(size_t width, size_t height) {
  CompositorSurface *surface = (CompositorSurface *)calloc(1, sizeof(CompositorSurface));
  if (!surface) return NULL;
  
  surface->width = width;
  surface->height = height;
  surface->stride = width * 4;
  surface->rgba = (uint8_t *)calloc(height * surface->stride, 1);
  if (!surface->rgba) {
    free(surface);
    return NULL;
  }
  return surface;
}

void compositor_surface_free(CompositorSurface *surface) {
  if (surface) {
    free(surface->rgba);
    free(surface);
  }
}

void compositor_surface_fill(CompositorSurface *surface, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  if (!surface || !surface->rgba) return;
  size_t total = surface->height * surface->stride;
  for (size_t i = 0; i < total; i += 4) {
    surface->rgba[i] = r;
    surface->rgba[i + 1] = g;
    surface->rgba[i + 2] = b;
    surface->rgba[i + 3] = a;
  }
}

void compositor_surface_clear(CompositorSurface *surface) {
  if (!surface || !surface->rgba) return;
  memset(surface->rgba, 0, surface->height * surface->stride);
}

void compositor_surface_copy(const CompositorSurface *src, CompositorSurface *dst) {
  if (!src || !dst || !src->rgba || !dst->rgba) return;
  if (src->width != dst->width || src->height != dst->height) return;
  memcpy(dst->rgba, src->rgba, src->height * src->stride);
}

void compositor_surface_blit(const CompositorSurface *src, CompositorSurface *dst,
                             size_t src_x, size_t src_y, size_t dst_x, size_t dst_y,
                             size_t width, size_t height) {
  if (!src || !dst || !src->rgba || !dst->rgba) return;
  if (src_x + width > src->width || src_y + height > src->height) return;
  if (dst_x + width > dst->width || dst_y + height > dst->height) return;
  
  for (size_t y = 0; y < height; y++) {
    size_t src_offset = (src_y + y) * src->stride + src_x * 4;
    size_t dst_offset = (dst_y + y) * dst->stride + dst_x * 4;
    memcpy(dst->rgba + dst_offset, src->rgba + src_offset, width * 4);
  }
}

CompositorSurface *compositor_surface_resize(const CompositorSurface *src, size_t new_width, size_t new_height) {
  if (!src || !src->rgba) return NULL;
  CompositorSurface *dst = compositor_surface_alloc(new_width, new_height);
  if (!dst) return NULL;
  
  float x_ratio = (float)src->width / new_width;
  float y_ratio = (float)src->height / new_height;
  
  for (size_t y = 0; y < new_height; y++) {
    for (size_t x = 0; x < new_width; x++) {
      size_t src_x = (size_t)(x * x_ratio);
      size_t src_y = (size_t)(y * y_ratio);
      if (src_x >= src->width) src_x = src->width - 1;
      if (src_y >= src->height) src_y = src->height - 1;
      
      size_t src_offset = src_y * src->stride + src_x * 4;
      size_t dst_offset = y * dst->stride + x * 4;
      memcpy(dst->rgba + dst_offset, src->rgba + src_offset, 4);
    }
  }
  return dst;
}

CompositorMask *compositor_mask_alloc(size_t width, size_t height) {
  CompositorMask *mask = (CompositorMask *)calloc(1, sizeof(CompositorMask));
  if (!mask) return NULL;
  
  mask->width = width;
  mask->height = height;
  mask->stride = width;
  mask->gray = (uint8_t *)calloc(height * width, 1);
  if (!mask->gray) {
    free(mask);
    return NULL;
  }
  return mask;
}

void compositor_mask_free(CompositorMask *mask) {
  if (mask) {
    free(mask->gray);
    free(mask);
  }
}

void compositor_mask_fill(CompositorMask *mask, uint8_t value) {
  if (!mask || !mask->gray) return;
  memset(mask->gray, value, mask->height * mask->stride);
}