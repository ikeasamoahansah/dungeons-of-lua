extern vec2 screen_size;
extern number radius = 0.75;
extern number softness = 0.45;

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
    vec4 tex = Texel(texture, texture_coords);
    vec2 position = (screen_coords.xy / screen_size) - vec2(0.5);
    number len = length(position);
    number vignette = 1.0 - smoothstep(radius - softness, radius, len);
    return tex * color * vec4(vignette, vignette, vignette, 1.0);
}
