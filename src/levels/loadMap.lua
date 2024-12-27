function loadMap(mapName, destX, destY)

    if destX and destY then
        player:setPosition(destX, destY)
    end

    loadedMap = mapName
    gameMap = sti("maps/" .. mapName .. ".lua")

    if gameMap.layers["enemies"] then
        for _, obj in pairs(gameMap.layers["enemies"].objects) do
            local args = {}
            if obj.properties.form then args.form = obj.properties.form end
            spawnEnemy(obj.x, obj.y, obj.name, args)
        end
    end

    if gameMap.layers["chests"] then
        for _, obj in pairs(gameMap.layers["chests"].objects) do
            spawnChest(obj.x, obj.y, obj.name, obj.type)
        end
    end
end
