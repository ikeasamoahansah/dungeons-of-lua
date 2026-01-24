extern number radius = 0.9;
extern number softness = 0.45;

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
    vec4 tex = Texel(texture, texture_coords);
    vec2 position = (screen_coords.xy / love.graphics.getDimensions()) - vec2(0.5);
    number len = length(position);
    number vignette = smoothstep(radius, radius-softness, len);
    return tex * color * vec4(1.0, 1.0, 1.0, vignette);
}
