-- TODO:
-- generate enemies

enemies = {}

-- Function to spawn enemy
function spawnEnemy(x, y, type, args)
    local enemy = {}
    enemy.type = type
    enemy.health = 3
    enemy.moving = 1
    enemy.dead = false
    enemy.chase = true

    enemy.dizzyTimer = 0
    enemy.animTimer = 0
    enemy.stunTimer = 0
    
    -- enemy state:
    -- 0: idle, standing
    -- 1: wander, stopped
    -- 1.1: wander, moving
    -- 99: alert
    -- 100: attacking

    enemy.state = 1

    enemy.startX = x
    enemy.startY = y
    enemy.wanderRadius = 30
    enemy.wanderSpeed  = 15
    enemy.wanderTimer = 0.5 + math.random() * 2
    enemy.wanderBufferTimer = 0
    enemy.wanderDir = vector(1, 1)

    local init
    if type == "bat" then
        init = require("src/enemies/bat")
    elseif type == "mage" then
        init = require("src/enemies/mage")
    elseif type == "boss" then
        init = require("src/enemies/boss")
    end

    enemy = init(enemy, x, y, args)

    function enemy:setScaleX()
        local px, py = player.collider:getPosition()
        local ex, ey = self.physics:getPosition()

        if self.state >= 99 then
            if px < ex then
                self.scaleX = -1
            else
                self.scaleX = 1
            end
        elseif self.state >= 1 and  self.state < 2 then
            if self.wanderDir.x < 0 then
                self.scaleX = -1
            else
                self.scaleX = 1
            end
        end
    end

    function enemy:lookForPlayer()
        -- check if enemy exists
        if self.physics == nil then return false end
        local ex = self.physics:getX()
        local ey = self.physics:getY()

        -- 'listening threshold'
        if distanceBetween(ex, ey, player.collider:getX(), player.collider:getY()) < 30 then
            return true
        end

        -- look at player if and only if enemy is facing player's direction
        if self.state >= 1 and self.state < 2 then
            if self.scaleX == 1 and ex > player.collider:getX() then return false end
            if self.scaleX == -1 and ex < player.collider:getX() then return false end
        end

        local toPlayerVec = getPlayerToSelfVector(ex, ey):rotateInplace(math.pi)

        -- line of queries towards the player

        for i=1,18 do
            local qRad = 3
            local qx = ex + toPlayerVec.x * i * qRad
            local qy = ey + toPlayerVec.y * i * qRad


            local hitPlayer = world:queryCircleArea(qx, qy, qRad, {'player'})
            if #hitPlayer > 0 then
                return true
            end

            local obstacles = world:queryCircleArea(qx, qy, qRad, {'wall'})
            if #obstacles > 0 then
                return false
            end
        end

        return false
    end
    
    function enemy:moveLogic(dt, stiff)

        if self.stunTimer > 0 then
            self.stunTimer = self.stunTimer - dt
        end
        if self.stunTimer < 0 then
            self.stunTimer = 0
            self.physics:setLinearVelocity(0, 0)
        end

        if self.dizzyTimer > 0 then
            self.dizzyTimer = self.dizzyTimer - dt
        end
        if self.dizzyTimer < 0 then
            self.dizzyTimer = 0
        end
        
        if self.stunTimer == 0 and self.dizzyTimer == 0 then
            self.anim:update(dt * self.moving)
            local px, py = player.collider:getPosition()
            local ex, ey = self.physics:getPosition()

            if self.state < 99 then
                if self:lookForPlayer() then
                    self.state = 99 -- alert
                    self.animTimer = 0.5
                end
            end

            if self.state >= 100 then
                self.dir = vector(px - ex, py - ey):normalized() * self.magnitude

                if self.chase then
                    if stiff then -- Stiff (grounded) movement
                        self.physics:setX(self.physics:getX() + self.dir.x * dt)
                        self.physics:setY(self.physics:getY() + self.dir.y * dt)
                    else -- Floaty movement
                        if distanceBetween(0, 0, self.physics:getLinearVelocity()) < self.maxSpeed then
                            self.physics:applyForce(self.dir:unpack())
                        end
                    end
                elseif self.aggro then
                    self:aggro(dt)
                end
            end
        end
    end

    function enemy:wanderUpdate(dt)
        if self.state < 1 or self.state >= 2 or self.dizzyTimer > 0 then return end
        if self.wanderTimer > 0 then self.wanderTimer = self.wanderTimer - dt end
        if self.wanderBufferTimer > 0 then self.wanderBufferTimer = self.wanderBufferTimer - dt end
        if self.wanderTimer < 0 then
            self.state = 1.1
            self.wanderTimer = 0

            local ex = self.physics:getX()
            local ey = self.physics:getY()

            if ex < self.startX and ey < self.startY then
                self.wanderDir = vector(0, 1)
            elseif ex > self.startX and ey < self.startY then
                self.wanderDir = vector(-1, 0)
            elseif ex < self.startX and ey > self.startY then
                self.wanderDir = vector(1, 0)
            else
                self.wanderDir = vector(0, -1)
            end

            self.wanderBufferTimer = 0.2
            self.wanderDir:rotateInplace(math.pi/-2 * math.random())
        end

        if self.state == 1.1 and self.physics then
            self.physics:setX(self.physics:getX() + self.wanderDir.x * self.wanderSpeed * dt)
            self.physics:setY(self.physics:getY() + self.wanderDir.y * self.wanderSpeed * dt)

            if distanceBetween(self.physics:getX(), self.physics:getY(), self.startX, self.startY) > self.wanderRadius and self.wanderBufferTimer <= 0 then
                self.state = 1
                self.wanderTimer = 1 + math.random(0.1, 0.8)
            end
        end
    end

    -- general update for all enemies
    function enemy:genericUpdate(dt)

        if self.animTimer > 0 then
            self.animTimer = self.animTimer - dt
            if self.animTimer < 0 then
                if self.state == 99 then self.state = 100 end -- Begin attacking
                self.animTimer = 0
            end
        end

        self:wanderUpdate(dt)
    end

    table.insert(enemies, enemy)
end

function enemies:update(dt)
    for i, e in ipairs(self) do
        e:update(dt)
        e:genericUpdate(dt)
    end
   
    -- remove dead enemies in reverse order
    for i=#enemies,1,-1 do
        if enemies[i].dead then
            if enemies[i].physics ~= nil then
                enemies[i].physics:destroy()
            end
            table.remove(enemies, i)
        end
    end
end

function enemies:draw()
    for i, e in ipairs(self) do
        e:draw()
    end
end
