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

    enemy.health = 1
    enemy.speed = 1
    enemy.maxSpeed = 80
    enemy.magnitude = 450
    enemy.dir = vector(0, 1)
    enemy.viewDistance = 150

    enemy.grid = anim8.newGrid(20, 20, enemy.sprite:getWidth(), enemy.sprite:getHeight())    
    enemy.anim = anim8.newAnimation(enemy.grid('1-2', 1), 0.3)

    if enemy.form == 2 then
        enemy.animations.staff = anim8.newAnimation(enemy.grid(3, 1), 1)
    end

    enemy.floatTime = 0.5
    enemy.floatY = 0
    enemy.floatMax = 1.5

    enemy.scaleX = 1
    enemy.scaleY = 1.5
    -- if math.random() < 0.5 then enemy.scaleX = -1 end

    enemy.shootTimer = 0
    enemy.shootCooldown = 2.5 -- seconds between shots

    function enemy:update(dt)
        enemy:moveLogic(dt)
        local px, py = player.collider:getPosition()
        local ex, ey = self.physics:getPosition()
        self:setScaleX()

        if self.state >= 100 then
            self.shootTimer = self.shootTimer + dt
            if self.shootTimer >= self.shootCooldown then
                self.shootTimer = 0
    
                -- Spread shot: 3 projectiles in a cone
                local baseAngle = math.atan2(py - ey, px - ex)
                local spread = 0.3  -- radians between shots
                for i = -1, 1 do
                    local angle = baseAngle + (i * spread)
                    local tx = ex + math.cos(angle) * 100
                    local ty = ey + math.sin(angle) * 100
                    spawnProjectile(ex, ey, tx, ty, 500, 1, "enemy")
                end
            end
        end
    end

    function enemy:draw()
        local ex, ey = self.physics:getPosition()
        self.anim:draw(self.sprite, ex, ey-self.floatY, nil, math.abs(self.scaleX * 3), self.scaleY, 8, 8)
    end

    function enemy:die()
    end
    return enemy

end


return bossInit