enemy = {}
enemy.x = 0
enemy.y = 0
enemy.speed = 300
enemy.sprite_sheet = love.graphics.newImage('assets/sprites/mage_outline.png')
enemy.seen_player = false


-- function hapazard()
--     local vx, vy = 0, 0
--     vy = player.speed


--     enemy.collider:setLinearVelocity(vx, vy)
-- end


function enemyUpdate(dt)
    --if enemy.seen_player == false then
    --    hapazard()
    --end
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
