-- MENU ---------------------------------------------------------------------------
-- Boot menu + options/rebinding screens, keyboard-navigated (Up/Down/W/S to
-- move, Enter to confirm, Esc to back out). Lives in gameState 0: while here
-- the world is NOT updated at all (updateGame refuses non-1 states) — it's a
-- real pause, not a soft one.
--
-- Modes: "main" -> "options" -> "rebind" (waiting for a new key).
-- Esc behavior per mode: main = quit, options = back to main, rebind = cancel.

menu = {}
menu.mode = "main"          -- main | options | rebind
menu.selected = 1           -- cursor index in the current mode's list
menu.optionSelected = 1
menu.rebindAction = nil     -- action id while in "rebind" mode
menu.runStarted = false     -- true after first Start: enables Resume + translucent pause look
menu.flashTimer = 0         -- seconds left on the options flash message
menu.flashText = ""

local MENU_ITEMS = {
    { id = "start",   label = "Start Game" },
    { id = "options", label = "Options" },
    { id = "exit",    label = "Exit" },
}

-- Options rows: every registry action (rebindable) + reset defaults + back.
local function optionRows()
    local rows = {}
    for _, def in ipairs(keybinds.registry) do
        table.insert(rows, { type = "bind", id = def.id, label = def.label })
    end
    table.insert(rows, { type = "reset", label = "Reset Defaults" })
    table.insert(rows, { type = "back",  label = "Back" })
    return rows
end

function menu:enter()
    self.mode = "main"
    self.selected = 1
    self.optionSelected = 1
    self.rebindAction = nil
    self.flashTimer = 0
end

function menu:update(dt)
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
    end
end

--------------------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------------------

function menu:keypressed(key)
    if self.mode == "rebind" then
        return self:keypressedRebind(key)
    elseif self.mode == "main" then
        return self:keypressedMain(key)
    elseif self.mode == "options" then
        return self:keypressedOptions(key)
    end
end

function menu:keypressedRebind(key)
    -- Esc cancels; any other key becomes the new binding and persists.
    if key == "escape" then
        self.mode = "options"
        self.rebindAction = nil
        return
    end
    keybinds:setBinding(self.rebindAction, key)
    self.rebindAction = nil
    self.mode = "options"
end

function menu:keypressedMain(key)
    local count = #MENU_ITEMS
    if key == "up" or key == "w" then
        self.selected = ((self.selected - 2 + count) % count) + 1
    elseif key == "down" or key == "s" then
        self.selected = (self.selected % count) + 1
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:activate(MENU_ITEMS[self.selected].id)
    elseif key == "escape" then
        love.event.quit()
    end
end

function menu:keypressedOptions(key)
    local rows = optionRows()
    local count = #rows
    if key == "up" or key == "w" then
        self.optionSelected = ((self.optionSelected - 2 + count) % count) + 1
    elseif key == "down" or key == "s" then
        self.optionSelected = (self.optionSelected % count) + 1
    elseif key == "return" or key == "kpenter" or key == "space" then
        local row = rows[self.optionSelected]
        if row.type == "bind" then
            self.rebindAction = row.id
            self.mode = "rebind"
        elseif row.type == "reset" then
            keybinds:resetDefaults()
            self.flashText = "Keybindings restored to defaults"
            self.flashTimer = 2
        elseif row.type == "back" then
            self.mode = "main"
            self.selected = 1
        end
    elseif key == "escape" then
        self.mode = "main"
        self.selected = 1
    end
end

function menu:activate(id)
    if id == "start" then
        -- First start OR resume-from-pause land here; the world is already
        -- loaded behind the menu, "starting" just unfreezes it.
        self.runStarted = true
        gameState = 1
    elseif id == "options" then
        self.mode = "options"
        self.optionSelected = 1
    elseif id == "exit" then
        love.event.quit()
    end
end

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------

function menu:draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- Backdrop: opaque night-blue before any run exists; when paused out of a
    -- live run, go translucent so the frozen world stays faintly visible.
    if self.runStarted then
        love.graphics.setColor(0, 0, 0, 0.75)
    else
        love.graphics.setColor(0.05, 0.04, 0.08, 1)
    end
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Title (main menu only — options/rebind screens paint their own headers)
    if self.mode == "main" then
        love.graphics.setFont(fonts.large)
        love.graphics.setColor(1, 0.85, 0.7, 1)
        love.graphics.printf("DUNGEONS", 0, h * 0.16, w, "center")
    end

    if self.mode == "main" then
        self:drawMain(w, h)
    elseif self.mode == "options" then
        self:drawOptions(w, h)
    else
        self:drawRebindPrompt(w, h)
    end

    love.graphics.setFont(love.graphics.getFont())
    love.graphics.setColor(1, 1, 1, 1)
end

function menu:drawMain(w, h)
    love.graphics.setFont(fonts.medium)
    local y = h * 0.45
    for i, item in ipairs(MENU_ITEMS) do
        local label = item.label
        if item.id == "start" and self.runStarted then
            label = "Resume"
        end
        if i == self.selected then
            love.graphics.setColor(1, 0.95, 0.8, 1)
            love.graphics.print("> " .. label, w * 0.42 - 90, y)
        else
            love.graphics.setColor(0.65, 0.65, 0.72, 1)
            love.graphics.print(label, w * 0.42 - 75, y)
        end
        y = y + 34
    end

    love.graphics.setFont(love.graphics.getFont())
    love.graphics.setColor(0.5, 0.5, 0.58, 1)
    love.graphics.printf("Up/Down: move     Enter: select     Esc: quit", 0, h - 40, w, "center")
end

function menu:drawOptions(w, h)
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 0.95, 0.8, 1)
    love.graphics.printf("OPTIONS", 0, h * 0.14, w, "center")

    local rows = optionRows()
    local leftX = w * 0.5 - 130
    local keyX  = w * 0.5 + 120
    -- 11 rows must fit between the header and the bottom hint line at
    -- 640x480-ish window sizes: 32px spacing overruns into the hint, 26 fits.
    local spacing = 26
    local y = h * 0.24

    for i, row in ipairs(rows) do
        local isSel = (i == self.optionSelected)
        if isSel then
            love.graphics.setColor(1, 0.95, 0.8, 1)
        else
            love.graphics.setColor(0.65, 0.65, 0.72, 1)
        end

        if row.type == "bind" then
            love.graphics.print(row.label, leftX - 15, y)
            -- Current binding, right column
            love.graphics.print(keybinds:keyLabel(row.id), keyX, y)
        else
            love.graphics.print(row.label, leftX - 15, y)
        end

        if isSel then
            love.graphics.print(">", leftX - 32, y)
        end

        y = y + spacing
    end

    -- Flash message (Reset Defaults confirmation)
    if self.flashTimer > 0 then
        love.graphics.setColor(0.55, 1, 0.85, math.min(1, self.flashTimer))
        love.graphics.printf(self.flashText, 0, h * 0.8, w, "center")
    end

    love.graphics.setFont(love.graphics.getFont())
    love.graphics.setColor(0.5, 0.5, 0.58, 1)
    love.graphics.printf("Up/Down: move    Enter: rebind    Esc: back", 0, h - 40, w, "center")
end

function menu:drawRebindPrompt(w, h)
    -- Find the human label of the action being rebound
    local label = ""
    for _, def in ipairs(keybinds.registry) do
        if def.id == self.rebindAction then
            label = def.label
            break
        end
    end

    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 0.95, 0.8, 1)
    love.graphics.printf("Press a new key for", 0, h * 0.32, w, "center")
    love.graphics.setColor(0.55, 1, 0.85, 1)
    love.graphics.printf(label, 0, h * 0.42, w, "center")

    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(0.6, 0.6, 0.68, 1)
    love.graphics.printf("(Esc to cancel)", 0, h * 0.56, w, "center")
end
