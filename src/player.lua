-- restructuring needed
player = {}
player.x = 0
player.y = 0
player.speed = 150
player.grid = anim8.newGrid(24, 32, sprites.playerSheet:getWidth(), sprites.playerSheet:getHeight())
player.collider = world:newBSGRectangleCollider(960, 1890, 30, 50, 10)
player.collider:setFixedRotation(true)
player.collider:setCollisionClass("player")

player.health = 10
player.maxHealth = 10
player.invincibleTimer = 0
player.hitFlashTimer = 0

player.animations = {}
player.animations.up = anim8.newAnimation(player.grid('1-3', 1), 0.2)
player.animations.down = anim8.newAnimation(player.grid('1-3', 3), 0.2)
player.animations.left = anim8.newAnimation(player.grid('1-3', 4), 0.2)
player.animations.right = anim8.newAnimation(player.grid('1-3', 2), 0.2)


-- Each attack is 5 frames, plays once then returns to walk
player.animations.attackUp    = anim8.newAnimation(player.grid('1-5', 5), 0.1, 'pauseAtEnd')
player.animations.attackDown  = anim8.newAnimation(player.grid('1-5', 7), 0.1, 'pauseAtEnd')
player.animations.attackLeft  = anim8.newAnimation(player.grid('1-5', 8), 0.1, 'pauseAtEnd')
player.animations.attackRight = anim8.newAnimation(player.grid('1-5', 6), 0.1, 'pauseAtEnd')

player.anim = player.animations.up
player.lastDirection = "up"

-- Add these with the other animations
player.animations.throwUp    = anim8.newAnimation(player.grid(16, 5), 0.15, 'pauseAtEnd')
player.animations.throwDown  = anim8.newAnimation(player.grid(16, 7), 0.15, 'pauseAtEnd')
player.animations.throwLeft  = anim8.newAnimation(player.grid(16, 8), 0.15, 'pauseAtEnd')
player.animations.throwRight = anim8.newAnimation(player.grid(16, 6), 0.15, 'pauseAtEnd')

-- Throw state
player.throwCooldown    = 0
player.throwCooldownMax = 0.4
player.throwDamage      = 1
player.throwSpeed       = 200

-- Attack state
player.attacking = false
player.attackTimer = 0
player.attackDuration = 0.5   -- how long the full attack lasts
player.attackCooldown = 0     -- prevents spam, ticks down
player.attackCooldownMax = 0.4
player.attackRange = 35       -- melee hit range in pixels
player.attackDamage = 1

function player:takeDamage(amount)
    if self.invincibleTimer > 0 then return end
    self.health = self.health - amount
    self.invincibleTimer = 1
    self.hitFlashTimer = 0.1 -- short white flash on hit
    if self.health <= 0 then
        gameState = 2 -- Set a new game state for "game over"

        -- Freeze all projectiles immediately
        for _, p in ipairs(projectiles) do
            if p.physics then
                p.physics:setLinearVelocity(0, 0)
            end
        end

        -- Freeze all enemies immediately
        for _, e in ipairs(enemies) do
            if e.physics then
                e.physics:setLinearVelocity(0, 0)
            end
        end
    end
end

function player:startAttack()
    if self.attackCooldown > 0 then return end
    self.attacking = true
    self.attackTimer = self.attackDuration
    self.attackCooldown = self.attackCooldownMax

    -- Switch to attack animation for current direction
    local dir = self.lastDirection
    self.anim = self.animations["attack" .. dir:sub(1,1):upper() .. dir:sub(2)]
    self.anim:gotoFrame(1)
    self.anim:resume()

    -- Hit enemies in front of player immediately on swing
    self:doMeleeHit()
end

function player:doMeleeHit()
    local px, py = self.collider:getPosition()

    -- Offset the hit box in the facing direction
    local offsets = {
        up    = { 0, -self.attackRange},
        down  = { 0,  self.attackRange},
        left  = {-self.attackRange, 0},
        right = { self.attackRange, 0},
    }

    local off = offsets[self.lastDirection]
    local hitX = px + off[1]
    local hitY = py + off[2]

    -- Query a circle in front of the player for enemies
    local hits = world:queryCircleArea(hitX, hitY, self.attackRange * 0.8, {'enemy'})
    for _, collider in ipairs(hits) do
        local enemy = collider.parent
        if enemy and not enemy.dead then
            enemies:takeDamage(enemy, self.attackDamage)
        end
    end
end

function player:startThrow()
    if player.throwCooldown > 0 then return end

    player.throwCooldown = player.throwCooldownMax
    player.attacking = true
    player.attackTimer = player.attackDuration

    -- Switch to throw animation for current direction
    local dir = player.lastDirection
    local animKey = "throw" .. dir:sub(1,1):upper() .. dir:sub(2)
    player.anim = player.animations[animKey]
    player.anim:gotoFrame(1)
    player.anim:resume()

    -- Spawn projectile in facing direction
    local px, py = player.collider:getPosition()

    local dirOffsets = {
        up    = { 0, -1},
        down  = { 0,  1},
        left  = {-1,  0},
        right = { 1,  0},
    }

    local d = dirOffsets[player.lastDirection]
    local tx = px + d[1] * 100
    local ty = py + d[2] * 100

    spawnPlayerProjectile(px, py, tx, ty, player.throwSpeed, player.throwDamage)
end

-- Tick throw cooldown in playerUpdate, add inside playerUpdate:
-- if player.throwCooldown > 0 then
--     player.throwCooldown = player.throwCooldown - dt
-- end

function playerUpdate(dt)
    -- if gameState == 2 then return end -- guard checks
    if player.invincibleTimer > 0 then
        player.invincibleTimer = player.invincibleTimer - dt
    end

    if player.hitFlashTimer > 0 then
        player.hitFlashTimer = player.hitFlashTimer - dt
    end

    if player.throwCooldown > 0 then
        player.throwCooldown = player.throwCooldown - dt
    end

    if player.attackCooldown > 0 then
        player.attackCooldown = player.attackCooldown - dt
    end
    if player.attackTimer > 0 then
        player.attackTimer = player.attackTimer - dt
        if player.attackTimer <= 0 then
            player.attacking = false  -- attack window over
            -- Return to the movement animation set after one-shot attack/throw anims.
            player.anim = player.animations[player.lastDirection]
        end
    end

    -- collider
    local vx = 0
    local vy = 0
    local moved = false

    -- Movement — blocked during attack so player commits to the swing
    if not player.attacking then
        if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
            vx = player.speed
            player.lastDirection = "right"
            player.anim = player.animations.right
            moved = true
        elseif love.keyboard.isDown("left") or love.keyboard.isDown("a") then
            vx = -player.speed
            player.lastDirection = "left"
            player.anim = player.animations.left
            moved = true
        elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
            vy = player.speed
            player.lastDirection = "down"
            player.anim = player.animations.down
            moved = true
        elseif love.keyboard.isDown("up") or love.keyboard.isDown("w") then
            vy = -player.speed
            player.lastDirection = "up"
            player.anim = player.animations.up
            moved = true
        end
    end

    player.collider:setLinearVelocity(vx, vy)

    -- Idle frame when not moving and not attacking
    if not moved and not player.attacking then
        -- Ensure idle frame is picked from looping walk anims (they all have frame 2).
        player.anim = player.animations[player.lastDirection]
        player.anim:gotoFrame(2)
    end

    player.anim:update(dt)
end

function drawPlayer()
    local px, py = player.x, player.y

    if player.hitFlashTimer > 0 then
        -- Bright white flash on hit
        love.graphics.setColor(1, 1, 1, 1)
        player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
        love.graphics.setColor(1, 1, 1, 1)
        -- Draw white overlay on top
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 0.8)
        player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
        love.graphics.setBlendMode("alpha")
    elseif player.invincibleTimer > 0 then
        local flash = math.sin(player.invincibleTimer * 20) > 0
        love.graphics.setColor(flash and {1, 0.3, 0.3, 1} or {1, 1, 1, 0.2})
        player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
    else
        love.graphics.setColor(1, 1, 1, 1)
        player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
    end

    love.graphics.setColor(1, 1, 1, 1)
end
