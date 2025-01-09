player = {}
player.x = 0
player.y = 0
player.speed = 150
player.grid = anim8.newGrid(24, 32, sprites.playerSheet:getWidth(), sprites.playerSheet:getHeight())
player.collider = world:newBSGRectangleCollider(960, 1890, 30, 50, 10)
player.collider:setFixedRotation(true)

player.animations = {}
player.animations.up = anim8.newAnimation(player.grid('1-3', 1), 0.2)
player.animations.down = anim8.newAnimation(player.grid('1-3', 3), 0.2)
player.animations.left = anim8.newAnimation(player.grid('1-3', 4), 0.2)
player.animations.right = anim8.newAnimation(player.grid('1-3', 2), 0.2)

player.anim = player.animations.up
-- player.animations.attack.up = anim8.newAnimation(player.grid('1-5', 5), 0.2)
-- player.animations.attack.down = anim8.newAnimation(player.grid('1-5', 7), 0.2)
-- player.animations.attack.left = anim8.newAnimation(player.grid('1-5', 8), 0.2)
-- player.animations.attack.right = anim8.newAnimation(player.grid('1-5', 6), 0.2)


function playerUpdate(dt)
    local keyPressed = false
    -- collider
    local vx = 0
    local vy = 0

    if love.keyboard.isDown("right") then
        vx = player.speed
        player.anim = player.animations.right
        keyPressed = true
    elseif love.keyboard.isDown("left") then
        vx = player.speed * -1
        player.anim = player.animations.left
        keyPressed = true
    elseif love.keyboard.isDown("down") then
        vy = player.speed
        player.anim = player.animations.down
        keyPressed = true
    elseif love.keyboard.isDown("up") then
        vy = player.speed * -1
        player.anim = player.animations.up
        keyPressed = true
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
