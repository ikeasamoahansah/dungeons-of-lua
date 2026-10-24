-- BOSS FIGHT DESIGN ---------------------------------------------------------------------------
-- Phase 1 (HP > 50%):  one move — the classic 3-shot cone every 2.5s. Baseline
--                      behavior, deliberately unchanged so phase 1 mirrors the
--                      normal-enemy threat model.
-- Phase 2 (HP <= 50%): the boss ENRAGES. The instant HP crosses the threshold,
--                      a 360° radial burst fires as the announcement, then a
--                      rotating pattern list takes over. Every pattern is
--                      telegraphed: the boss holds its staff pose and its light
--                      aura flares (drawLighting picks this up) for the cast
--                      window before shots leave the barrel:
--   cone5   — tighter, faster 5-shot cone (pressure)
--   homing  — single slow bolt that CHASES the player (outplay with the dodge,
--             or facetank it with the shield; it uses the enemy homing rules,
--             so player i-frames/dodge also break its lock)
--   spread  — wide 3-shot at ~340px/s, quick filler to keep the ring moving
--   radial  — 8 shots in a full circle, longest telegraph, the "GET AWAY" moment
-- Rotation order matters: cone5 keeps rhythm, then homing threatens movement,
-- then spread punishes over-camping, then radial clears the middle.
--
-- Phase 2 also tints the sprite red and nudges move speed — visible + felt.

local function bossInit(enemy, x, y, args)
    enemy.physics = world:newBSGRectangleCollider(x, y, 12, 16, 3)
    enemy.physics:setFixedRotation(true)
    enemy.physics:setMass(1)
    enemy.physics:setLinearDamping(2)
    enemy.physics.parent = enemy

    enemy.form = 1
    enemy.sprite = sprites.enemies.boss

    if args and args.form ~= nil then
        enemy.form = args.form
    end

    enemy.health = 5
    enemy.maxHealth = 5
    
    enemy.speed = 1
    enemy.maxSpeed = 80
    enemy.magnitude = 450
    enemy.dir = vector(0, 1)
    enemy.viewDistance = 150
    enemy.separationRadius = 50

    enemy.grid = anim8.newGrid(20, 20, enemy.sprite:getWidth(), enemy.sprite:getHeight())

    -- NOTE: the animations table must exist UNCONDITIONALLY now. The original
    -- file only created it inside `if enemy.form == 2`, so a form-1 boss (the
    -- map default) had enemy.animations == nil and the cast telegraph code
    -- indexed nil. Same story for walk: it used to live OUTSIDE the
    -- .animations table, so the cast code couldn't restore it by name.
    enemy.animations = {}
    enemy.animations.walk = anim8.newAnimation(enemy.grid('1-2', 1), 0.3)
    enemy.anim = enemy.animations.walk

    -- Staff pose as the casting telegraph — created ONLY if the sprite sheet
    -- actually has a 3rd column. The stock boss sheet is 40x20 (2 columns),
    -- so here staff stays nil and casting keeps the walk pose; the telegraph
    -- still reads via the light flare + longer cast window. (The original
    -- form-2-only assignment would have crashed the moment a form-2 boss
    -- ever spawned, since the frame doesn't exist on this art.)
    local columns = math.floor(enemy.sprite:getWidth() / 20)
    if columns >= 3 then
        enemy.animations.staff = anim8.newAnimation(enemy.grid(3, 1), 1)
    end

    enemy.floatTime = 0.5
    enemy.floatY = 0
    enemy.floatMax = 1.5

    enemy.scaleX = 1
    enemy.scaleY = 1.5
    -- if math.random() < 0.5 then enemy.scaleX = -1 end

    -- Attack machinery ------------------------------------------------------------------
    enemy.shootTimer = 0
    enemy.shootCooldown = 2.5  -- phase 1 pacing

    -- Phase tracking. Phase flips exactly once, when HP crosses half.
    enemy.phase = 1

    -- Cast (telegraph) state: while castTimer > 0 the boss is winding up
    -- castPattern, holding the staff pose, flaring its light. Fires at zero.
    enemy.castTimer = 0
    enemy.castPattern = nil
    enemy.castTelegraphNormal = 0.5  -- seconds of warning, most patterns
    enemy.castTelegraphRadial = 0.8  -- the big one gets a longer tell

    -- Phase 2 pattern list + per-pattern cooldown (seconds between casts).
    -- Longer pauses after radial/spread so patterns read as individual *moves*,
    -- not constant noise.
    enemy.phase2Patterns = {"cone5", "homing", "spread", "radial"}
    enemy.patternIndex = 1  -- will start the rotation on "cone5" (set in transition)

    local PATTERN_COOLDOWNS = {
        cone3   = 2.5,
        cone5   = 2.0,
        homing  = 2.2,
        spread  = 1.6,
        radial  = 3.0,
    }

    -- Light aura: default is ENEMY_LIGHT_RADIUS (60) picked up by drawLighting;
    -- beginCast/cast wind-up overrides it via self.lightRadius so threats FLARE
    -- in the dark. Kept in sync every update.
    enemy.lightRadius = nil

    function enemy:beginCast()
        local pattern

        if self.phase == 1 then
            pattern = "cone3"  -- the original fight, untouched
        else
            -- Phase 2: cycle the rotation; wrap the index so it loops forever
            pattern = self.phase2Patterns[self.patternIndex]
            self.patternIndex = (self.patternIndex % #self.phase2Patterns) + 1
        end

        self.castPattern = pattern
        self.castTimer = (pattern == "radial")
            and self.castTelegraphRadial
            or self.castTelegraphNormal

        -- Casting pose: hold the staff animation (static pose, 1s — longer
        -- than any telegraph) while winding up. Restored to the walk set when
        -- the pattern fires.
        if self.animations.staff then
            self.anim = self.animations.staff
        end
    end

    function enemy:firePattern(pattern)
        -- Fresh positions at fire time — never cache through the wind-up
        local ex, ey = self.physics:getPosition()
        local px, py = player.collider:getPosition()
        local baseAngle = math.atan2(py - ey, px - ex)

        if pattern == "cone3" then
            -- Original 3-shot cone; kept byte-for-byte behavior (500px/s, 0.3 rad)
            local spread = 0.3
            for i = -1, 1 do
                local angle = baseAngle + (i * spread)
                local tx = ex + math.cos(angle) * 100
                local ty = ey + math.sin(angle) * 100
                spawnProjectile(ex, ey, tx, ty, 500, 1, "enemy")
            end

        elseif pattern == "cone5" then
            -- Step up on the same idea: 5 shots, tighter spacing, slightly
            -- slower than cone3 per shot but way more walls to slide through.
            -- Dodging stays possible: hold Shift perpendicular to the cone axis.
            local spread = 0.22
            for i = -2, 2 do
                local angle = baseAngle + (i * spread)
                local tx = ex + math.cos(angle) * 100
                local ty = ey + math.sin(angle) * 100
                spawnProjectile(ex, ey, tx, ty, 480, 1, "enemy")
            end

        elseif pattern == "homing" then
            -- Single slow chaser. 190px/s is SLOWER than the player's sprint
            -- (225) — the question isn't whether you can outrun it, it's whether
            -- you spend the dodge/shield on it or weave. Opt-in homing flag.
            -- The bolt inherits the shared homing rules: window, steering,
            -- and lock-break on player i-frames all come from HOMING_* setup
            -- in src/entities/projectile.lua.
            spawnProjectile(ex, ey, px, py, 190, 1, "enemy", true)

        elseif pattern == "spread" then
            -- Wide, moderately fast — punishes standing still in front of the
            -- boss; runs straight lines through its sides, easy to sidestep
            -- if you're already moving. Filler pressure between big moves.
            local spread = 0.5
            for i = -1, 1 do
                local angle = baseAngle + (i * spread)
                local tx = ex + math.cos(angle) * 100
                local ty = ey + math.sin(angle) * 100
                spawnProjectile(ex, ey, tx, ty, 340, 1, "enemy")
            end

        elseif pattern == "radial" then
            self:fireRadial()
        end
    end

    -- 360° ring of 8 shots at moderate speed. A random rotation offset per
    -- cast stops the pattern from being solvable by memory alone — you dodge
    -- by reading the telegraph, not by counting.
    function enemy:fireRadial()
        local ex, ey = self.physics:getPosition()
        local count = 8
        local offset = math.random() * math.pi
        for i = 0, count - 1 do
            local angle = offset + i * (math.pi * 2 / count)
            local tx = ex + math.cos(angle) * 100
            local ty = ey + math.sin(angle) * 100
            spawnProjectile(ex, ey, tx, ty, 260, 1, "enemy")
        end
    end

    function enemy:update(dt)
        enemy:moveLogic(dt)
        self:setScaleX()

        -- PHASE TRANSITION: exactly once, at half health. Fires a radial burst
        -- immediately — no telegraph — because the burst IS the announcement:
        -- "phase 2, act accordingly." The attacks below take it from there.
        if self.phase == 1 and self.health <= self.maxHealth * 0.5 then
            self.phase = 2
            self.patternIndex = 1  -- rotation starts on "cone5" next cast
            self:fireRadial()
            -- Phase 2 movement: slightly faster stalk, still dodgeable.
            self.maxSpeed = 95
        end

        -- Cast machine (only when actively aggro'd, like the old shootTimer)
        if self.state >= 100 then
            if self.castTimer > 0 then
                -- WIND-UP: tick the telegraph down; pattern fires at zero.
                self.castTimer = self.castTimer - dt
                if self.castTimer <= 0 then
                    self:firePattern(self.castPattern)
                    self.castPattern = nil
                    -- Hand the sprite back to the walk set after casting
                    self.anim = self.animations.walk
                    self.shootTimer = 0
                end
            else
                -- IDLE BETWEEN CASTS: count down to the next telegraph using
                -- the CURRENT pattern's pacing (phase 1: fixed cone3 cooldown).
                self.shootTimer = self.shootTimer + dt
                local nextPattern = (self.phase == 1)
                    and "cone3"
                    or self.phase2Patterns[self.patternIndex]
                if self.shootTimer >= (PATTERN_COOLDOWNS[nextPattern] or 2.5) then
                    self:beginCast()
                end
            end
        end

        -- Light aura: flare while telegraphing (drawLighting reads
        -- self.lightRadius; nil = default ENEMY_LIGHT_RADIUS). Phase 2 keeps a
        -- slightly hotter resting aura as well — menace you can see in the dark.
        if self.castTimer > 0 then
            self.lightRadius = 110
        elseif self.phase == 2 then
            self.lightRadius = 80
        else
            self.lightRadius = nil
        end
    end

    function enemy:draw()
        local ex, ey = self.physics:getPosition()
        -- Phase 2 tint: enrage colors. Multiplying the sprite with a warm red
        -- is the cheapest possible "this thing changed" read; combined with the
        -- faster movement and burst-on-transition the fight turns somewhere
        -- between 1 and 2 hits in.
        if self.phase == 2 then
            love.graphics.setColor(1, 0.55, 0.55)
        end
        self.anim:draw(self.sprite, ex, ey-self.floatY, nil, math.abs(self.scaleX * 3), self.scaleY, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
    end

    function enemy:die()
    end
    return enemy

end


return bossInit
