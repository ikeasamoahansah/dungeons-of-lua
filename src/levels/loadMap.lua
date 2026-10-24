-- MINIMAP: the dungeon layout is pre-rendered ONCE per map load onto an
-- offscreen canvas; the HUD then just stamps live markers (player, enemies)
-- onto it every frame — one canvas draw + a few dots, near-zero per-frame cost.
-- The canvas pixel size per tile is fixed, world->canvas conversion uses the
-- map's own tile size so a different tile size still lands dots correctly.
minimapCanvas = nil
MINIMAP_TILE_PX = 4  -- 4 canvas px per tile -> 120x120 canvas for the 30x30 map

function buildMinimap()
    local mapW = gameMap.width   -- tiles across
    local mapH = gameMap.height  -- tiles down

    minimapCanvas = love.graphics.newCanvas(mapW * MINIMAP_TILE_PX, mapH * MINIMAP_TILE_PX)

    love.graphics.setCanvas(minimapCanvas)
    love.graphics.clear()  -- transparent start: unexplored/void stays see-through

    -- Layer colors: dim floor, brighter bricks — walls read as structure.
    -- base_wall is drawn ON TOP of floor where both exist, since walls
    -- occlude the ground.
    local layers = {
        { name = "floor",     r = 0.20, g = 0.18, b = 0.24 },
        { name = "base_wall", r = 0.50, g = 0.47, b = 0.55 },
    }

    for _, layerInfo in ipairs(layers) do
        local layer = gameMap.layers[layerInfo.name]
        if layer and layer.data then
            love.graphics.setColor(layerInfo.r, layerInfo.g, layerInfo.b)
            for y = 1, mapH do
                local row = layer.data[y]
                if row then
                    for x = 1, mapW do
                        -- STI stores a tile table where a tile exists, nil
                        -- where it doesn't — existence is all we need here.
                        if row[x] then
                            love.graphics.rectangle("fill",
                                (x - 1) * MINIMAP_TILE_PX,
                                (y - 1) * MINIMAP_TILE_PX,
                                MINIMAP_TILE_PX, MINIMAP_TILE_PX)
                        end
                    end
                end
            end
        end
    end

    love.graphics.setCanvas()
end

function loadMap(mapName, destX, destY)

    if destX and destY then
        player:setPosition(destX, destY)
    end

    loadedMap = mapName
    gameMap = sti("assets/maps/" .. mapName .. ".lua")

    -- Minimap rebuild must come after gameMap exists; it only needs the
    -- tile layers, so enemy/wall spawning below can proceed regardless.
    buildMinimap()

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
            wall:setCollisionClass("wall")
            table.insert(walls, wall)
        end
    end

    --if gameMap.layers["chests"] then
        --for _, obj in pairs(gameMap.layers["chests"].objects) do
            --spawnChest(obj.x, obj.y, obj.name, obj.type)
        --end
    --end
end
