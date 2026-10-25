function gameStart()
    
    initGlobals()
    
    vector = require "libraries/hump/vector"

    anim8 = require('libraries/anim8')
    sti = require('libraries/sti')
    wf = require('libraries/windfield')


    world = wf.newWorld(0, 0)

    world:addCollisionClass('player')
    world:addCollisionClass('enemy')
    world:addCollisionClass('wall')
    world:addCollisionClass('projectile', {
        ignores = {'enemy', 'projectile'}  -- projectiles dont hit each other or enemies
    })
    world:addCollisionClass('playerProjectile', {
        ignores = {'player', 'playerProjectile'}  -- phases through player and other player shots
    })

    love.graphics.setDefaultFilter("nearest", "nearest")

    require('src/startup/require')
    requireAll()

    -- keybindings: load from (or create) the settings file, and put the menu
    -- into its pristine boot state, before the very first frame runs.
    keybinds:init()
    menu:enter()
end

function initGlobals()
    data = {}

    -- game state
    -- 0: main menu
    -- 1: gameplay
    -- 2: Game Over!
    
    gameState = 0
    globalStun = 0
end
