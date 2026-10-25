function drawCamera()
    --if gameState == 0 then return end

    if gameMap.layers["floor"] then
        gameMap:drawLayer(gameMap.layers["floor"])
    end

    if gameMap.layers["base_wall"] then
        gameMap:drawLayer(gameMap.layers["base_wall"])
    end

    drawPlayer()
    -- The shield orb renders hot-on-the-heels of the sprite, BEFORE lighting —
    -- it's an in-world object, so it gets multiplied down at distance like
    -- everything else (the orb itself emits a light slot below, so it's never
    -- actually invisible).
    drawShieldOrb()
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
local SHIELD_LIGHT_RADIUS  = 55  -- subtle extra glow while the shield orb is up
local ENEMY_LIGHT_RADIUS   = 60  -- glow around alarmed/attacking enemies
local ENEMY_BOLT_RADIUS    = 30  -- enemy projectiles; they stay visible through the dark
local PLAYER_BOLT_RADIUS   = 24  -- your fire spells

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

    -- 1b) Shield orb glow — while the barrier is up the player's light pool
    --     blooms wider. Same position slot, just a bigger halo; additive in
    --     the shader, so it visibly brightens the torch rather than double-drawing.
    if player.shieldActive then
        table.insert(allLights, {player.x, player.y, SHIELD_LIGHT_RADIUS})
    end

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
    --    lightRadius is an optional per-enemy override: the boss flares
    --    hot while telegraphing a cast, and runs a hotter phase-2 aura.
    for _, e in ipairs(enemies) do
        if not e.dead and e.physics and e.state and e.state >= 99 and #allLights < MAX_LIGHTS then
            local ex, ey = e.physics:getPosition()
            table.insert(allLights, {ex, ey, e.lightRadius or ENEMY_LIGHT_RADIUS})
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

-- The glowing shield orb drawn around the player while the barrier is up.
-- Teal palette so it reads distinct from: torch light (warm white), fire
-- spells (orange), enemy bolts (orange-red) and alert glows.
-- Drawn in world space (before the lighting pass) on purpose.
function drawShieldOrb()
    if not player.shieldActive then return end

    local px, py = player.x, player.y
    -- Gentle breathing pulse — alive, not a static ring
    local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6)
    local radius = player.shieldRadius + 2 * pulse

    -- Faint interior: barely-there translucent tint, NOT a bright disc.
    love.graphics.setColor(0.3, 0.9, 0.7, 0.05 + 0.03 * pulse)
    love.graphics.circle("fill", px, py, radius)

    -- Glowing circumference: a soft wide halo behind a thin bright rim, so the
    -- boundary reads clearly while the interior stays see-through.
    love.graphics.setLineWidth(5 + 2 * pulse)
    love.graphics.setColor(0.55, 1, 0.85, 0.12 + 0.06 * pulse)
    love.graphics.circle("line", px, py, radius)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.55, 1, 0.85, 0.45 + 0.15 * pulse)
    love.graphics.circle("line", px, py, radius)

    -- Secondary faint outer ring — energy field feel
    love.graphics.setColor(0.55, 1, 0.85, 0.18)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", px, py, radius + 4 + 2 * pulse)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function drawHUD()
    -- Small font for every label below: without this the HUD inherits
    -- whatever font the previous draw call left set (24px from the menu), so
    -- "Flash step" / "HP" / "Shield" dwarfed the bars next to them.
    love.graphics.setFont(fonts.small)
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
    love.graphics.print("HP  " .. player.health .. "/" .. player.maxHealth, x, y + barHeight + 2)

    -- FLASH STEP bar (dodge charges) — tiny, sits under the HP label.
    -- Drains a slice per dodge, refills gradually after a no-dash delay.
    -- All logic lives in player.flashStep* fields (src/player.lua).
    local fsWidth  = 100
    local fsHeight = 6
    local fsX = x
    -- 32 = 20 (HP bar top) + 14 (its height) + 2 (gap) + fine-tuned padding:
    -- clears the 12px HP label without leaving a large empty band.
    local fsY = y + 32
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

    -- SHIELD bar — third tiny meter. Deliberately shows the regen design:
    -- dimmed while the post-shutdown regen delay waits, teal while tickling
    -- up, brighter still while the orb is actually raised (felt through the
    -- constant drain). Red blink on E-pressed-with-too-little-charge.
    local shWidth  = 100
    local shHeight = 6
    local shX = x
    local shY = fsY + 12  -- tucks just under the Flash step bar
    local shPercent = math.max(0, math.min(1, player.shieldMeter or 1))

    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", shX, shY, shWidth, shHeight, 3, 3)

    -- Fill color state machine: denied-blink red > active bright > waiting
    -- (delay) dim > regenerating normal
    local shColor = {0.3, 0.9, 0.7, 1}
    if (player.shieldDeniedTimer or 0) > 0 and math.sin(player.shieldDeniedTimer * 40) > 0 then
        shColor = {1, 0.25, 0.25, 1}
    elseif player.shieldActive then
        shColor = {0.55, 1, 0.85, 1}
    elseif (player.shieldRegenDelayTimer or 0) > 0 then
        shColor = {0.3, 0.9, 0.7, 0.35}
    end
    love.graphics.setColor(shColor)
    love.graphics.rectangle("fill", shX, shY, shWidth * shPercent, shHeight, 3, 3)

    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.rectangle("line", shX, shY, shWidth, shHeight, 3, 3)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Shield", shX + shWidth + 8, shY - 4)

    drawMinimap()

    love.graphics.setColor(1, 1, 1, 1)
end

-- MINIMAP SETTINGS ---
local MINIMAP_MARGIN = 12  -- distance from the window's top-right corner

-- Stamps the pre-rendered dungeon canvas (built in loadMap) with live markers:
--   - enemies as red dots, brighter when alerted/attacking (state >= 99) —
--     doubles as a live threat radar
--   - the player as a warm dot (matching their torch) with a small facing
--     tick, which is the literal "sense of direction" bit
function drawMinimap()
    if not minimapCanvas then return end

    local w = love.graphics.getWidth()
    local pad = 4  -- inner padding between panel edge and map canvas
    local panelW = minimapCanvas:getWidth() + pad * 2
    local panelH = minimapCanvas:getHeight() + pad * 2
    local x = w - panelW - MINIMAP_MARGIN
    local y = MINIMAP_MARGIN

    -- Panel: translucent, matching the HP bar's dark style
    love.graphics.setColor(0.04, 0.04, 0.07, 0.8)
    love.graphics.rectangle("fill", x, y, panelW, panelH, 5, 5)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle("line", x, y, panelW, panelH, 5, 5)

    -- Static layout — one canvas draw
    love.graphics.setColor(1, 1, 1, 1)
    local mapX = x + pad
    local mapY = y + pad
    love.graphics.draw(minimapCanvas, mapX, mapY)

    -- World px -> canvas px: world tile size (e.g. 64) vs canvas px per tile (4)
    local scale = MINIMAP_TILE_PX / gameMap.tilewidth
    local mapTo = function(wx, wy)
        return mapX + wx * scale, mapY + wy * scale
    end

    -- Enemies: dim red while idle/wandering so the map shows a lived-in
    -- dungeon, bright red when state >= 99 (alert/attack) — the threats
    -- that matter read at a glance.
    for _, e in ipairs(enemies) do
        if e.physics and not e.dead then
            local ex, ey = e.physics:getPosition()
            local dx, dy = mapTo(ex, ey)
            if e.state and e.state >= 99 then
                love.graphics.setColor(1, 0.2, 0.2, 1)
                love.graphics.circle("fill", dx, dy, 2.5)
            else
                love.graphics.setColor(0.7, 0.25, 0.25, 0.55)
                love.graphics.circle("fill", dx, dy, 1.5)
            end
        end
    end

    -- Player: facing tick first so the dot covers the joint, then the dot
    -- itself in the torch color.
    local px, py = mapTo(player.x, player.y)
    local facing = {
        up    = { 0, -1},
        down  = { 0,  1},
        left  = {-1,  0},
        right = { 1,  0},
    }
    local f = facing[player.lastDirection] or { 0, -1 }
    love.graphics.setColor(1, 0.3, 0.3, 0.9)
    love.graphics.line(px, py, px + f[1] * 6, py + f[2] * 6)
    love.graphics.setColor(1, 0.95, 0.8, 1)
    love.graphics.circle("fill", px, py, 2.5)

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
