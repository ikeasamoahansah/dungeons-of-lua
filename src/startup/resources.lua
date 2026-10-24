sprites = {}

sprites.enemies = {}
sprites.effects = {}

-- player
sprites.playerSheet = love.graphics.newImage('assets/sprites/player/Fumiko.png')

-- enemies
sprites.enemies.bat = love.graphics.newImage('assets/sprites/enemies/bat.png')
sprites.enemies.mage = love.graphics.newImage('assets/sprites/enemies/mage.png')
sprites.enemies.boss = love.graphics.newImage('assets/sprites/enemies/boss.png')

-- shaders: the vignette darkens screen corners (screen space), the lighting
-- shader is the dungeon darkness/light-pool pass drawn in world space by
-- drawLighting() in src/draw.lua.
shaders = {}
shaders.vignette = love.graphics.newShader('assets/shaders/vignette.glsl')
shaders.lighting = love.graphics.newShader('assets/shaders/lighting.glsl')

-- fonts
fonts = {}
fonts.large = love.graphics.newFont(48)
fonts.medium = love.graphics.newFont(24)