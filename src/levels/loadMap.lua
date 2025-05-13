function loadMap(mapName, destX, destY)

    if destX and destY then
        player:setPosition(destX, destY)
    end

    loadedMap = mapName
    gameMap = sti("assets/maps/" .. mapName .. ".lua")

    if gameMap.layers["enemies"] then
        for _, obj in pairs(gameMap.layers["enemies"].objects) do
            local args = {}
            if obj.properties.form then args.form = obj.properties.form end
            -- print(obj.name)
            spawnEnemy(obj.x, obj.y, obj.name, args)
        end
    end
    
    walls = {}
    if gameMap.layers["wall"] then
        for i, obj in pairs(gameMap.layers["wall"].objects) do
            local wall = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            wall:setType("static")
            table.insert(walls, wall)
        end
    end

    --if gameMap.layers["chests"] then
        --for _, obj in pairs(gameMap.layers["chests"].objects) do
            --spawnChest(obj.x, obj.y, obj.name, obj.type)
        --end
    --end
end
