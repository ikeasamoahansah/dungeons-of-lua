-- restructuring needed
player = {}
player.x = 0
player.y = 0
player.speed = 150
player.grid = anim8.newGrid(24, 32, sprites.playerSheet:getWidth(), sprites.playerSheet:getHeight())
player.collider = world:newBSGRectangleCollider(960, 1890, 30, 50, 10)
player.collider:setFixedRotation(true)

player.health = 10
player.maxHealth = 10
player.invincibleTimer = 0

player.animations = {}
player.animations.up = anim8.newAnimation(player.grid('1-3', 1), 0.2)
player.animations.down = anim8.newAnimation(player.grid('1-3', 3), 0.2)
player.animations.left = anim8.newAnimation(player.grid('1-3', 4), 0.2)
player.animations.right = anim8.newAnimation(player.grid('1-3', 2), 0.2)

player.anim = player.animations.up

player.animations.swordUp = anim8.newAnimation(player.grid('1-5', 5), 0.2)
player.animations.swordDown = anim8.newAnimation(player.grid('1-5', 7), 0.2)
player.animations.swordLeft = anim8.newAnimation(player.grid('1-5', 8), 0.2)
player.animations.swordRight = anim8.newAnimation(player.grid('1-5', 6), 0.2)

function player:takeDamage(amount)
    if self.invincibleTimer > 0 then return end
    self.health = self.health - amount
    self.invincibleTimer = 1
    print("Player took damage! Health: " .. self.health)
    if self.health <= 0 then
        print("Player died!")
        -- TODO: specific death logic
        gameState = 2 -- Set a new game state for "game over"
        print("Game Over!")
    end
end

function playerUpdate(dt)
    if player.invincibleTimer > 0 then
        player.invincibleTimer = player.invincibleTimer - dt
    end

    local keyPressed = false
    -- collider
    local vx = 0
    local vy = 0

    -- Attack animations
    local isAttacking = love.keyboard.isDown("space") -- You can change this key as needed

    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        vx = player.speed
        if isAttacking then
            player.anim = player.swordRight
        else
            player.anim = player.animations.right
        end
        keyPressed = true
    elseif love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        vx = player.speed * -1
        if isAttacking then
            player.anim = player.swordLeft
        else
            player.anim = player.animations.left
        end
        keyPressed = true
    elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        vy = player.speed
        if isAttacking then
            player.anim = player.swordDown
        else
            player.anim = player.animations.down
        end
        keyPressed = true
    elseif love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        vy = player.speed * -1
        if isAttacking then
            player.anim = player.swordUp
        else
            player.anim = player.animations.up
        end
        keyPressed = true
    else
        -- If player is just attacking without moving, update animation to last faced direction
        if isAttacking then
            -- Assuming last direction is preserved in self.lastDirection
            local lastDir = player.lastDirection or "down"
            player.anim = player.animations.sword[lastDir]
        end
    end

    -- Store last direction for attack-only
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        player.lastDirection = "right"
    elseif love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        player.lastDirection = "left"
    elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        player.lastDirection = "down"
    elseif love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        player.lastDirection = "up"
    end

    player.collider:setLinearVelocity(vx, vy)


    if keyPressed == false then
        player.anim:gotoFrame(2)
    end
    player.anim:update(dt)
end

function drawPlayer()
    local px, py = player.x, player.y
    player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
end
