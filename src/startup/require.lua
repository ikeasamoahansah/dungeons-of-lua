function requireAll()
    require('src/startup/resources')
    require('src/sounds/sound')
    
    require('src/utils/cam')
    require('src/utils/utils')

    require('src/levels/loadMap')

    require('src/enemies/enemy')

    require('src/player')
    require('src/update')
    require('src/draw')
end
