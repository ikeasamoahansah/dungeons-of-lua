player = {}
player.x = 0
player.y = 0
player.speed = 150
player.sprite_sheet = love.graphics.newImage('assets/sprites/Fumiko.png')

-- animations.attack.up = anim8.newAnimation(player.grid('1-5', 5), 0.2)
-- animations.attack.down = anim8.newAnimation(player.grid('1-5', 7), 0.2)
-- animations.attack.left = anim8.newAnimation(player.grid('1-5', 8), 0.2)
-- animations.attack.right = anim8.newAnimation(player.grid('1-5', 6), 0.2)


function playerUpdate(dt)
    local keyPressed = false
    -- collider
    local vx = 0
    local vy = 0

    if love.keyboard.isDown("right") then
        vx = player.speed
        player.anim = animations.right
        keyPressed = true
    elseif love.keyboard.isDown("left") then
        vx = player.speed * -1
        player.anim = animations.left
        keyPressed = true
    elseif love.keyboard.isDown("down") then
        vy = player.speed
        player.anim = animations.down
        keyPressed = true
    elseif love.keyboard.isDown("up") then
        vy = player.speed * -1
        player.anim = animations.up
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
    player.anim:draw(player.sprite_sheet, px, py, nil, 1.5, nil, 12, 16)
end

