camera = require('libraries/camera')
cam = camera()

function cameraUpdate(dt)
    player.x = player.collider:getX()
    player.y = player.collider:getY()


    cam:lookAt(player.x, player.y)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local mapW = gameMap.width * gameMap.tilewidth
    local mapH = gameMap.height * gameMap.tileheight
    if cam.x < w / 2 then
        cam.x = w / 2
    end
    if cam.y < h / 2 then
        cam.y = h / 2
    end
    -- Right border
    if cam.x > (mapW - w / 2) then
        cam.x = (mapW - w / 2)
    end
    -- Bottom border
    if cam.y > (mapH - h / 2) then
        cam.y = (mapH - h / 2)
    end
end
