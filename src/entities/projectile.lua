projectiles = {}

-- HOMING SHOT SETTINGS ------------------------------------------------------------------------
-- Enemy projectiles spawned with homing = true lock onto the player and steer toward
-- them for the first HOMING_TIME seconds of their lifetime, then keep flying in a
-- straight line for the rest of it.
-- Tuning notes:
--   HOMING_TIME — how long the active chase lasts. Longer = scarier. Roughly half the
--                 projectile's lifetime feels fair.
--   HOMING_TURN — steering strength. Each frame the shot's heading is nudged
--                 HOMING_TURN * dt of the way toward the player, so LOW values curve
--                 gently (dodgeable by strafing) and HIGH values snap on target
--                 (effectively undodgeable). 4 is a reasonable middle ground given the
--                 player's 150 move speed.
-- Lock-break rule: the moment the player becomes untouchable — took a hit OR is
-- mid-dodge — any live homing lock is cancelled PERMANENTLY — not "paused until
-- the i-frames end". Pausing would make the shot re-acquire the instant the
-- grace runs out, which feels like cheating. With a permanent break, getting
-- hit and dodging are both legitimate escapes (one costs HP, one is free).
local HOMING_TIME = 1.5 -- seconds of active tracking after the shot spawns
local HOMING_TURN = 4   -- steering strength (fraction of the gap closed per second)

function spawnProjectile(x, y, tx, ty, speed, damage, owner, homing)
    local p = {}
    p.damage = damage or 1
    p.owner = owner or "enemy"
    p.dead = false
    p.lifetime = 3  -- seconds before auto-despawn

    -- Remember the launch speed so the homing update can re-apply velocity later;
    -- setLinearVelocity() at spawn is a one-time write, not a stored value.
    p.speed = speed

    -- Homing configuration.
    -- homing is opt-in per call site (8th argument) so callers choose whether a
    -- shot tracks: the mage pays for it with its 2s cooldown, while the boss's
    -- 3-shot cone at 500px/s stays dodgeable straight-fire.
    p.homing = homing or false
    if p.homing then
        p.homingTime = HOMING_TIME  -- countdown of the chase window
        p.turnRate   = HOMING_TURN  -- how hard the shot steers
    end

    -- Direction towards target
    local dx = tx - x
    local dy = ty - y
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then return end  -- guard against zero length

    -- normalized direction to fix box2D issue
    local ndx = dx / len
    local ndy = dy / len

    -- Spawn offset so projectile doesn't immediately collide with the enemy body
    -- Physics collider
    local spawnOffset = 10
    p.physics = world:newCircleCollider(
        x + ndx * spawnOffset,
        y + ndy * spawnOffset,
        3
    )
    p.physics:setFixedRotation(true)
    p.physics:setGravityScale(0)  -- no gravity pulling projectiles down
    p.physics:setCollisionClass("projectile")
    p.physics.parent = p
    
    -- Set velocity directly — this overwrites any inherited momentum
    -- so direction is always exactly toward the target regardless of
    -- which way the enemy is moving or facing
    p.physics:setLinearVelocity(ndx * speed, ndy * speed)

    p.dx = ndx
    p.dy = ndy

    table.insert(projectiles, p)
end

function updateProjectiles(dt)
    for i, p in ipairs(projectiles) do
        if not p.dead then
            p.lifetime = p.lifetime - dt

            -- Despawn after lifetime
            if p.lifetime <= 0 then
                p.dead = true
            end

            -------------------------------------------------------------------------------------
            -- HOMING / LOCK-ON
            -------------------------------------------------------------------------------------
            -- Rule 1: Lock break. The instant the player becomes untouchable —
            -- took a hit (invincibleTimer) OR is mid-dodge dash
            -- (dodgeInvincibleTimer) — this shot's homing is cancelled
            -- PERMANENTLY, not "paused until it ends". Pausing would make the
            -- shot re-acquire the instant the ghosting runs out, which feels
            -- like cheating. With a permanent break, both eating a hit and
            -- dodging through it count as escapes; the dodge is just the free way.
            if p.homing and (player.invincibleTimer > 0 or player.dodgeInvincibleTimer > 0) then
                p.homing = false
            end

            -- Rule 2: Steering. While the lock is live and the chase window hasn't
            -- run out, nudge the shot's heading toward the player.
            if p.homing and p.homingTime > 0 then
                p.homingTime = p.homingTime - dt

                local mx, my = p.physics:getPosition()
                local px, py = player.collider:getPosition()

                -- Unit vector from the projectile to the player right now
                local tox = px - mx
                local toy = py - my
                local toLen = math.sqrt(tox*tox + toy*toy)

                if toLen > 0 then
                    -- Proportional steering instead of angle math (no atan2 wraparound
                    -- headaches): blend the current heading with the direction to the
                    -- player, closing p.turnRate*dt of the gap this frame.
                    --
                    -- Per-frame blend ≈ 4 / 60 ≈ 0.066, so the orb visibly CURVES
                    -- after you instead of snapping — that curvature is exactly what
                    -- makes it dodgeable by lateral movement.
                    local blend = p.turnRate * dt
                    if blend > 1 then
                        blend = 1  -- clamp for huge dt (lag spikes): full snap, never overshoot
                    end

                    local hx = p.dx * (1 - blend) + (tox / toLen) * blend
                    local hy = p.dy * (1 - blend) + (toy / toLen) * blend
                    local hLen = math.sqrt(hx*hx + hy*hy)

                    -- Guard against a zero-length blend (current heading exactly
                    -- opposite the player on the same frame blend hits 1).
                    if hLen > 0.0001 then
                        p.dx = hx / hLen
                        p.dy = hy / hLen
                    end

                    -- Re-apply velocity along the (possibly steered) heading.
                    -- The projectile ignores gravity and can't rotate visually
                    -- (circle collider), so writing velocity directly each frame
                    -- is the cheapest correct way to steer it.
                    p.physics:setLinearVelocity(p.dx * p.speed, p.dy * p.speed)
                end
                -- If the player is gone/zero-dist, just keep last velocity —
                -- lifetime and wall collisions below still apply.
            end

            -- Check hit on player
            if p.physics:enter("player") then
                player:takeDamage(p.damage)
                p.dead = true
            end

            -- Check hit on wall
            if p.physics:enter("wall") then
                p.dead = true
            end
        end
    end

    -- Cleanup dead projectiles in reverse order
    for i = #projectiles, 1, -1 do
        if projectiles[i].dead then
            if projectiles[i].physics and projectiles[i].physics.body then
                projectiles[i].physics:destroy()
                projectiles[i].physics = nil
            end
            table.remove(projectiles, i)
        end
    end
end

function drawProjectiles()
    for i, p in ipairs(projectiles) do
        if not p.dead then
            local px, py = p.physics:getPosition()

            -- Outer glow
            love.graphics.setColor(1, 0.4, 0.1, 0.3)
            love.graphics.circle("fill", px, py, 7)

            -- Inner orb
            love.graphics.setColor(1, 0.6, 0.1, 1)
            love.graphics.circle("fill", px, py, 3)

            -- Lock-on tell: a pulsing red ring drawn ONLY while this shot is
            -- actively homing. Once the window expires or the lock breaks on
            -- i-frames, the ring vanishes and the player knows the shot has
            -- gone dumb — readable feedback either way.
            if p.homing and p.homingTime and p.homingTime > 0 then
                -- Oscillate 0..1 using the countdown lifetime as the phase
                local pulse = 0.5 + 0.5 * math.sin(p.lifetime * 12)
                love.graphics.setColor(1, 0.15, 0.15, 0.35 + 0.25 * pulse)
                love.graphics.circle("line", px, py, 9 + 1.5 * pulse)
            end

            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

-- Player projectiles: FIRE SPELLS (cast with X). Each cast homes onto the
-- nearest LIVE enemy for its flight window; if every enemy is gone mid-flight
-- the bolt just flies straight out. Treated as its own homing family with
-- tighter steering than enemy shots — the caster picked the target ground.
playerProjectiles = {}

-- FIRE SPELL SETTINGS ------------------------------------------------------------------------
local FIRE_HOMING_TIME = 2.0 -- seconds of tracking (of the 2.5s lifetime)
local FIRE_TURN        = 5   -- tighter than enemy homing (HOMING_TURN = 4): the bolt is
                             -- meant as a lock-on answer to dodgeable mage shots

function spawnPlayerProjectile(x, y, tx, ty, speed, damage)
    local p = {}
    p.damage  = damage or 1
    p.dead    = false
    p.lifetime = 2.5

    -- Fire bolt homing config: no fixed target at spawn — the nearest live
    -- enemy is re-picked EVERY frame during the homing window, so the bolt
    -- never chases a corpse and always prefers the closest threat.
    p.speed = speed
    p.homing = true
    p.homingTime = FIRE_HOMING_TIME
    p.turnRate = FIRE_TURN

    local dx = tx - x
    local dy = ty - y
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then return end

    local ndx = dx / len
    local ndy = dy / len

    -- Spawn offset so it doesnt collide with player body
    local offset = 12
    p.physics = world:newCircleCollider(
        x + ndx * offset,
        y + ndy * offset,
        8
    )
    p.physics:setFixedRotation(true)
    p.physics:setGravityScale(0)
    p.physics:setCollisionClass('playerProjectile')
    p.physics.parent = p
    p.physics:setLinearVelocity(ndx * speed, ndy * speed)

    p.dx = ndx
    p.dy = ndy

    -- Trail particles
    p.trail = {}

    table.insert(playerProjectiles, p)
end

function updatePlayerProjectiles(dt)
    for i, p in ipairs(playerProjectiles) do
        if not p.dead and p.physics then
            p.lifetime = p.lifetime - dt
            if p.lifetime <= 0 then
                p.dead = true
            end

            ------------------------------------------------------------------
            -- FIRE BOLT HOMING: steer toward the nearest LIVE enemy.
            -- Symmetric with the enemy homing in updateProjectiles: proportional
            -- steering capped per frame; the lock window is shorter than the
            -- bolt's life so the tail end is a straight shot.
            ------------------------------------------------------------------
            if p.homing and p.homingTime > 0 then
                p.homingTime = p.homingTime - dt

                -- Target re-selection every frame: nearest living enemy wins;
                -- corpses and despawned physics are skipped. No enemy left =
                -- no steering this frame (bolt coasts straight).
                local mx, my = p.physics:getPosition()
                local nearest, nearestDistSq = nil, math.huge

                for _, e in ipairs(enemies) do
                    if not e.dead and e.physics then
                        local ex, ey = e.physics:getPosition()
                        local dsq = (ex - mx) * (ex - mx) + (ey - my) * (ey - my)
                        if dsq < nearestDistSq then
                            nearestDistSq = dsq
                            nearest = {x = ex, y = ey}
                        end
                    end
                end

                if nearest then
                    local tox = nearest.x - mx
                    local toy = nearest.y - my
                    local toLen = math.sqrt(tox*tox + toy*toy)

                    if toLen > 0 then
                        -- Same blend steering as enemy bolts (see updateProjectiles):
                        -- closes turnRate*dt of the gap toward the target per frame,
                        -- clamped to 1 for huge dt so it can't overshoot.
                        local blend = p.turnRate * dt
                        if blend > 1 then blend = 1 end

                        local hx = p.dx * (1 - blend) + (tox / toLen) * blend
                        local hy = p.dy * (1 - blend) + (toy / toLen) * blend
                        local hLen = math.sqrt(hx*hx + hy*hy)

                        if hLen > 0.0001 then
                            p.dx = hx / hLen
                            p.dy = hy / hLen
                        end

                        p.physics:setLinearVelocity(p.dx * p.speed, p.dy * p.speed)
                    end
                end
            end

            -- Store trail positions for draw
            local px, py = p.physics:getPosition()
            table.insert(p.trail, 1, {x = px, y = py, life = 0.1})
            if #p.trail > 6 then
                table.remove(p.trail)
            end
            for _, pt in ipairs(p.trail) do
                pt.life = pt.life - dt
            end

            -- Hit enemy
            if p.physics:enter('enemy') then
                local data = p.physics:getEnterCollisionData('enemy')
                if data and data.collider and data.collider.parent then
                    enemies:takeDamage(data.collider.parent, p.damage)
                end
                p.dead = true
            end

            -- Hit wall
            if p.physics:enter('wall') then
                p.dead = true
            end
        end
    end

    -- Cleanup
    for i = #playerProjectiles, 1, -1 do
        if playerProjectiles[i].dead then
            if playerProjectiles[i].physics and
               playerProjectiles[i].physics.body then
                playerProjectiles[i].physics:destroy()
                playerProjectiles[i].physics = nil
            end
            table.remove(playerProjectiles, i)
        end
    end
end

function drawPlayerProjectiles()
    for i, p in ipairs(playerProjectiles) do
        if not p.dead and p.physics then
            local px, py = p.physics:getPosition()

            -- Draw trail — ember fade
            for j, pt in ipairs(p.trail) do
                local alpha = (pt.life / 0.1) * 0.5 * (1 - j / #p.trail)
                local size  = 6 * (1 - j / #p.trail)
                love.graphics.setColor(1, 0.45, 0.15, alpha)
                love.graphics.circle("fill", pt.x, pt.y, size)
            end

            -- Outer glow — firey haze
            love.graphics.setColor(1, 0.35, 0.1, 0.25)
            love.graphics.circle("fill", px, py, 18)

            -- Mid ring — hot bubble
            love.graphics.setColor(1, 0.55, 0.2, 0.7)
            love.graphics.circle("fill", px, py, 12)

            -- Bright core — near-white flame center
            love.graphics.setColor(1, 0.9, 0.6, 1)
            love.graphics.circle("fill", px, py, 6)

            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end