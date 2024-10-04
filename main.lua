function love.load()
    anim8 = require('libraries.anim8')
    sti = require('libraries.sti')
    camera = require('libraries.camera')
    wf = require('libraries.windfield')

    gameMap = sti('assets/maps/dungeon.lua')
    cam = camera()
    world = wf.newWorld(0, 0)

    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("SEGETES - The Game")
    love.window.setMode(400, 300)
--     love.window.setFullscreen(true)

    player = {}
    player.collider = world:newBSGRectangleCollider(960, 1890, 30, 50, 10)
    player.collider:setFixedRotation(true)
    player.x = 0
    player.y = 0
    player.speed = 150
    player.sprite_sheet = love.graphics.newImage('assets/sprites/Fumiko.png')
    player.grid = anim8.newGrid(24, 32, player.sprite_sheet:getWidth(), player.sprite_sheet:getHeight())

    player.animations = {}
    player.animations.up = anim8.newAnimation(player.grid('1-3', 1), 0.2)
    player.animations.down = anim8.newAnimation(player.grid('1-3', 3), 0.2)
    player.animations.left = anim8.newAnimation(player.grid('1-3', 4), 0.2)
    player.animations.right = anim8.newAnimation(player.grid('1-3', 2), 0.2)

    -- player.animations.attack.up = anim8.newAnimation(player.grid('1-5', 5), 0.2)
    -- player.animations.attack.down = anim8.newAnimation(player.grid('1-5', 7), 0.2)
    -- player.animations.attack.left = anim8.newAnimation(player.grid('1-5', 8), 0.2)
    -- player.animations.attack.right = anim8.newAnimation(player.grid('1-5', 6), 0.2)

    player.anim = player.animations.up

    -- background = love.graphics.newImage('assets/maps/grass.png')

    -- TODO: 
    -- Add enemies
    -- Configure shaders
    -- Make enemies attack player with readius

    walls = {}
    if gameMap.layers["walls"] then
        for i, obj in pairs(gameMap.layers["walls"].objects) do
            local wall = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            wall:setType("static")
            table.insert(walls, wall)
        end
    end

    sounds = {}
    sounds.dungeon = love.audio.newSource("assets/sounds/dungeon.mp3", "stream")
    sounds.dungeon:setLooping(true)
    sounds.dungeon:play()
end

function love.update(dt)
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
    if love.keyboard.isDown("escape") then
       love.event.quit()
    end

    player.collider:setLinearVelocity(vx, vy)

    -- if love.keyboard.isDown("space") then
    --     player.anim = player.animations.attack.down
    -- end

    if keyPressed == false then
        player.anim:gotoFrame(2)
    end

    world:update(dt)
    player.x = player.collider:getX()
    player.y = player.collider:getY()

    player.anim:update(dt)

    cam:lookAt(player.x, player.y)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight
    if cam.x < w/2 then
        cam.x = w/2
    end
    if cam.y < h/2 then
        cam.y = h/2
    end
    -- Right border
    if cam.x > (mapW - w/2) then
        cam.x = (mapW - w/2)
    end
    -- Bottom border
    if cam.y > (mapH - h/2) then
        cam.y = (mapH - h/2)
    end

    -- sounds

    if love.keyboard.isDown("z") then
        sounds.dungeon:stop()
    end
end

function love.draw()
    cam:attach()
        gameMap:drawLayer(gameMap.layers["Ground"])
        gameMap:drawLayer(gameMap.layers["Divisions"])
        player.anim:draw(player.sprite_sheet, player.x, player.y, nil, 1.5, nil, 12, 16)
    cam:detach()
end
