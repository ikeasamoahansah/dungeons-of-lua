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
    elseif gameState == 3 then
        drawVictory()
    elseif gameState == 4 then
        drawQuitScreen()
    end
end

function love.keypressed(key)
    -- QUIT SCREEN (web build): any key returns to the menu — the run stays
    -- paused behind it, so "Resume" picks the dungeon back up. The dungeon
    -- music resumes with it (quitGame stopped it on the way out).
    if gameState == 4 then
        gameState = 0
        menu:enter()
        if sounds and sounds.dungeon then
            sounds.dungeon:play()
        end
        return
    end

    -- MENU PRIORITY: while in the menu every keypress is menu input; the
    -- gameplay handlers below never run (gameState ~= 1 guards them anyway).
    if gameState == 0 then
        menu:keypressed(key)
        return
    end

    -- In-game Esc = pause out to the menu (world freezes, Resume continues
    -- the run). Esc anywhere else = quit — a real quit on desktop, the
    -- farewell screen in the browser (quitGame).
    if key == "escape" then
        if gameState == 1 then
            gameState = 0
            menu:enter()
        else
            quitGame()
        end
        return
    end

    if key == "z" then
        sounds.dungeon:stop()
    end

    -- Gameplay actions go through keybinds — what "x"/"space"/"c"/"e" used to
    -- hardcode is now whatever the options screen says. (Only live in state 1,
    -- so the game-over / cleared screens don't cast spells)
    if gameState == 1 then
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

    -- R restarts from the game-over OR cleared screens — including during the
    -- victory grace period right after the boss dies, when the cleared screen
    -- hasn't come up yet (gameState is still 1 while the world winds down).
    -- Uses the in-game restart (restartGame) because love.event.quit("restart")
    -- can't relaunch the runtime in the browser build.
    if key == "r" and (gameState == 2 or gameState == 3
                       or (gameState == 1 and victoryTimer > 0)) then
        restartGame()
    end
end
