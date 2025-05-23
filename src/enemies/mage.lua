local function mageInit(enemy, x, y, args)
    enemy.physics = world:newBSGRectangleCollider(x, y, 12, 16, 3)
    enemy.physics:setFixedRotation(true)
    enemy.physics:setMass(1)
    enemy.physics:setLinearDamping(2)
    enemy.physics.parent = enemy

    enemy.form = 1
    enemy.sprite = sprites.enemies.mage

    if args and args.form ~= nil then
        enemy.form = args.form
    end

    enemy.health = 1
    enemy.speed = 2
    enemy.maxSpeed = 80
    enemy.magnitude = 450
    enemy.dir = vector(0, 1)
    enemy.viewDistance = 100

    enemy.grid = anim8.newGrid(20, 24, enemy.sprite:getWidth(), enemy.sprite:getHeight())
    enemy.animations = {}
    
    enemy.animations.walk = anim8.newAnimation(enemy.grid('1-2', 1), 0.4)

    if enemy.form == 2 then
        enemy.animations.staff = anim8.newAnimation(enemy.grid(3, 1), 1)
    end

    enemy.anim = enemy.animations.walk

    enemy.floatTime = 0.5
    enemy.floatY = 0
    enemy.floatMax = 1.5

    enemy.scaleX = 1
    enemy.scaleY = 1.5
    -- if math.random() < 0.5 then enemy.scaleX = -1 end

    function enemy:update(dt)
        enemy:moveLogic(dt)
        local px, py = player.collider:getPosition()
        local ex, ey = self.physics:getPosition()
        self:setScaleX()
    end

    function enemy:draw()
        local ex, ey = self.physics:getPosition()
        self.anim:draw(self.sprite, ex, ey-self.floatY, nil, math.abs(self.scaleX * 2.5), self.scaleY, 8, 8)
    end

    function enemy:die()
    end
    return enemy

end


return mageInit