function love.load()
    require('src/startup/gameStart')
    gameStart()
    loadMap("dungeon")
end

function love.update(dt)
    updateAll(dt)
end

function love.draw()
    local shader = love.graphics.newShader([[
        extern number radius = 0.9;
        extern number softness = 0.45;

        vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
            vec4 tex = Texel(texture, texture_coords);
            vec2 position = (screen_coords.xy / love.graphics.getDimensions()) - vec2(0.5);
            number len = length(position);
            number vignette = smoothstep(radius, radius-softness, len);
            return tex * color * vec4(1.0, 1.0, 1.0, vignette);
        }
    ]])

    if shader then
        love.graphics.setShader(shader)
    end

    cam:attach()
    drawCamera()
    cam:detach()

    love.graphics.setShader()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    
    if key == "z" then
        sounds.dungeon:stop()
    end
end
