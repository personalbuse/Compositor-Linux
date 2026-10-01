#ifndef COMPOSITOR_SURFACE_H
#define COMPOSITOR_SURFACE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  uint8_t *rgba;
  size_t width;
  size_t height;
  size_t stride;
} CompositorSurface;

typedef struct {
  uint8_t *gray;
  size_t width;
  size_t height;
  size_t stride;
} CompositorMask;

CompositorSurface *compositor_surface_alloc(size_t width, size_t height);
void compositor_surface_free(CompositorSurface *surface);
void compositor_surface_fill(CompositorSurface *surface, uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void compositor_surface_clear(CompositorSurface *surface);
void compositor_surface_copy(const CompositorSurface *src, CompositorSurface *dst);
void compositor_surface_blit(const CompositorSurface *src, CompositorSurface *dst,
                             size_t src_x, size_t src_y, size_t dst_x, size_t dst_y,
                             size_t width, size_t height);
CompositorSurface *compositor_surface_resize(const CompositorSurface *src, size_t new_width, size_t new_height);

CompositorMask *compositor_mask_alloc(size_t width, size_t height);
void compositor_mask_free(CompositorMask *mask);
void compositor_mask_fill(CompositorMask *mask, uint8_t value);

#ifdef __cplusplus
}
#endif

#endif