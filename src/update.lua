function updateAll(dt)
    updateGame(dt)
end


function updateGame(dt)
    world:update(dt)
    playerUpdate(dt)
    enemies:update(dt)
    updateProjectiles(dt)
    cameraUpdate(dt)
    -- soundUpdate(dt)
end
