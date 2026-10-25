local function batInit(enemy, x, y, args)
    enemy.physics = world:newBSGRectangleCollider(x, y, 11, 9, 1)
    enemy.physics:setFixedRotation(true)
    enemy.physics:setMass(1)
    enemy.physics:setLinearDamping(2)
    enemy.physics.parent = enemy

    enemy.form = 1
    enemy.sprite = sprites.enemies.bat

    if args and args.form ~= nil then
        enemy.form = args.form
    end

    enemy.health = 1
    enemy.maxHealth = 1

    enemy.speed = 3
    enemy.maxSpeed = 80
    enemy.magnitude = 450
    enemy.dir = vector(0, 1)

    -- Line of sight runs 20px further than the standard 150 (mage/boss).
    enemy.viewDistance = 170

    enemy.grid = anim8.newGrid(16, 16, enemy.sprite:getWidth(), enemy.sprite:getHeight())
    enemy.anim = anim8.newAnimation(enemy.grid('1-2', 1), 0.15)

    enemy.floatTime = 0.5
    enemy.floatY = 0
    enemy.floatMax = 1.5

    enemy.scaleX = 1
    enemy.scaleY = 1
    -- if math.random() < 0.5 then enemy.scaleX = -1 end

    -- CHARGE ATTACK (the bat's flash step) ------------------------------------------------
    -- When a bat locks on it STOPS, telegraphs a windup, then rockets straight at the
    -- player's position — accelerate like the player's own dodge, and dodgeable for the
    -- same reason: the dash vector is locked at LAUNCH (end of windup), so any move you
    -- make during the telegraph beats it.
    -- Pacing mirrors the player's tools: 0.55s windup (flash step deny blink territory)
    -- and a 2.5s cycle (longer than flash step's ~2s full cycle — the bat has no other
    -- threat, so its one trick gets a stricter cooldown).
    enemy.chargePhase        = nil   -- nil: normal AI | "windup" | "dashing" | "recover"
    enemy.chargeTimer        = 0     -- countdown of the current phase
    enemy.chargeWindup       = 0.55  -- standing still, rings closing in — the dodge tell
    enemy.chargeDashTime     = 0.45  -- ~150px of travel at the dash speed
    enemy.chargeRecover      = 0.35  -- brief drift after a dash before normal chase resumes
    enemy.chargeCooldownMax  = 2.5   -- time between charge attempts
    enemy.chargeCooldown     = 0     -- ready on spawn
    enemy.chargeSpeed        = 330   -- far above the 80 chase cap; the "accelerate" bit
    enemy.chargeTriggerRange = 280   -- max range to start a charge (its LOS reach)
    enemy.chargeMinRange     = 60    -- closer than this: just touch for damage, no charge
    enemy.chargeDirX         = 0
    enemy.chargeDirY         = 0
    enemy.shieldBounceCooldown = 0  -- throttles shield-rim bounce checks

    -- Shield ricochet: the orb is solid to bats. Contact with the rim reflects
    -- the bat's velocity outward (no meter cost to the player — a bounce is
    -- a "blocked with a shove", not an absorbed bite). A dash that connects
    -- with the shield ends right there and pays a full cooldown like a boop.
    function enemy:bounceOffShield()
        local px, py = player.x, player.y
        local ex, ey = self.physics:getPosition()
        local dx, dy = ex - px, ey - py
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= 0 or self.shieldBounceCooldown > 0 then return end

        local nx, ny = dx / dist, dy / dist  -- shield-rim outward normal
        local vx, vy = self.physics:getLinearVelocity()

        -- Only bounce when actually heading INTO the shield, not when already
        -- sliding away from it.
        local dot = vx * nx + vy * ny
        if dot >= 0 then return end

        local vxr, vyr = vx - 2 * dot * nx, vy - 2 * dot * ny
        local bounce = 0.6  -- not a full elastic: heavy dampened knockback
        self.physics:setLinearVelocity(vxr * bounce, vyr * bounce)

        -- Lift the collider clear of the rim so the overlap resolves clean
        -- and one contact = exactly one bounce.
        self.physics:setPosition(px + nx * (player.shieldRadius + 8), py + ny * (player.shieldRadius + 8))
        self.shieldBounceCooldown = 0.4

        -- A interrupted dash counts as a fully denied charge.
        if self.chargePhase then
            self.chargePhase = nil
            self.chargeTimer = 0
            self.lightRadius = nil
            self.chargeCooldown = self.chargeCooldownMax
        end
    end

    function enemy:beginCharge()
        self.chargePhase = "windup"
        self.chargeTimer = self.chargeWindup
        -- Hard stop: the whole "spot -> stop -> charge" read depends on this canceling
        -- the drifty floaty movement dead in its tracks.
        self.physics:setLinearVelocity(0, 0)
    end

    function enemy:updateCharge(dt)
        self.anim:update(dt)
        self.chargeTimer = self.chargeTimer - dt

        if self.chargePhase == "windup" then
            -- Pinned in place through the whole tell (damping can't start it drifting).
            self.physics:setLinearVelocity(0, 0)

            if self.chargeTimer <= 0 then
                -- Lock the dash vector HERE, at launch — never at trigger. The windup
                -- is the dodge window: move during it and the bat commits to where
                -- you WERE.
                local px, py = player.collider:getPosition()
                local ex, ey = self.physics:getPosition()
                local dx, dy = px - ex, py - ey
                local len = math.sqrt(dx * dx + dy * dy)

                if len < self.chargeMinRange then
                    -- Player walked inside the min range during the windup: charge
                    -- collapses into its recover phase, normal AI takes over.
                    self.chargePhase = "recover"
                    self.chargeTimer = self.chargeRecover
                elseif len > 0 then
                    self.chargeDirX = dx / len
                    self.chargeDirY = dy / len
                    self.physics:setLinearVelocity(self.chargeDirX * self.chargeSpeed, self.chargeDirY * self.chargeSpeed)
                    self.chargePhase = "dashing"
                    self.chargeTimer = self.chargeDashTime
                else
                    self.chargePhase = "recover"
                    self.chargeTimer = self.chargeRecover
                end
            end

        elseif self.chargePhase == "dashing" then
            -- Re-write velocity every frame: linearDamping(2) would otherwise bleed
            -- speed off mid-dash and ruin the constant "accelerated" feel.
            self.physics:setLinearVelocity(self.chargeDirX * self.chargeSpeed, self.chargeDirY * self.chargeSpeed)

            -- Contact damage mid-dash, same touch range (<30) as normal chase.
            -- Repeated hits are already throttled on the player's side
            -- (invincibleTimer for HP, shieldAbsorbCooldown for the orb).
            if self.chargeHitCooldown and self.chargeHitCooldown > 0 then
                self.chargeHitCooldown = self.chargeHitCooldown - dt
            else
                local px, py = player.collider:getPosition()
                local ex, ey = self.physics:getPosition()
                if distanceBetween(ex, ey, px, py) < 30 and player.takeDamage then
                    player:takeDamage(1)
                    self.chargeHitCooldown = 0.3
                end
            end

            if self.chargeTimer <= 0 then
                self.chargePhase = "recover"
                self.chargeTimer = self.chargeRecover
            end

        elseif self.chargePhase == "recover" then
            if self.chargeTimer <= 0 then
                self.chargePhase = nil
                self.chargeTimer = 0
                self.lightRadius = nil
                self.chargeCooldown = self.chargeCooldownMax
            end
        end
    end

    function enemy:update(dt)
        local ex, ey = self.physics:getPosition()

        -- Recharge meter — only ticks while NOT mid-phase (dodge window excluded), so
        -- a recover counts toward downtime like the player's dash regen delay.
        if self.chargePhase == nil and self.chargeCooldown > 0 then
            self.chargeCooldown = math.max(0, self.chargeCooldown - dt)
        end
        if self.shieldBounceCooldown > 0 then
            self.shieldBounceCooldown = math.max(0, self.shieldBounceCooldown - dt)
        end

        -- The orb is a wall the bat sees, too: any inward contact with the rim
        -- ricochets it away (and ends an interrupted dash).
        if player.shieldActive then
            self:bounceOffShield()
        end

        -- Getting booped mid-charge (fire bolt knockback sets stunTimer) cancels it:
        -- debt paid via a full cooldown, exactly like a denied player dash.
        if self.chargePhase and self.stunTimer > 0 then
            self.chargePhase = nil
            self.chargeTimer = 0
            self.lightRadius = nil
            self.chargeCooldown = self.chargeCooldownMax
        end

        if self.chargePhase then
            self:updateCharge(dt)
        else
            -- Normal bat AI (original behavior, untouched).
            enemy:moveLogic(dt)

            -- While actively hunting (state >= 100) and off cooldown, look for a
            -- clean lane at charge range: nothing between here and the player.
            if self.state >= 100
               and self.stunTimer <= 0 and self.dizzyTimer <= 0
               and self.chargeCooldown <= 0 then
                local pxw, pyw = player.collider:getPosition()
                local dist = distanceBetween(ex, ey, pxw, pyw)

                if dist < self.chargeTriggerRange and dist > self.chargeMinRange then
                    if #world:queryLine(ex, ey, pxw, pyw, {'wall'}) == 0 then
                        self:beginCharge()
                    end
                end
            end
        end

        -- Telegraph glow for drawLighting: a flare right before/during the dash
        -- announces the threat through the dark (same trick as the boss cast).
        if self.chargePhase then
            self.lightRadius = 85
        end

        self:setScaleX()
    end

    function enemy:draw()
        local ex, ey = self.physics:getPosition()

        -- Telegraphs and dash ghosts only ever draw while alive.
        if not self.dead then
        -- Charge telegraph: closing red rings through the windup window. Rings
        -- tightening ONTO the bat read as "it's about to launch" — the fill gets
        -- hotter as the window runs out.
        if self.chargePhase == "windup" then
            local p = 1 - self.chargeTimer / self.chargeWindup  -- 0..1 across the tell
            love.graphics.setColor(1, 0.2, 0.25, 0.2 + 0.3 * p)
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", ex, ey - self.floatY, 18)
            love.graphics.setColor(1, 0.2, 0.25, 0.15 + 0.25 * p)
            love.graphics.circle("fill", ex, ey - self.floatY, 6 + 8 * p)
        end

        -- Dash streaks: reverse-ghost copies of the sprite trailing behind along
        -- the charge vector — the blur sells the acceleration.
        if self.chargePhase == "dashing" then
            for i = 1, 3 do
                local off = i * 9
                love.graphics.setColor(1, 0.3, 0.45, 0.45 - 0.13 * i)
                self.anim:draw(
                    self.sprite,
                    ex - self.chargeDirX * off,
                    ey - self.floatY - self.chargeDirY * off,
                    nil,
                    math.abs(self.scaleX * 3),
                    self.scaleY,
                    8, 8
                )
            end
            love.graphics.setColor(1, 1, 1, 1)
        end
        end

        self.anim:draw(self.sprite, ex, ey-self.floatY, nil, math.abs(self.scaleX * 3), self.scaleY, 8, 8)
    end

    function enemy:die()
    end
    return enemy
end

return batInit
