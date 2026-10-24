-- restructuring needed
player = {}
player.x = 0
player.y = 0
player.speed = 150
-- SPRINT: hold Shift (either) to run at 1.5x walk speed. Used to weave around
-- enemy melee (deadly at <30px) and keep ahead of homing shots — note walk/sprint
-- speed vs mage bolt speed: 150/225 vs 240, so sprinting alone won't outrun a
-- bolt, but a dodge dash (below) sheds the lock outright.
player.sprintSpeed = 225
player.grid = anim8.newGrid(24, 32, sprites.playerSheet:getWidth(), sprites.playerSheet:getHeight())
player.collider = world:newBSGRectangleCollider(960, 1890, 30, 50, 10)
player.collider:setFixedRotation(true)
player.collider:setCollisionClass("player")

player.health = 10
player.maxHealth = 10
player.invincibleTimer = 0
player.hitFlashTimer = 0

player.animations = {}
player.animations.up = anim8.newAnimation(player.grid('1-3', 1), 0.2)
player.animations.down = anim8.newAnimation(player.grid('1-3', 3), 0.2)
player.animations.left = anim8.newAnimation(player.grid('1-3', 4), 0.2)
player.animations.right = anim8.newAnimation(player.grid('1-3', 2), 0.2)


-- Each attack is 5 frames, plays once then returns to walk
player.animations.attackUp    = anim8.newAnimation(player.grid('1-5', 5), 0.1, 'pauseAtEnd')
player.animations.attackDown  = anim8.newAnimation(player.grid('1-5', 7), 0.1, 'pauseAtEnd')
player.animations.attackLeft  = anim8.newAnimation(player.grid('1-5', 8), 0.1, 'pauseAtEnd')
player.animations.attackRight = anim8.newAnimation(player.grid('1-5', 6), 0.1, 'pauseAtEnd')

player.anim = player.animations.up
player.lastDirection = "up"

-- Add these with the other animations
player.animations.throwUp    = anim8.newAnimation(player.grid(16, 5), 0.15, 'pauseAtEnd')
player.animations.throwDown  = anim8.newAnimation(player.grid(16, 7), 0.15, 'pauseAtEnd')
player.animations.throwLeft  = anim8.newAnimation(player.grid(16, 8), 0.15, 'pauseAtEnd')
player.animations.throwRight = anim8.newAnimation(player.grid(16, 6), 0.15, 'pauseAtEnd')

-- Throw state
-- NOTE: throwing used to reuse the MELEE timers (attacking / attackTimer), which
-- is exactly what blocked all movement for 0.5s after pressing X. The throw now
-- has its own state below so the player can walk around while a shot flies out
-- — melee still commits to the swing and holds you in place.
player.throwing      = false
player.throwTimer    = 0
player.throwDuration = 0.5   -- keep the old (0.5s) throw animation length

player.throwCooldown    = 0
player.throwCooldownMax = 0.4
player.throwDamage      = 1
player.throwSpeed       = 200

-- Attack state
player.attacking = false
player.attackTimer = 0
player.attackDuration = 0.5   -- how long the full attack lasts
player.attackCooldown = 0     -- prevents spam, ticks down
player.attackCooldownMax = 0.4
player.attackRange = 35       -- melee hit range in pixels
player.attackDamage = 1

-- Dodge dash state (triggered by tapping C, see player:startDodge)
-- A short momentum burst in one direction with i-frames. Deliberately uses its
-- own invincibility timer (dodgeInvincibleTimer) instead of piggybacking on the
-- post-hit invincibleTimer: the draw code flashes red for took-a-hit i-frames,
-- which would make a clean dodge look like you got clipped.
player.dodging    = false
player.dodgeTimer = 0         -- counts the burst down
player.dodgeDirX  = 0         -- dash heading, locked at dash start
player.dodgeDirY  = 0
player.dodgeDuration     = 0.2   -- seconds the burst lasts
player.dodgeSpeed        = 450   -- burst speed (~3x walk)
player.dodgeCooldown     = 0
player.dodgeCooldownMax  = 0.6   -- includes the dash itself, so ~0.4s dead time
player.dodgeInvincibleTimer = 0
player.dodgeInvincibleTime  = 0.3 -- i-frame window, slightly longer than the burst

-- FLASH STEP meter (dodge resource, drawn as a tiny bar in drawHUD)
-- Each dash spends one slice; after flashStepRegenDelay seconds WITHOUT a dash
-- the meter trickles back to full. Tapping C with too little charge is denied
-- (HUD blinks red) rather than silently doing nothing.
player.flashStep = 1                 -- current charge, 0..1
player.flashStepCost = 0.3           -- per dash: 3 dashes from a full bar
player.flashStepRegenDelay = 0.8     -- seconds without a dash before regen starts
player.flashStepRegenDelayTimer = 0  -- countdown of the above
player.flashStepRegenRate = 1 / 1.2  -- full refill in ~1.2s of regen
player.flashStepDeniedTimer = 0      -- brief red blink on HUD when a dash is refused

function player:takeDamage(amount)
    if self.invincibleTimer > 0 then return end
    -- Dodge i-frames: identical "you can't be touched right now" rule as the
    -- took-a-hit timer above, with a separate timer/visual (see state block).
    -- Note the projectile loop in src/entities/projectile.lua still destroys
    -- shots that overlap you during this window — dodging THROUGH a bolt
    -- deletes it without paying HP, which is the fun part.
    if self.dodgeInvincibleTimer > 0 then return end
    self.health = self.health - amount
    self.invincibleTimer = 1
    self.hitFlashTimer = 0.1 -- short white flash on hit
    if self.health <= 0 then
        gameState = 2 -- Set a new game state for "game over"

        -- Freeze all projectiles immediately
        for _, p in ipairs(projectiles) do
            if p.physics then
                p.physics:setLinearVelocity(0, 0)
            end
        end

        -- Freeze all enemies immediately
        for _, e in ipairs(enemies) do
            if e.physics then
                e.physics:setLinearVelocity(0, 0)
            end
        end
    end
end

function player:startAttack()
    if self.attackCooldown > 0 then return end
    if self.dodging then return end  -- mid-dash swings look broken; dash lands first
    self.attacking = true
    self.attackTimer = self.attackDuration
    self.attackCooldown = self.attackCooldownMax

    -- Switch to attack animation for current direction
    local dir = self.lastDirection
    self.anim = self.animations["attack" .. dir:sub(1,1):upper() .. dir:sub(2)]
    self.anim:gotoFrame(1)
    self.anim:resume()

    -- Hit enemies in front of player immediately on swing
    self:doMeleeHit()
end

function player:doMeleeHit()
    local px, py = self.collider:getPosition()

    -- Offset the hit box in the facing direction
    local offsets = {
        up    = { 0, -self.attackRange},
        down  = { 0,  self.attackRange},
        left  = {-self.attackRange, 0},
        right = { self.attackRange, 0},
    }

    local off = offsets[self.lastDirection]
    local hitX = px + off[1]
    local hitY = py + off[2]

    -- Query a circle in front of the player for enemies
    local hits = world:queryCircleArea(hitX, hitY, self.attackRange * 0.8, {'enemy'})
    for _, collider in ipairs(hits) do
        local enemy = collider.parent
        if enemy and not enemy.dead then
            enemies:takeDamage(enemy, self.attackDamage)
        end
    end
end

-- Dodge dash: quick burst in the direction you're holding (or facing) with a
-- short i-frame window that also breaks any live homing locks — dodging and
-- tanking a hit are both ways out of a lock-on, dodge is just the free one.
function player:startDodge()
    if self.dodgeCooldown > 0 or self.dodging then return end
    if self.attacking then return end  -- committed to the melee swing, no escape hatch

    -- Charge gate: not enough Flash step? Flag the HUD to blink red and bail.
    -- The check runs BEFORE any dash state is touched, so a refused tap
    -- changes nothing.
    if self.flashStep < self.flashStepCost then
        self.flashStepDeniedTimer = 0.25
        return
    end

    -- Dash direction: a held movement key wins; otherwise dash toward facing.
    local dirOffsets = {
        up    = { 0, -1},
        down  = { 0,  1},
        left  = {-1,  0},
        right = { 1,  0},
    }

    local dashKey
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        dashKey = "right"
    elseif love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        dashKey = "left"
    elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        dashKey = "down"
    elseif love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        dashKey = "up"
    else
        dashKey = self.lastDirection  -- standing still: dash the way you face
    end

    local d = dirOffsets[dashKey]

    self.dodging = true
    self.dodgeTimer = self.dodgeDuration
    self.dodgeDirX = d[1]
    self.dodgeDirY = d[2]
    self.dodgeCooldown = self.dodgeCooldownMax

    -- Spend the meter slice and restart the regen delay. The delay only resets
    -- on a SUCCESSFUL dash: mashing C while it's on cooldown or empty never
    -- punishes regen, it just fails the gates above.
    self.flashStep = self.flashStep - self.flashStepCost
    self.flashStepRegenDelayTimer = self.flashStepRegenDelay

    -- Grant the i-frame window (its own timer — see the state block comment)
    -- and face/anim toward the dash so the walk anim reads as a running burst.
    self.dodgeInvincibleTimer = self.dodgeInvincibleTime
    self.lastDirection = dashKey
    self.anim = self.animations[dashKey]
end

function player:startThrow()
    if player.throwCooldown > 0 then return end

    player.throwCooldown = player.throwCooldownMax

    -- Start the throw animation on its OWN timer.
    -- The old code set player.attacking / attackTimer here, which was the root
    -- cause of "rooted to the ground while shooting". Now the throw animation
    -- plays while movement keeps running (see playerUpdate below).
    player.throwing = true
    player.throwTimer = player.throwDuration

    -- Switch to throw animation for current direction
    local dir = player.lastDirection
    local animKey = "throw" .. dir:sub(1,1):upper() .. dir:sub(2)
    player.anim = player.animations[animKey]
    player.anim:gotoFrame(1)
    player.anim:resume()

    -- Spawn projectile in facing direction
    local px, py = player.collider:getPosition()

    local dirOffsets = {
        up    = { 0, -1},
        down  = { 0,  1},
        left  = {-1,  0},
        right = { 1,  0},
    }

    local d = dirOffsets[player.lastDirection]
    local tx = px + d[1] * 100
    local ty = py + d[2] * 100

    spawnPlayerProjectile(px, py, tx, ty, player.throwSpeed, player.throwDamage)
end

-- Throw state recap (all ticking happens automatically in playerUpdate below):
--   throwCooldown — gates how often a shot can fire (priority: can't spam)
--   throwing/throwTimer — how long the throw animation is on screen
--   Neither of them blocks movement anymore — movement is only gated by the
--   melee state (player.attacking).

function playerUpdate(dt)
    -- if gameState == 2 then return end -- guard checks
    if player.invincibleTimer > 0 then
        player.invincibleTimer = player.invincibleTimer - dt
    end

    if player.hitFlashTimer > 0 then
        player.hitFlashTimer = player.hitFlashTimer - dt
    end

    if player.throwCooldown > 0 then
        player.throwCooldown = player.throwCooldown - dt
    end

    if player.attackCooldown > 0 then
        player.attackCooldown = player.attackCooldown - dt
    end
    if player.attackTimer > 0 then
        player.attackTimer = player.attackTimer - dt
        if player.attackTimer <= 0 then
            player.attacking = false  -- attack window over
            -- Return to the movement animation set after one-shot attack/throw anims.
            player.anim = player.animations[player.lastDirection]
        end
    end

    -- Throw animation countdown (melee's twin, handled above via attackTimer).
    -- When the throw anim finishes, the sprite goes back to the normal
    -- walk/idle set — key difference from melee: the throw never touched
    -- player.attacking, so this un-wind is purely cosmetic.
    if player.throwTimer > 0 then
        player.throwTimer = player.throwTimer - dt
        if player.throwTimer <= 0 then
            player.throwing = false
            player.anim = player.animations[player.lastDirection]
        end
    end

    -- Dodge dash timers: cooldown and i-frame windows tick in parallel; the
    -- burst timer below tracks the actual movement burst.
    if player.dodgeCooldown > 0 then
        player.dodgeCooldown = player.dodgeCooldown - dt
    end

    if player.dodgeInvincibleTimer > 0 then
        player.dodgeInvincibleTimer = player.dodgeInvincibleTimer - dt
    end

    -- FLASH STEP regen. Two phases, prioritized by the delay timer:
    --   1. delay timer running — nothing regenerates ("not pressed for a while")
    --   2. delay done — charge trickles back toward full until it sits at 1
    if player.flashStepDeniedTimer > 0 then
        player.flashStepDeniedTimer = player.flashStepDeniedTimer - dt
    end

    if player.flashStepRegenDelayTimer > 0 then
        player.flashStepRegenDelayTimer = player.flashStepRegenDelayTimer - dt
    elseif player.flashStep < 1 then
        player.flashStep = math.min(1, player.flashStep + player.flashStepRegenRate * dt)
    end

    if player.dodgeTimer > 0 then
        player.dodgeTimer = player.dodgeTimer - dt
        if player.dodgeTimer <= 0 then
            player.dodging = false
            -- Burst over: snap back to the walk set; the normal walk-pick /
            -- idle logic takes over on subsequent frames.
            player.anim = player.animations[player.lastDirection]
        end
    end

    -- HOLD X to fire continuously.
    -- The tap handler in love.keypressed (main.lua) still covers single presses;
    -- this makes shooting work while moving like the movement keys do: hold to
    -- keep performing the action. startThrow is cooldown-guarded, so the frame
    -- the key goes down (keypressed fires, then update sees isDown true) the
    -- cooldown it just set blocks this duplicate call — no double shots.
    if love.keyboard.isDown("x") then
        player:startThrow()
    end

    -- collider
    local vx = 0
    local vy = 0
    local moved = false

    -- Movement — blocked during a MELEE attack (you commit to the swing) but
    -- ALLOWED during a throw: this is what makes "move and shoot" work. The
    -- throw only freezes the sprite, not the body.
    --
    -- An active dodge dash OVERRIDES regular movement entirely (checked first):
    -- velocity is locked to the heading chosen at dash start. You can't steer
    -- mid-dash — that commitment, plus the i-frames, is the skill of dodging.
    -- Walls/logs still stop you via physics, so no clipping through the map.
    if player.dodging then
        vx = player.dodgeDirX * player.dodgeSpeed
        vy = player.dodgeDirY * player.dodgeSpeed
        moved = true
    elseif not player.attacking then
        -- SPRINT: Shift (either one) ups the walk speed for every branch below.
        -- Sprinting is allowed while throwing (run-and-gun) and costs nothing —
        -- it's held, not stamina-based, so it stays a smooth evasion tool.
        local speed = player.speed
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            speed = player.sprintSpeed
        end

        if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
            vx = speed
            player.lastDirection = "right"
            moved = true
        elseif love.keyboard.isDown("left") or love.keyboard.isDown("a") then
            vx = -speed
            player.lastDirection = "left"
            moved = true
        elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
            vy = speed
            player.lastDirection = "down"
            moved = true
        elseif love.keyboard.isDown("up") or love.keyboard.isDown("w") then
            vy = -speed
            player.lastDirection = "up"
            moved = true
        end
    end

    -- Walk animation pick. The branches above only write velocity + facing;
    -- the walk anim is now chosen here, in one place.
    -- While a throw animation is live it OWNS the sprite: the player keeps
    -- gliding in the held direction while the throw frame is drawn. (The sheet
    -- is a single 4-directional character per frame, so "torso plays the swing,
    -- feet slide" is the standard compromise — and it reads fine at 0.5s.)
    if moved and not player.throwing then
        player.anim = player.animations[player.lastDirection]
    end

    player.collider:setLinearVelocity(vx, vy)

    -- Idle frame when not moving, not mid-melee and not mid-throw
    -- (in those cases the attack/throw animation owns the sprite instead)
    if not moved and not player.attacking and not player.throwing then
        -- Ensure idle frame is picked from looping walk anims (they all have frame 2).
        player.anim = player.animations[player.lastDirection]
        player.anim:gotoFrame(2)
    end

    player.anim:update(dt)
end

function drawPlayer()
    local px, py = player.x, player.y

    if player.hitFlashTimer > 0 then
        -- Bright white flash on hit
        love.graphics.setColor(1, 1, 1, 1)
        player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
        love.graphics.setColor(1, 1, 1, 1)
        -- Draw white overlay on top
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 0.8)
        player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
        love.graphics.setBlendMode("alpha")
    elseif player.dodgeInvincibleTimer > 0 then
        -- MID-DASH ghost: pale and translucent, clearly not the red
        -- took-a-hit blink. Tells the player "this is my i-frame burst".
        love.graphics.setColor(0.7, 0.9, 1, 0.55)
        player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
    elseif player.invincibleTimer > 0 then
        local flash = math.sin(player.invincibleTimer * 20) > 0
        love.graphics.setColor(flash and {1, 0.3, 0.3, 1} or {1, 1, 1, 0.2})
        player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
    else
        love.graphics.setColor(1, 1, 1, 1)
        player.anim:draw(sprites.playerSheet, px, py, nil, 1.5, nil, 12, 16)
    end

    love.graphics.setColor(1, 1, 1, 1)
end
