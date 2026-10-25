function love.load()
    require('src/startup/gameStart')
    gameStart()
    loadMap("dungeon")
end

function love.update(dt)
    -- Menu state: the world is frozen; only menu bookkeeping ticks.
    if gameState == 0 then
        menu:update(dt)
        return
    end
    updateAll(dt)
end

function love.draw()
    -- MENU: full screen menu, world not drawn (it's frozen in the background
    -- and for a first-ever boot it isn't worth showing — the menu paints over it).
    if gameState == 0 then
        menu:draw()
        return
    end

    if shaders and shaders.vignette then
        shaders.vignette:send("screen_size", {love.graphics.getDimensions()})
        love.graphics.setShader(shaders.vignette)
    end

    cam:attach()
    drawCamera()
    cam:detach()

    love.graphics.setShader()

    -- Draw HUD
    drawHUD()

    if gameState == 2 then
        drawGameOver()
    end
end

function love.keypressed(key)
    -- MENU PRIORITY: while in the menu every keypress is menu input; the
    -- gameplay handlers below never run (gameState ~= 1 guards them anyway).
    if gameState == 0 then
        menu:keypressed(key)
        return
    end

    -- In-game Esc = pause out to the menu (world freezes, Resume continues
    -- the run). Esc from the game-over screen quits outright.
    if key == "escape" then
        if gameState == 1 then
            gameState = 0
            menu:enter()
        else
            love.event.quit()
        end
        return
    end

    if key == "z" then
        sounds.dungeon:stop()
    end

    -- Gameplay actions go through keybinds — what "x"/"space"/"c"/"e" used to
    -- hardcode is now whatever the options screen says.
    if gameState ~= 2 then
        if keybinds:keyMatches("attack", key) then
            player:startAttack()
        end
        if keybinds:keyMatches("fire", key) then
            player:startThrow()
        end
        if keybinds:keyMatches("dodge", key) then
            player:startDodge()
        end
        if keybinds:keyMatches("shield", key) then
            player:toggleShield()
        end
    end

    -- R only restarts from the game-over screen
    if key == "r" and gameState == 2 then
        love.event.quit("restart")
    end
end
