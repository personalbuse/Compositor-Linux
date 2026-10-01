#include "blend.h"
#include <math.h>

static inline float clampf(float x) {
  return x < 0 ? 0 : (x > 1 ? 1 : x);
}

float blend_channel(float cb, float cs, BlendMode mode) {
  switch (mode) {
    case BLEND_NORMAL: return cs;
    case BLEND_DARKEN: return fminf(cb, cs);
    case BLEND_MULTIPLY: return cb * cs;
    case BLEND_COLOR_BURN:
      return cb == 0 ? 0 : 1 - fminf(1, (1 - cb) / cs);
    case BLEND_LINEAR_BURN: return cb + cs - 1;
    case BLEND_LIGHTEN: return fmaxf(cb, cs);
    case BLEND_SCREEN: return cb + cs - cb * cs;
    case BLEND_COLOR_DODGE:
      return cb == 1 ? 1 : fminf(1, cb / (1 - cs));
    case BLEND_LINEAR_DODGE: return fminf(1, cb + cs);
    case BLEND_OVERLAY:
      return cb <= 0.5 ? 2 * cb * cs : 1 - 2 * (1 - cb) * (1 - cs);
    case BLEND_SOFT_LIGHT: {
      if (cs <= 0.5) {
        return cb - (1 - 2 * cs) * cb * (1 - cb);
      } else {
        float d = cb <= 0.25 ? ((16 * cb - 12) * cb + 4) * cb : sqrtf(cb);
        return cb + (2 * cs - 1) * (d - cb);
      }
    }
    case BLEND_HARD_LIGHT:
      return cs <= 0.5 ? 2 * cb * cs : 1 - 2 * (1 - cb) * (1 - cs);
    case BLEND_VIVID_LIGHT:
      return cs <= 0.5
        ? (cb == 0 ? 0 : 1 - fminf(1, (1 - cb) / (2 * cs)))
        : (cb == 1 ? 1 : fminf(1, cb / (1 - (2 * cs - 1))));
    case BLEND_LINEAR_LIGHT:
      return cs <= 0.5 ? cb + 2 * cs - 1 : cb + 2 * (cs - 0.5);
    case BLEND_PIN_LIGHT:
      return cs <= 0.5 ? fminf(cb, 2 * cs) : fmaxf(cb, 2 * cs - 1);
    case BLEND_HARD_MIX: {
      float v = blend_channel(cb, cs, BLEND_VIVID_LIGHT);
      return v < 0.5 ? 0 : 1;
    }
    case BLEND_DIFFERENCE: return fabsf(cb - cs);
    case BLEND_EXCLUSION: return cb + cs - 2 * cb * cs;
    case BLEND_SUBTRACT: return fmaxf(0, cb - cs);
    case BLEND_DIVIDE: return cs == 0 ? 1 : fminf(1, cb / cs);
    case BLEND_HUE:
    case BLEND_SATURATION:
    case BLEND_COLOR:
    case BLEND_LUMINOSITY:
      return cs;
  }
  return cs;
}

void blend_rgb(float *cb, const float *cs, BlendMode mode) {
  if (mode <= BLEND_DIVIDE) {
    cb[0] = blend_channel(cb[0], cs[0], mode);
    cb[1] = blend_channel(cb[1], cs[1], mode);
    cb[2] = blend_channel(cb[2], cs[2], mode);
    return;
  }
  
  float hsb[3], hsb_s[3];
  rgb_to_hsl(cb[0], cb[1], cb[2], &hsb[0], &hsb[1], &hsb[2]);
  rgb_to_hsl(cs[0], cs[1], cs[2], &hsb_s[0], &hsb_s[1], &hsb_s[2]);
  
  float h = hsb[0], s = hsb[1], l = hsb[2];
  float hs = hsb_s[0], ss = hsb_s[1], ls = hsb_s[2];
  
  switch (mode) {
    case BLEND_HUE: h = hs; break;
    case BLEND_SATURATION: s = ss; break;
    case BLEND_COLOR: h = hs; s = ss; break;
    case BLEND_LUMINOSITY: l = ls; break;
  }
  
  hsl_to_rgb(h, s, l, &cb[0], &cb[1], &cb[2]);
}

void rgb_to_hsl(float r, float g, float b, float *h, float *s, float *l) {
  float max = fmaxf(fmaxf(r, g), b);
  float min = fminf(fminf(r, g), b);
  float delta = max - min;
  
  *l = (max + min) / 2;
  
  if (delta == 0) {
    *h = 0;
    *s = 0;
  } else {
    *s = (*l <= 0.5) ? delta / (max + min) : delta / (2 - max - min);
    if (max == r) *h = (g - b) / delta + (g < b ? 6 : 0);
    else if (max == g) *h = (b - r) / delta + 2;
    else *h = (r - g) / delta + 4;
    *h /= 6;
  }
}

void hsl_to_rgb(float h, float s, float l, float *r, float *g, float *b) {
  if (s == 0) {
    *r = *g = *b = l;
    return;
  }
  
  float q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  float p = 2 * l - q;
  
  float hk = fmodf(h * 6, 6);
  float t[3] = { hk + 2, hk, hk - 2 };
  
  for (int i = 0; i < 3; i++) {
    float tc = t[i];
    if (tc < 0) tc += 6;
    if (tc > 6) tc -= 6;
    if (tc < 1) t[i] = p + (q - p) * tc;
    else if (tc < 3) t[i] = q;
    else if (tc < 4) t[i] = p + (q - p) * (4 - tc);
    else t[i] = p;
  }
  
  *r = t[0]; *g = t[1]; *b = t[2];
}

float set_lum(float r, float g, float b, float l) {
  float d = l - lum(r, g, b);
  r += d; g += d; b += d;
  return clip_color(r, g, b);
}

float clip_color(float r, float g, float b) {
  float max = fmaxf(fmaxf(r, g), b);
  float min = fminf(fminf(r, g), b);
  if (min < 0 || max > 1) {
    float l = lum(r, g, b);
    if (max > 1) {
      r = l + (r - l) * (1 - l) / (max - l);
      g = l + (g - l) * (1 - l) / (max - l);
      b = l + (b - l) * (1 - l) / (max - l);
    }
    if (min < 0) {
      r = l + (r - l) * l / (l - min);
      g = l + (g - l) * l / (l - min);
      b = l + (b - l) * l / (l - min);
    }
  }
  return 0;
}

float sat(float r, float g, float b) {
  return fmaxf(fmaxf(r, g), b) - fminf(fminf(r, g), b);
}

float lum(float r, float g, float b) {
  return 0.3 * r + 0.59 * g + 0.11 * b;
}

void compositor_blend_pixel(uint8_t *dst_rgba, const uint8_t *src_rgba, BlendMode mode) {
  float as = src_rgba[3] / 255.0f;
  float ab = dst_rgba[3] / 255.0f;
  
  if (as == 0) return;
  if (ab == 0) {
    dst_rgba[0] = src_rgba[0];
    dst_rgba[1] = src_rgba[1];
    dst_rgba[2] = src_rgba[2];
    dst_rgba[3] = src_rgba[3];
    return;
  }
  
  float cs[3] = { src_rgba[0] / 255.0f, src_rgba[1] / 255.0f, src_rgba[2] / 255.0f };
  float cb[3] = { dst_rgba[0] / 255.0f, dst_rgba[1] / 255.0f, dst_rgba[2] / 255.0f };
  
  if (mode >= BLEND_HUE) {
    float hsb[3];
    rgb_to_hsl(cs[0], cs[1], cs[2], &hsb[0], &hsb[1], &hsb[2]);
    rgb_to_hsl(cb[0], cb[1], cb[2], &hsb[0], &hsb[1], &hsb[2]);
  }
  
  blend_rgb(cb, cs, mode);
  
  float ao = as + ab * (1 - as);
  if (ao == 0) {
    dst_rgba[0] = dst_rgba[1] = dst_rgba[2] = dst_rgba[3] = 0;
    return;
  }
  
  float co_r = (as * (1 - ab) * cs[0] + as * ab * cb[0] + (1 - as) * ab * cb[0]) / ao;
  float co_g = (as * (1 - ab) * cs[1] + as * ab * cb[1] + (1 - as) * ab * cb[1]) / ao;
  float co_b = (as * (1 - ab) * cs[2] + as * ab * cb[2] + (1 - as) * ab * cb[2]) / ao;
  
  dst_rgba[0] = (uint8_t)(co_r * 255 * ao + 0.5f);
  dst_rgba[1] = (uint8_t)(co_g * 255 * ao + 0.5f);
  dst_rgba[2] = (uint8_t)(co_b * 255 * ao + 0.5f);
  dst_rgba[3] = (uint8_t)(ao * 255 + 0.5f);
}