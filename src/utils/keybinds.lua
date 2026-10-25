-- KEYBINDS ---------------------------------------------------------------------------
-- Every player action goes through this module instead of hard-coded
-- love.keyboard.isDown("x") calls, which is what makes the options screen
-- rebinding possible at all.
--
-- Actions are declared in .registry (render order for the options screen,
-- with human labels and default keys); .actions holds the LIVE binding per
-- action (supports 1..n keys per action, though rebinding always sets one).
-- Bindings persist across restarts via a small Lua file in the save dir.

keybinds = {}

local unpackList = unpack or table.unpack  -- Lua 5.1/LuaJIT vs 5.2+

-- Ordered action registry: options screen shows them top-to-bottom in this
-- order. add an entry here and it appears in options + works everywhere.
keybinds.registry = {
    { id = "moveUp",    label = "Move Up",      default = { "w" } },
    { id = "moveDown",  label = "Move Down",    default = { "s" } },
    { id = "moveLeft",  label = "Move Left",    default = { "a" } },
    { id = "moveRight", label = "Move Right",   default = { "d" } },
    { id = "attack",    label = "Melee Attack", default = { "space" } },
    { id = "fire",      label = "Fire Spell",   default = { "x" } },
    { id = "dodge",     label = "Dodge Dash",   default = { "c" } },
    { id = "shield",    label = "Shield",       default = { "e" } },
    { id = "sprint",    label = "Sprint",       default = { "lshift" } },
}

keybinds.actions = {}  -- id -> { keys = { "w" } } after init()

-- Arrow keys stay as fixed, always-on fallbacks for movement regardless of
-- rebinding — a mover never gets locked out because they rebound W to K.
-- (Gameplay actions attack/fire/dodge/shield have NO fallbacks: the arrows
-- don't cast spells.)
local MOVE_FALLBACKS = {
    moveUp    = "up",
    moveDown  = "down",
    moveLeft  = "left",
    moveRight = "right",
}

function keybinds:init()
    self.actions = {}
    for _, def in ipairs(self.registry) do
        self.actions[def.id] = { keys = { unpackList(def.default) } }
    end
    -- Try saved settings; if none exist yet, write the defaults so the file
    -- is there and editable by hand too.
    if not self:load() then
        self:save()
    end
end

-- Any bound key currently held? (movement/hold-to-fire queries use this)
function keybinds:isDown(action)
    local bind = self.actions[action]
    if not bind then return false end
    for _, k in ipairs(bind.keys) do
        if love.keyboard.isDown(k) then return true end
    end
    local fallback = MOVE_FALLBACKS[action]
    if fallback and love.keyboard.isDown(fallback) then return true end
    return false
end

-- Was THIS specific key just pressed and bound to this action?
-- (love.keypressed handlers use this)
function keybinds:keyMatches(action, key)
    local bind = self.actions[action]
    if not bind then return false end
    for _, k in ipairs(bind.keys) do
        if k == key then return true end
    end
    return false
end

-- Rebind an action to a single new key and persist immediately.
function keybinds:setBinding(action, key)
    local bind = self.actions[action]
    if not bind then return end
    bind.keys = { key }
    self:save()
end

function keybinds:resetDefaults()
    for _, def in ipairs(self.registry) do
        self.actions[def.id].keys = { unpackList(def.default) }
    end
    self:save()
end

-- Pleasant key names for the HUD/options ("space" -> "Space")
local PRETTY = {
    space  = "Space",
    ["return"] = "Enter",
    lshift = "L-Shift", rshift = "R-Shift",
    lctrl  = "L-Ctrl",  rctrl  = "R-Ctrl",
    lalt   = "L-Alt",   ralt   = "R-Alt",
    tab    = "Tab",
}

function keybinds:prettyKey(k)
    return PRETTY[k] or k:upper()
end

function keybinds:keyLabel(action)
    local bind = self.actions[action]
    if not bind or #bind.keys == 0 then return "?" end
    local names = {}
    for _, k in ipairs(bind.keys) do
        table.insert(names, self:prettyKey(k))
    end
    return table.concat(names, " / ")
end

--------------------------------------------------------------------------------
-- PERSISTENCE: settings.lua in the love save directory, format:
--   return { attack = { keys = { "space" } }, ... }
-- Written on every binding change; read once at init.
--------------------------------------------------------------------------------

local SETTINGS_FILE = "settings.lua"

function keybinds:save()
    local rows = {}
    for _, def in ipairs(self.registry) do
        local keys = {}
        for _, k in ipairs(self.actions[def.id].keys) do
            table.insert(keys, string.format('"%s"', tostring(k)))
        end
        table.insert(rows, string.format('  %s = { keys = { %s } },',
            def.id, table.concat(keys, ", ")))
    end
    love.filesystem.write(SETTINGS_FILE,
        "return {\n" .. table.concat(rows, "\n") .. "\n}\n")
end

function keybinds:load()
    if not love.filesystem.getInfo(SETTINGS_FILE) then return false end
    local chunk = love.filesystem.load(SETTINGS_FILE)
    if not chunk then return false end

    -- Everything is validated: unknown ids skipped, non-string keys dropped,
    -- empty/missing bindings fall back to defaults. Hand-edited junk can't
    -- wedge the input system.
    local ok, data = pcall(chunk())
    if not ok or type(data) ~= "table" then return false end

    for _, def in ipairs(self.registry) do
        local saved = data[def.id]
        if type(saved) == "table" and type(saved.keys) == "table"
           and #saved.keys > 0 and type(saved.keys[1]) == "string" then
            local keys = {}
            for _, k in ipairs(saved.keys) do
                table.insert(keys, tostring(k))
            end
            self.actions[def.id].keys = keys
        end
    end
    return true
end
