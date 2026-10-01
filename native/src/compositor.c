#include "compositor.h"
#include "blend.h"
#include <string.h>

void compositor_composite_layer(const uint8_t *src, size_t src_stride,
                                uint8_t *dst, size_t dst_stride,
                                size_t width, size_t height,
                                float opacity, BlendMode mode,
                                const uint8_t *mask, size_t mask_stride) {
  for (size_t y = 0; y < height; y++) {
    const uint8_t *src_row = src + y * src_stride;
    uint8_t *dst_row = dst + y * dst_stride;
    const uint8_t *mask_row = mask ? mask + y * mask_stride : NULL;
    
    for (size_t x = 0; x < width; x++) {
      uint8_t src_pixel[4] = { src_row[x * 4], src_row[x * 4 + 1], src_row[x * 4 + 2], src_row[x * 4 + 3] };
      
      if (opacity < 1.0f) {
        src_pixel[3] = (uint8_t)(src_pixel[3] * opacity + 0.5f);
      }
      
      if (mask_row) {
        float mask_val = mask_row[x] / 255.0f;
        src_pixel[3] = (uint8_t)(src_pixel[3] * mask_val + 0.5f);
      }
      
      if (src_pixel[3] > 0) {
        compositor_blend_pixel(dst_row + x * 4, src_pixel, mode);
      }
    }
  }
}