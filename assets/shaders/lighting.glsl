// LIGHTING PASS ---------------------------------------------------------------------------
// Multiplies the whole scene with a dungeon light map: everything sits near
// darkness except a warm pool around the player, smaller glows around enemies
// who are alarmed/attacking, and tiny glows on projectiles (so homing bolts
// coming at you through the dark are visible *just* in time).
//
// Drawn as an axis-aligned white rectangle inside cam:attach() using love's
// MULTIPLY blend mode, so the shader output literally scales the scene below.
//
// FRAGMENT-ONLY, deliberately: this LÖVE build rejects single-file vertex
// stages (the top-level `varying` compiles as a read-only input, and the
// #ifdef VERTEX staging fails to link). It doesn't matter — see below.

// Light list sent fresh every frame from drawLighting() in src/draw.lua:
//   x, y = world position, z = light radius in pixels.
// Entries beyond lightCount are never read by the loop, so Lua only sends the
// live slots (up to 16).
uniform vec3 lights[16];   // slots: [0]=player, then projectiles, then attacking enemies
uniform int  lightCount;

// Camera uniforms, refreshed each frame: world = screen - windowCenter + cam.
// Valid exactly because the camera only ever translates (lookAt) and never
// zooms or rotates in this game.
uniform vec2 cam_pos;
uniform vec2 screen_size;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Screen pixel -> world pixel conversion (see uniform comment).
    vec2 worldPos = screen_coords - screen_size * 0.5 + cam_pos;

    // Dungeon ambience: cold, near-black (not fully black, so unlit areas stay
    // readable). Light is warm, like torchlight, for contrast.
    vec3 ambience = vec3(0.07, 0.06, 0.10);
    vec3 torch    = vec3(1.00, 0.95, 0.82);

    float light = 0.0;

    for (int i = 0; i < lightCount; i++) {
        float d = distance(worldPos, lights[i].xy);
        // Quadratic falloff: 1.0 at the light's center, 0.0 at the edge of its
        // radius. Squaring the linear ramp is what makes the pool bloom out
        // softly instead of looking like a hard disc.
        float t = 1.0 - clamp(d / lights[i].z, 0.0, 1.0);
        light += t * t;
    }
    // Overlapping lights (player + aura + bolt in the same spot) clamp to a
    // maximum instead of blowing out the scene.
    light = clamp(light, 0.0, 1.0);

    // mix() between the two colors gives the dark-to-warm ramp; multiplying by
    // the drawn color (always white here) keeps the pass transparent to later
    // color tweaks.
    return vec4(mix(ambience, torch, light) * color.rgb, color.a);
}
