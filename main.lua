function love.load()
    require('src/startup/gameStart')
    gameStart()
    loadMap("dungeon")
end

function love.update(dt)
    updateAll(dt)
end

function love.draw()
    if shaders and shaders.vignette then
        shaders.vignette:send("screen_size", {love.graphics.getDimensions()})
        love.graphics.setShader(shaders.vignette)
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
