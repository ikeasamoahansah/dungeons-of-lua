function gameStart()
    
    initGlobals()
    
    vector = require "libraries/hump/vector"

    anim8 = require('libraries/anim8')
    sti = require('libraries/sti')
    wf = require('libraries/windfield')


    world = wf.newWorld(0, 0)

    love.graphics.setDefaultFilter("nearest", "nearest")

    -- TODO:
    -- Add enemies
    -- Configure shaders
    -- Make enemies attack player within radius

    require('src/startup/require')
    requireAll()
    
end

function initGlobals()
    data = {}

    -- game state
    -- 0: main menu
    -- 1: gameplay
    
    gameState = 0
    globalStun = 0
end
