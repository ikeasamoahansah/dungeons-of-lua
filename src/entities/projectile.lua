projectiles = {}

function spawnProjectile(x, y, tx, ty, speed, damage, owner)
    local p = {}
    p.damage = damage or 1
    p.owner = owner or "enemy"
    p.dead = false
    p.lifetime = 3  -- seconds before auto-despawn

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

            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

-- Player projectiles stored separately
playerProjectiles = {}

function spawnPlayerProjectile(x, y, tx, ty, speed, damage)
    local p = {}
    p.damage  = damage or 1
    p.dead    = false
    p.lifetime = 2.5

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

            -- Draw trail
            for j, pt in ipairs(p.trail) do
                local alpha = (pt.life / 0.1) * 0.4 * (1 - j / #p.trail)
                local size  = 7 * (1 - j / #p.trail)
                love.graphics.setColor(0.3, 0.6, 1, alpha)
                love.graphics.circle("fill", pt.x, pt.y, size)
            end

            -- Outer glow
            love.graphics.setColor(0.2, 0.5, 1, 0.25)
            love.graphics.circle("fill", px, py, 18)

            -- Mid ring
            love.graphics.setColor(0.4, 0.7, 1, 0.6)
            love.graphics.circle("fill", px, py, 12)

            -- Bright core
            love.graphics.setColor(0.8, 0.95, 1, 1)
            love.graphics.circle("fill", px, py, 6)

            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end