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
    enemy.speed = 0
    enemy.maxSpeed = 80
    enemy.magnitude = 450
    enemy.dir = vector(0, 1)
    enemy.viewDistance = 100

    enemy.grid = anim8.newGrid(16, 16, enemy.sprite:getWidth(), enemy.sprite:getHeight())
    enemy.anim = anim8.newAnimation(enemy.grid('1-2', 1), 0.15)

    enemy.floatTime = 0.5
    enemy.floatY = 0
    enemy.floatMax = 1.5

    enemy.scaleX = 3
    enemy.scaleY = 1
    -- if math.random() < 0.5 then enemy.scaleX = -1 end

    function enemy:update(dt)
        enemy:moveLogic(dt)
        local px, py = player.collider:getPosition()
        local ex, ey = self.physics:getPosition()
        self:setScaleX()
    end

    function enemy:draw()
        local ex, ey = self.physics:getPosition()
        self.anim:draw(self.sprite, ex, ey-self.floatY, nil, self.scaleX, self.scaleY, 8, 8)
    end

    function enemy:die()
    end
    return enemy
end

return batInit
