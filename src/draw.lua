function drawCamera()
    --if gameState == 0 then return end
    
    if gameMap.layers["floor"] then
        gameMap:drawLayer(gameMap.layers["floor"])
    end

    if gameMap.layers["base_wall"] then
        gameMap:drawLayer(gameMap.layers["base_wall"])
    end

    drawPlayer()
    enemies:draw()
    drawEnemyHealthBars()
    drawProjectiles()
    drawPlayerProjectiles()

    -- Lighting must come LAST so it multiplies everything above — any sprite
    -- drawn after this pass would escape the darkness.
    drawLighting()
end

-- LIGHTING SETTINGS ---------------------------------------------------------------------------
-- How dark the world is and how far light reaches. Tuned for the 30..35px sprites
-- and 600x480 window; bump these if you change art scale.
local MAX_LIGHTS           = 16  -- shader array cap; safety-break below keeps Lua in sync
local PLAYER_LIGHT_RADIUS  = 170 -- the player's torch pool
local ENEMY_LIGHT_RADIUS   = 60  -- glow around alarmed/attacking enemies
local ENEMY_BOLT_RADIUS    = 30  -- enemy projectiles; they stay visible through the dark
local PLAYER_BOLT_RADIUS   = 24  -- your own throws

-- The dungeon darkness pass. Multiplies the scene below with a light map:
--   1. The player is ALWAYS lit (they're the torch).
--   2. Projectiles glow small and bright — you can see attacks coming.
--   3. Enemies in state >= 99 (alert + attacking) glow — telegraphed from the dark.
-- Everything else sits in cold near-black set inside assets/shaders/lighting.glsl.
function drawLighting()
    local shader = shaders.lighting
    if not shader then return end

    -- Priority order matters only if we hit MAX_LIGHTS: player first (never
    -- dropped), then danger, then threat telegraphs.
    local allLights = {}

    -- 1) Player torch — always slot[0]. player.x/y are synced to the collider
    --    every frame by cameraUpdate
    table.insert(allLights, {player.x, player.y, PLAYER_LIGHT_RADIUS})

    -- 2) Projectiles — a fleeing throw or an incoming homing bolt both glow.
    --    Their sprites had bright glows already, which are multiplied down to
    --    near-invisible in the dark; these pools restore them.
    for _, p in ipairs(projectiles) do
        if not p.dead and p.physics and #allLights < MAX_LIGHTS then
            local px, py = p.physics:getPosition()
            table.insert(allLights, {px, py, ENEMY_BOLT_RADIUS})
        end
    end
    for _, p in ipairs(playerProjectiles) do
        if not p.dead and p.physics and #allLights < MAX_LIGHTS then
            local px, py = p.physics:getPosition()
            table.insert(allLights, {px, py, PLAYER_BOLT_RADIUS})
        end
    end

    -- 3) Attack telegraphs. state 99 = alert ("?!"), 100+ = attacking/firing.
    --    The glow fades in as they close in — threats announce themselves
    --    through the dark so the dodge tools get used, not forgotten.
    for _, e in ipairs(enemies) do
        if not e.dead and e.physics and e.state and e.state >= 99 and #allLights < MAX_LIGHTS then
            local ex, ey = e.physics:getPosition()
            table.insert(allLights, {ex, ey, ENEMY_LIGHT_RADIUS})
        end
    end

    -- 'multiply' requires the premultiplied submode in this LÖVE build; with
    -- an alpha-1 quad the rgb result is the same (dst * src) either way.
    love.graphics.setBlendMode('multiply', 'premultiplied')
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)

    -- Send uniforms. lightCount is a plain number; the light array is sent as
    -- one {x, y, radius} table per live light. Slots past lightCount are never
    -- touched by the shader's loop, so the rest of the array can hold garbage.
    -- Send uniforms, refreshed every frame:
    --   lightCount / lights — the live slots (player torch first, then danger,
    --     then threat telegraphs); slots past lightCount are never read.
    --   cam_pos / screen_size — the screen->world transform the shader uses,
    --     because it computes world position per pixel (fragment-only shader).
    shader:send('lightCount', #allLights)
    local unpackPos = unpack or table.unpack  -- Lua 5.1/LuaJIT vs 5.2+
    shader:send('lights', unpackPos(allLights))
    shader:send('cam_pos', {cam.x, cam.y})
    shader:send('screen_size', {love.graphics.getWidth(), love.graphics.getHeight()})

    -- The overlay rect, in world coords: the shader reads each vertex's
    -- object-space position AS its world position (see the shader header).
    -- Slight overdraw on every side, so the pass never leaves an unshaded
    -- sliver even at odd window aspect ratios after resizing.
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local padding = 60
    love.graphics.rectangle('fill',
        cam.x - w / 2 - padding, cam.y - h / 2 - padding,
        w + padding * 2, h + padding * 2)

    love.graphics.setShader()
    -- Restore the DEFAULT blend setup: plain alpha blend with standard
    -- (pre-multiplied-into-alpha) source colors. In this LÖVE version the
    -- default alphamode is named 'alphamultiply'.
    love.graphics.setBlendMode('alpha', 'alphamultiply')
end


function drawGameOver()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    --Dark overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    --GAME OVER text
    love.graphics.setColor(1, 0.1, 0.1, 1)
    love.graphics.setFont(fonts.large)
    love.graphics.printf("GAME OVER", 0, h / 2 - 40, w, "center")

    -- Restart hint
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(fonts.medium)
    love.graphics.printf("Press 'R' to restart", 0, h / 2 + 10, w, "center")

    -- Reset color and font to default
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.getFont())
end

function drawHUD()
    local barWidth = 150
    local barHeight = 14
    local x = 20
    local y = 20
    local healthPercent = player.health / player.maxHealth

    -- Flash bar red/white when invincible (just took damage)
    local flashColor = {0.85, 0.15, 0.15, 1}
    if player.invincibleTimer > 0 then
        local flash = math.sin(player.invincibleTimer * 20) > 0
        flashColor = flash and {1, 1, 1, 1} or {0.85, 0.15, 0.15, 1}
    end

    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight, 4, 4)

    -- Health fill with flash
    love.graphics.setColor(flashColor)
    love.graphics.rectangle("fill", x, y, barWidth * healthPercent, barHeight, 4, 4)

    -- Border
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.rectangle("line", x, y, barWidth, barHeight, 4, 4)

    -- Label
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("HP  " .. player.health .. "/" .. player.maxHealth, x, y + barHeight + 4)

    -- FLASH STEP bar (dodge charges) — tiny, sits under the HP label.
    -- Drains a slice per dodge, refills gradually after a no-dash delay.
    -- All logic lives in player.flashStep* fields (src/player.lua).
    local fsWidth  = 100
    local fsHeight = 6
    local fsX = x
    local fsY = y + 34  -- clear of the HP bar and its label
    -- Clamp so nothing can ever produce a negative rectangle width
    local fsPercent = math.max(0, math.min(1, player.flashStep or 1))

    -- Background — same style as the HP bar, just smaller
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", fsX, fsY, fsWidth, fsHeight, 3, 3)

    -- Fill: icy blue to match the dash ghost. When a dash is refused for low
    -- charge (flashStepDeniedTimer, set in startDodge), the fill color blinks
    -- red briefly — the bar still shows the true remaining charge.
    local fsColor = {0.55, 0.8, 1, 1}
    if (player.flashStepDeniedTimer or 0) > 0
       and math.sin(player.flashStepDeniedTimer * 40) > 0 then
        fsColor = {1, 0.25, 0.25, 1}
    end
    love.graphics.setColor(fsColor)
    love.graphics.rectangle("fill", fsX, fsY, fsWidth * fsPercent, fsHeight, 3, 3)

    -- Border + label beside the tiny bar
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.rectangle("line", fsX, fsY, fsWidth, fsHeight, 3, 3)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Flash step", fsX + fsWidth + 8, fsY - 4)

    love.graphics.setColor(1, 1, 1, 1)
end

function drawEnemyHealthBars()
    for _, e in ipairs(enemies) do
        if e.physics and not e.dead then  -- skip dead enemies
            local ex, ey = e.physics:getPosition()
            local barWidth = 24
            local barHeight = 3
            local x = ex - barWidth / 2
            local y = ey - 20

            local healthPercent = math.max(0, e.health / (e.maxHealth or e.health))
            if healthPercent >= 1 then goto continue end

            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
            love.graphics.rectangle("fill", x, y, barWidth, barHeight, 1, 1)

            local r = 1 - healthPercent
            local g = healthPercent
            love.graphics.setColor(r, g, 0.1, 1)
            love.graphics.rectangle("fill", x, y, barWidth * healthPercent, barHeight, 1, 1)

            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("line", x, y, barWidth, barHeight, 1, 1)

            love.graphics.setColor(1, 1, 1, 1)
            ::continue::
        end
    end
end