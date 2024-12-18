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

    require('player')
    player.grid = anim8.newGrid(24, 32, player.sprite_sheet:getWidth(), player.sprite_sheet:getHeight())
    player.collider = world:newBSGRectangleCollider(960, 1890, 30, 50, 10)
    player.collider:setFixedRotation(true)

    animations = {}
    animations.up = anim8.newAnimation(player.grid('1-3', 1), 0.2)
    animations.down = anim8.newAnimation(player.grid('1-3', 3), 0.2)
    animations.left = anim8.newAnimation(player.grid('1-3', 4), 0.2)
    animations.right = anim8.newAnimation(player.grid('1-3', 2), 0.2)

    player.anim = animations.up

    -- background = love.graphics.newImage('assets/maps/grass.png')

    -- TODO:
    -- Add enemies
    -- Configure shaders
    -- Make enemies attack player within radius

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
    world:update(dt)
    playerUpdate(dt)
    if love.keyboard.isDown("escape") then
        love.event.quit()
    end

    player.x = player.collider:getX()
    player.y = player.collider:getY()


    cam:lookAt(player.x, player.y)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight
    if cam.x < w / 2 then
        cam.x = w / 2
    end
    if cam.y < h / 2 then
        cam.y = h / 2
    end
    -- Right border
    if cam.x > (mapW - w / 2) then
        cam.x = (mapW - w / 2)
    end
    -- Bottom border
    if cam.y > (mapH - h / 2) then
        cam.y = (mapH - h / 2)
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
    drawPlayer()
    cam:detach()
end
