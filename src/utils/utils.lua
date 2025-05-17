-- Utilities class

function distanceBetween(x1, y1, x2, y2)
    return math.sqrt( (x2 - x1)^2 + (y2 - y1)^2 )
end

function getPlayerToSelfVector(x, y)
    return vector(x - player.collider:getX(), y - player.collider:getY()):normalized()
end