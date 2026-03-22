function updateAll(dt)
    updateGame(dt)
end


function updateGame(dt)
    if gameState == 2 then return end -- stop everything on game over
    
    world:update(dt)
    playerUpdate(dt)
    enemies:update(dt)
    updateProjectiles(dt)
    cameraUpdate(dt)
    -- soundUpdate(dt)
end
