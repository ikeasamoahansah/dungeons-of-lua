function updateAll(dt)
    updateGame(dt)
end


-- VICTORY (game state 3) ------------------------------------------------------------------------
-- Triggered the moment the boss dies (see boss.lua's enemy:die -> startVictory).
-- The world doesn't cut to the cleared screen instantly: a short 2s grace
-- period lets the death blink play out while enemies and shots are effectively
-- pacified (their update loops are skipped below, velocities were zeroed, and
-- in-flight enemy bolts stand still instead of clipping the player mid-victory).
-- When the timer runs out, gameState becomes 3 and drawVictory takes over.
function startVictory()
    if gameState ~= 1 then return end

    victoryTimer = 2

    -- Pacify in-flight enemy shots immediately: kill homing locks and stop
    -- them dead so the player can't be killed by a bolt during the celebration.
    for _, p in ipairs(projectiles) do
        p.homing = false
        if p.physics then
            p.physics:setLinearVelocity(0, 0)
        end
    end

    -- Stand down every living enemy (they freeze in place during the grace
    -- period — their update is skipped in updateGame below).
    for _, e in ipairs(enemies) do
        if e.physics and not e.dead then
            e.state = 1
            e.physics:setLinearVelocity(0, 0)
        end
    end
end


function updateGame(dt)
    -- ONLY state 1 runs the world. Menu (0), game over (2) and victory (3)
    -- freeze everything — physics, enemies, projectiles, camera all hold
    -- still, so returning to the menu is a true pause and nothing keeps
    -- simulating behind it.
    if gameState ~= 1 then return end

    world:update(dt)
    playerUpdate(dt)

    -- Victory sequence: slightly unusual order — after the boss dies the
    -- enemies/projectiles stop being driven at all for the grace period, but
    -- the world + player keep simulating so the moment still feels alive.
    if victoryTimer > 0 then
        victoryTimer = victoryTimer - dt
        if victoryTimer <= 0 then
            gameState = 3 -- cleared!
            return
        end
    else
        enemies:update(dt)
        updateProjectiles(dt)
        updatePlayerProjectiles(dt)
    end

    cameraUpdate(dt)
    -- soundUpdate(dt)
end
