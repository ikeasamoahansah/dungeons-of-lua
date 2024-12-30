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
    enemy.startX = x
    enemy.startY = y

    local init
    if type == "bat" then
        init = require("src/enemies/bat")
    elseif type == "mage" then
        init = require("src/enemies/mage")
    elseif type == "boss" then
        init = require("src/enemies/boss")
    end

    enemy = init(enemy, x, y, args)
end

function enemyUpdate(dt)
    for i, e in ipairs(self) do
        e:update(dt)
    end
end

function drawEnemy()
end

