#include "resample.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define LANCZOS_TAPS 3
#define LANCZOS_RADIUS 3.0f

static float lanczos3(float x) {
  if (x == 0.0f) return 1.0f;
  if (x < -LANCZOS_RADIUS || x > LANCZOS_RADIUS) return 0.0f;
  float xpi = x * 3.14159265358979323846f;
  float xpi3 = xpi / 3.0f;
  return (sinf(xpi) / xpi) * (sinf(xpi3) / xpi3);
}

static void compute_lanczos_weights(float scale, float *weights, int *indices, int *count, int src_size, int dst_idx) {
  float center = (dst_idx + 0.5f) * scale - 0.5f;
  int start = (int)floorf(center - LANCZOS_RADIUS);
  int end = (int)ceilf(center + LANCZOS_RADIUS);
  *count = 0;
  float sum = 0.0f;
  
  for (int i = start; i <= end; i++) {
    int idx = i;
    if (idx < 0) idx = 0;
    if (idx >= src_size) idx = src_size - 1;
    float w = lanczos3((i - center));
    if (w != 0.0f) {
      weights[*count] = w;
      indices[*count] = idx;
      sum += w;
      (*count)++;
    }
  }
  
  for (int i = 0; i < *count; i++) {
    weights[i] /= sum;
  }
}

int compositor_halving_rgba(const uint8_t *src, size_t src_w, size_t src_h, size_t src_stride,
                            uint8_t *dst, size_t dst_stride) {
  if (!src || !dst) return -1;
  
  size_t dst_w = (src_w + 1) / 2;
  size_t dst_h = (src_h + 1) / 2;
  float scale = 2.0f;
  
  const int PADDING = 8;
  size_t padded_w = src_w + 2 * PADDING;
  size_t padded_h = src_h + 2 * PADDING;
  size_t padded_stride = padded_w * 4;
  uint8_t *padded = (uint8_t *)calloc(padded_h * padded_stride, 1);
  if (!padded) return -1;
  
  for (size_t y = 0; y < src_h; y++) {
    memcpy(padded + (y + PADDING) * padded_stride + PADDING * 4,
           src + y * src_stride, src_w * 4);
  }
  
  for (size_t y = 0; y < PADDING; y++) {
    memcpy(padded + y * padded_stride + PADDING * 4,
           padded + PADDING * padded_stride + PADDING * 4, src_w * 4);
    memcpy(padded + (padded_h - 1 - y) * padded_stride + PADDING * 4,
           padded + (PADDING + src_h - 1) * padded_stride + PADDING * 4, src_w * 4);
  }
  
  for (size_t y = 0; y < padded_h; y++) {
    for (size_t x = 0; x < PADDING; x++) {
      size_t src_idx = (y * padded_stride + PADDING * 4);
      size_t dst_idx_left = y * padded_stride + x * 4;
      size_t dst_idx_right = y * padded_stride + (PADDING + src_w + x) * 4;
      memcpy(padded + dst_idx_left, padded + src_idx, 4);
      memcpy(padded + dst_idx_right, padded + src_idx + (src_w - 1) * 4, 4);
    }
  }
  
  float weights[16];
  int indices[16];
  int count;
  
  for (size_t y = 0; y < dst_h; y++) {
    for (size_t x = 0; x < dst_w; x++) {
      float r = 0, g = 0, b = 0, a = 0;
      
      compute_lanczos_weights(scale, weights, indices, &count, padded_h, y + PADDING);
      for (int ky = 0; ky < count; ky++) {
        float wy = weights[ky];
        int sy = indices[ky];
        
        compute_lanczos_weights(scale, weights, indices, &count, padded_w, x + PADDING);
        for (int kx = 0; kx < count; kx++) {
          float wx = weights[kx];
          int sx = indices[kx];
          size_t offset = sy * padded_stride + sx * 4;
          float w = wy * wx;
          r += padded[offset] * w;
          g += padded[offset + 1] * w;
          b += padded[offset + 2] * w;
          a += padded[offset + 3] * w;
        }
      }
      
      size_t dst_offset = y * dst_stride + x * 4;
      dst[dst_offset] = (uint8_t)(r + 0.5f);
      dst[dst_offset + 1] = (uint8_t)(g + 0.5f);
      dst[dst_offset + 2] = (uint8_t)(b + 0.5f);
      dst[dst_offset + 3] = (uint8_t)(a + 0.5f);
    }
  }
  
  free(padded);
  return 0;
}

int compositor_halving_gray(const uint8_t *src, size_t src_w, size_t src_h, size_t src_stride,
                            uint8_t *dst, size_t dst_stride) {
  if (!src || !dst) return -1;
  
  size_t dst_w = (src_w + 1) / 2;
  size_t dst_h = (src_h + 1) / 2;
  float scale = 2.0f;
  
  float weights[16];
  int indices[16];
  int count;
  
  for (size_t y = 0; y < dst_h; y++) {
    for (size_t x = 0; x < dst_w; x++) {
      float val = 0;
      
      compute_lanczos_weights(scale, weights, indices, &count, src_h, y);
      for (int ky = 0; ky < count; ky++) {
        float wy = weights[ky];
        int sy = indices[ky];
        if (sy >= (int)src_h) sy = src_h - 1;
        
        compute_lanczos_weights(scale, weights, indices, &count, src_w, x);
        for (int kx = 0; kx < count; kx++) {
          float wx = weights[kx];
          int sx = indices[kx];
          if (sx >= (int)src_w) sx = src_w - 1;
          val += src[sy * src_stride + sx] * wy * wx;
        }
      }
      
      dst[y * dst_stride + x] = (uint8_t)(val + 0.5f);
    }
  }
  return 0;
}

static uint8_t lerp_byte(uint8_t a, uint8_t b, float t) {
  return (uint8_t)(a + (b - a) * t + 0.5f);
}

int compositor_resample_rgba(const uint8_t *src, size_t src_w, size_t src_h, size_t src_stride,
                             uint8_t *dst, size_t dst_w, size_t dst_h, size_t dst_stride,
                             ResampleMethod method) {
  if (!src || !dst) return -1;
  if (src_w == 0 || src_h == 0 || dst_w == 0 || dst_h == 0) return -1;
  
  float x_scale = (float)src_w / dst_w;
  float y_scale = (float)src_h / dst_h;
  
  if (method == RESAMPLE_NEAREST) {
    for (size_t y = 0; y < dst_h; y++) {
      size_t sy = (size_t)(y * y_scale);
      if (sy >= src_h) sy = src_h - 1;
      for (size_t x = 0; x < dst_w; x++) {
        size_t sx = (size_t)(x * x_scale);
        if (sx >= src_w) sx = src_w - 1;
        size_t src_offset = sy * src_stride + sx * 4;
        size_t dst_offset = y * dst_stride + x * 4;
        memcpy(dst + dst_offset, src + src_offset, 4);
      }
    }
    return 0;
  }
  
  if (method == RESAMPLE_BILINEAR) {
    for (size_t y = 0; y < dst_h; y++) {
      float fy = y * y_scale;
      size_t sy0 = (size_t)fy;
      size_t sy1 = sy0 + 1 < src_h ? sy0 + 1 : sy0;
      float ty = fy - sy0;
      
      for (size_t x = 0; x < dst_w; x++) {
        float fx = x * x_scale;
        size_t sx0 = (size_t)fx;
        size_t sx1 = sx0 + 1 < src_w ? sx0 + 1 : sx0;
        float tx = fx - sx0;
        
        size_t o00 = sy0 * src_stride + sx0 * 4;
        size_t o01 = sy0 * src_stride + sx1 * 4;
        size_t o10 = sy1 * src_stride + sx0 * 4;
        size_t o11 = sy1 * src_stride + sx1 * 4;
        size_t dst_offset = y * dst_stride + x * 4;
        
        for (int c = 0; c < 4; c++) {
          float v00 = src[o00 + c];
          float v01 = src[o01 + c];
          float v10 = src[o10 + c];
          float v11 = src[o11 + c];
          float v0 = v00 + (v01 - v00) * tx;
          float v1 = v10 + (v11 - v10) * tx;
          dst[dst_offset + c] = (uint8_t)(v0 + (v1 - v0) * ty + 0.5f);
        }
      }
    }
    return 0;
  }
  
  if (method == RESAMPLE_LANCZOS3) {
    float weights[16];
    int indices[16];
    int count;
    
    for (size_t y = 0; y < dst_h; y++) {
      float fy = (y + 0.5f) * y_scale - 0.5f;
      compute_lanczos_weights(1.0f, weights, indices, &count, src_h, (int)fy);
      
      for (size_t x = 0; x < dst_w; x++) {
        float fx = (x + 0.5f) * x_scale - 0.5f;
        compute_lanczos_weights(1.0f, weights, indices, &count, src_w, (int)fx);
        
        float r = 0, g = 0, b = 0, a = 0;
        float wsum = 0;
        
        for (int ky = 0; ky < count; ky++) {
          float wy = weights[ky];
          int sy = indices[ky];
          
          compute_lanczos_weights(1.0f, weights, indices, &count, src_w, (int)fx);
          for (int kx = 0; kx < count; kx++) {
            float wx = weights[kx];
            int sx = indices[kx];
            float w = wy * wx;
            size_t offset = sy * src_stride + sx * 4;
            r += src[offset] * w;
            g += src[offset + 1] * w;
            b += src[offset + 2] * w;
            a += src[offset + 3] * w;
            wsum += w;
          }
        }
        
        if (wsum > 0) {
          r /= wsum;
          g /= wsum;
          b /= wsum;
          a /= wsum;
        }
        
        size_t dst_offset = y * dst_stride + x * 4;
        dst[dst_offset] = (uint8_t)(r + 0.5f);
        dst[dst_offset + 1] = (uint8_t)(g + 0.5f);
        dst[dst_offset + 2] = (uint8_t)(b + 0.5f);
        dst[dst_offset + 3] = (uint8_t)(a + 0.5f);
      }
    }
    return 0;
  }
  
  return -1;
}

int compositor_resample_gray(const uint8_t *src, size_t src_w, size_t src_h, size_t src_stride,
                             uint8_t *dst, size_t dst_w, size_t dst_h, size_t dst_stride,
                             ResampleMethod method) {
  if (!src || !dst) return -1;
  if (src_w == 0 || src_h == 0 || dst_w == 0 || dst_h == 0) return -1;
  
  float x_scale = (float)src_w / dst_w;
  float y_scale = (float)src_h / dst_h;
  
  if (method == RESAMPLE_NEAREST) {
    for (size_t y = 0; y < dst_h; y++) {
      size_t sy = (size_t)(y * y_scale);
      if (sy >= src_h) sy = src_h - 1;
      for (size_t x = 0; x < dst_w; x++) {
        size_t sx = (size_t)(x * x_scale);
        if (sx >= src_w) sx = src_w - 1;
        dst[y * dst_stride + x] = src[sy * src_stride + sx];
      }
    }
    return 0;
  }
  
  if (method == RESAMPLE_BILINEAR) {
    for (size_t y = 0; y < dst_h; y++) {
      float fy = y * y_scale;
      size_t sy0 = (size_t)fy;
      size_t sy1 = sy0 + 1 < src_h ? sy0 + 1 : sy0;
      float ty = fy - sy0;
      
      for (size_t x = 0; x < dst_w; x++) {
        float fx = x * x_scale;
        size_t sx0 = (size_t)fx;
        size_t sx1 = sx0 + 1 < src_w ? sx0 + 1 : sx0;
        float tx = fx - sx0;
        
        float v00 = src[sy0 * src_stride + sx0];
        float v01 = src[sy0 * src_stride + sx1];
        float v10 = src[sy1 * src_stride + sx0];
        float v11 = src[sy1 * src_stride + sx1];
        float v0 = v00 + (v01 - v00) * tx;
        float v1 = v10 + (v11 - v10) * tx;
        dst[y * dst_stride + x] = (uint8_t)(v0 + (v1 - v0) * ty + 0.5f);
      }
    }
    return 0;
  }
  
  if (method == RESAMPLE_LANCZOS3) {
    float weights[16];
    int indices[16];
    int count;
    
    for (size_t y = 0; y < dst_h; y++) {
      float fy = (y + 0.5f) * y_scale - 0.5f;
      compute_lanczos_weights(1.0f, weights, indices, &count, src_h, (int)fy);
      
      for (size_t x = 0; x < dst_w; x++) {
        float fx = (x + 0.5f) * x_scale - 0.5f;
        compute_lanczos_weights(1.0f, weights, indices, &count, src_w, (int)fx);
        
        float val = 0;
        float wsum = 0;
        
        for (int ky = 0; ky < count; ky++) {
          float wy = weights[ky];
          int sy = indices[ky];
          
          compute_lanczos_weights(1.0f, weights, indices, &count, src_w, (int)fx);
          for (int kx = 0; kx < count; kx++) {
            float wx = weights[kx];
            int sx = indices[kx];
            val += src[sy * src_stride + sx] * wy * wx;
            wsum += wy * wx;
          }
        }
        
        if (wsum > 0) val /= wsum;
        dst[y * dst_stride + x] = (uint8_t)(val + 0.5f);
      }
    }
    return 0;
  }
  
  return -1;
}

void compositor_rgba_clamp_premultiplied(uint8_t *rgba, size_t count) {
  for (size_t i = 0; i < count * 4; i += 4) {
    uint8_t a = rgba[i + 3];
    if (a == 0) {
      rgba[i] = rgba[i + 1] = rgba[i + 2] = 0;
    } else if (a < 255) {
      float inv_a = 255.0f / a;
      for (int c = 0; c < 3; c++) {
        int v = (int)(rgba[i + c] * inv_a + 0.5f);
        if (v > 255) v = 255;
        rgba[i + c] = (uint8_t)v;
      }
    }
  }
}