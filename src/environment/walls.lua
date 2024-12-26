walls = {}

function wallInit()
    if gameMap.layers["walls"] then
        for i, obj in pairs(gameMap.layers["walls"].objects) do
            local wall = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            wall:setType("static")
            table.insert(walls, wall)
        end
    end
end

return wallInit()
