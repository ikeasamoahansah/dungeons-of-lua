/* VIGNETTE PASS ------------------------------------------------------------------------
   Darkens screen corners to focus the camera on dungeon walls; drawn fullscreen
   in main.lua each frame (outside cam:attach). FRAGMENT-ONLY, deliberately:
   this LÖVE build rejects single-file vertex stages. */

// GLSL ES NOTE (web build): uniform initializers (`extern x = y`) are illegal
// in GLSL ES, so radius/softness are plain constants inside the body now —
// same values desktop used. The parameter is "tex", not "texture": that name
// shadows the built-in texture() function Texel() uses when LÖVE compiles for
// GLSL ES / WebGL.
extern vec2 screen_size;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 texel = Texel(tex, texture_coords);
    vec2 position = (screen_coords.xy / screen_size) - vec2(0.5);
    float len = length(position);
    // radius 0.75, softness 0.45 (former extern defaults, inlined for web)
    float vignette = 1.0 - smoothstep(0.30, 0.75, len);
    return texel * color * vec4(vignette, vignette, vignette, 1.0);
}
