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
end

function enemyUpdate(dt)
    enemy.anim:update(dt)
end

function drawEnemy()
    local px, py = enemy.x, enemy.y
    enemy.anim:draw(enemy.sprite_sheet, px, py, nil, 1.5, nil, 12, 16)
end

function chase()
    -- when in range
    -- enemy should pursue player
end
