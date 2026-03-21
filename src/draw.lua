function drawCamera()
    --if gameState == 0 then return end
    
    if gameMap.layers["floor"] then
        gameMap:drawLayer(gameMap.layers["floor"])
    end

    if gameMap.layers["base_wall"] then
        gameMap:drawLayer(gameMap.layers["base_wall"])
    end

    drawPlayer()
    enemies:draw()
end


function drawGameOver()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    --Dark overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    --GAME OVER text
    love.graphics.setColor(1, 0.1, 0.1, 1)
    love.graphics.setFont(fonts.large)
    love.graphics.printf("GAME OVER", 0, h / 2 - 40, w, "center")

    -- Restart hint
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(fonts.medium)
    love.graphics.printf("Press R to restart", 0, h / 2 + 10, w, "center")

    -- Reset color and font to default
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.getFont())
end