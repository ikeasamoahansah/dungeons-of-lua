function updateAll(dt)
    updateGame(dt)
end


function updateGame(dt)
    -- ONLY state 1 runs the world. Menu (0) and game over (2) freeze
    -- everything — physics, enemies, projectiles, camera all hold still, so
    -- returning to the menu is a true pause and nothing keeps simulating
    -- behind it.
    if gameState ~= 1 then return end -- stop everything in menu / game over

    world:update(dt)
    playerUpdate(dt)
    enemies:update(dt)
    updateProjectiles(dt)
    updatePlayerProjectiles(dt)
    cameraUpdate(dt)
    -- soundUpdate(dt)
end
