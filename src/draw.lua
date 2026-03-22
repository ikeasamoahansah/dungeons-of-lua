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
    drawEnemyHealthBars()
    drawProjectiles()
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
    love.graphics.printf("Press 'R' to restart", 0, h / 2 + 10, w, "center")

    -- Reset color and font to default
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.getFont())
end

function drawHUD()
    local barWidth = 150
    local barHeight = 14
    local x = 20
    local y = 20
    local healthPercent = player.health / player.maxHealth

    -- Flash bar red/white when invincible (just took damage)
    local flashColor = {0.85, 0.15, 0.15, 1}
    if player.invincibleTimer > 0 then
        local flash = math.sin(player.invincibleTimer * 20) > 0
        flashColor = flash and {1, 1, 1, 1} or {0.85, 0.15, 0.15, 1}
    end

    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight, 4, 4)

    -- Health fill with flash
    love.graphics.setColor(flashColor)
    love.graphics.rectangle("fill", x, y, barWidth * healthPercent, barHeight, 4, 4)

    -- Border
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.rectangle("line", x, y, barWidth, barHeight, 4, 4)

    -- Label
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("HP  " .. player.health .. "/" .. player.maxHealth, x, y + barHeight + 4)

    love.graphics.setColor(1, 1, 1, 1)
end

function drawEnemyHealthBars()
    for _, e in ipairs(enemies) do
        if e.physics and not e.dead then  -- skip dead enemies
            local ex, ey = e.physics:getPosition()
            local barWidth = 24
            local barHeight = 3
            local x = ex - barWidth / 2
            local y = ey - 20

            local healthPercent = math.max(0, e.health / (e.maxHealth or e.health))
            if healthPercent >= 1 then goto continue end

            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
            love.graphics.rectangle("fill", x, y, barWidth, barHeight, 1, 1)

            local r = 1 - healthPercent
            local g = healthPercent
            love.graphics.setColor(r, g, 0.1, 1)
            love.graphics.rectangle("fill", x, y, barWidth * healthPercent, barHeight, 1, 1)

            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("line", x, y, barWidth, barHeight, 1, 1)

            love.graphics.setColor(1, 1, 1, 1)
            ::continue::
        end
    end
end