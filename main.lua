function love.load()
    anim8 = require('libraries.anim8')
    sti = require('libraries.sti')

    gameMap = sti('assets/maps/second_map_re.lua')

    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("SEGETES - The Game")

    player = {}
    player.x = 0
    player.y = 0
    player.speed = 2
    player.sprite_sheet = love.graphics.newImage('assets/sprites/fighter.png')
    player.grid = anim8.newGrid(24, 32, player.sprite_sheet:getWidth(), player.sprite_sheet:getHeight())

    player.animations = {}
    player.animations.up = anim8.newAnimation(player.grid('1-3', 1), 0.2)
    player.animations.down = anim8.newAnimation(player.grid('1-3', 3), 0.2)
    player.animations.left = anim8.newAnimation(player.grid('1-3', 4), 0.2)
    player.animations.right = anim8.newAnimation(player.grid('1-3', 2), 0.2)

    player.anim = player.animations.down

    background = love.graphics.newImage('assets/maps/grass.png')
end

function love.update(dt)
    local keyPressed = false

    if love.keyboard.isDown("right") then
        player.x = player.x + player.speed
        player.anim = player.animations.right
        keyPressed = true
    elseif love.keyboard.isDown("left") then
        player.x = player.x - player.speed
        player.anim = player.animations.left
        keyPressed = true
    elseif love.keyboard.isDown("down") then
        player.y = player.y + player.speed
        player.anim = player.animations.down
        keyPressed = true
    elseif love.keyboard.isDown("up") then
        player.y = player.y - player.speed
        player.anim = player.animations.up
        keyPressed = true
    end
    if love.keyboard.isDown("escape") then
       love.event.quit()
    end

    if keyPressed == false then
        player.anim:gotoFrame(2)
    end

    player.animations.up:update(dt)
    player.animations.down:update(dt)
    player.animations.left:update(dt)
    player.animations.right:update(dt)

end

function love.draw()
    gameMap:draw()
    player.anim:draw(player.sprite_sheet, player.x, player.y, nil, 1)
end