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

-- QUIT (browser-aware) ---------------------------------------------------------------------------
-- love.event.quit() closes the desktop process, but a browser page can't be
-- closed from inside it — on the web build that made both the menu's Exit item
-- and Esc do nothing at all. On the web, quitting instead shows a polite
-- "thanks for playing" screen (game state 4) the player can leave by pressing
-- any key; desktop still exits for real. Identified via getOS, which love.js
-- reports as "Web".
function quitGame()
    if love.system.getOS() == "Web" then
        -- Also stop the looping dungeon track: part of what makes the
        -- farewell screen read as "the game has ended".
        if sounds and sounds.dungeon then
            sounds.dungeon:stop()
        end
        gameState = 4
    else
        love.event.quit()
    end
end

-- RESTART (in-game fresh run) --------------------------------------------------------------------
-- love.event.quit("restart") tears down the whole Lua state and re-launches the
-- runtime — fine on desktop, but it CANNOT work inside the browser build (love.js
-- can't relaunch its runtime), so pressing R on the game-over / cleared screens
-- did nothing there. restartGame() rebuilds the run entirely on the Lua side:
-- clearing the require cache makes every src/libraries module re-run its
-- top-level init (collider creation, spawn/entity tables, camera...) against a
-- brand new physics world, so this is a true fresh dungeon, not a soft reset.
function restartGame()
    -- Stop the old dungeon music first: re-requiring sound.lua would otherwise
    -- start a second loop on top of the previous one.
    if sounds and sounds.dungeon then
        sounds.dungeon:stop()
    end

    for k, _ in pairs(package.loaded) do
        if k:sub(1, 3) == "src" or k:sub(1, 9) == "libraries" then
            package.loaded[k] = nil
        end
    end

    -- gameStart() re-inits everything (world, resources, globals, menu); the
    -- dungeon map is loaded after, like love.load does on first boot.
    gameStart()
    loadMap("dungeon")
end

function initGlobals()
    data = {}

    -- game state
    -- 0: main menu
    -- 1: gameplay
    -- 2: Game Over!
    -- 3: Dungeon cleared (boss defeated)
    -- 4: Quit screen (web only)

    gameState = 0
    globalStun = 0
    victoryTimer = 0  -- countdown to the cleared screen once the boss dies
end
