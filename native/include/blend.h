#ifndef COMPOSITOR_BLEND_H
#define COMPOSITOR_BLEND_H

#include <stdint.h>
#include <stddef.h>
#include "compositor.h"

#ifdef __cplusplus
extern "C" {
#endif

float blend_channel(float cb, float cs, BlendMode mode);
void blend_rgb(float *cb, const float *cs, BlendMode mode);
void rgb_to_hsl(float r, float g, float b, float *h, float *s, float *l);
void hsl_to_rgb(float h, float s, float l, float *r, float *g, float *b);
float set_lum(float r, float g, float b, float l);
float clip_color(float r, float g, float b);
float sat(float r, float g, float b);
float lum(float r, float g, float b);

#ifdef __cplusplus
}
#endif

#endif