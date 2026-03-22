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