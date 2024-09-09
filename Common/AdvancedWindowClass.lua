Button = require("ButtonClass")

local AdvancedWindow = {}

function AdvancedWindow:print(text)

    term.redirect(self.innerWin)
    self.innerWin.setBackgroundColour(self.backgroundColour)
    self.innerWin.setTextColour(self.foregroundColour)
    print(text)
    term.redirect(term.native())

    self:drawButtons()

end

function AdvancedWindow:addButton(id, label, x, y, w, h, idleColour, activatedColour, callback)
    -- creates a button
    -- args:
    --  - id: string - the id to refer to the button by
    --  - x: integer - x pos of the top left corner
    --  - y: integer - y pos of the top left corner
    --  - w: integer - width
    --  - h: integer - height
    --  - idleColour: colour - colour of the button by default
    --  - activatedColour: colour - the colour to turn when pressed
    --  - callback: function - the function to execute when pressed

    if self.buttons[id] ~= nil then -- a button already exists with this id
        return false
    end

    self.buttons[id] = Button.new(id, label, x, y, w, h, idleColour, activatedColour, callback)

    self.buttons[id]:draw(false, self.innerWin)

end

function AdvancedWindow:drawButtons()

    for k, v in pairs(self.buttons) do

        v:draw(false, self.innerWin)

    end

end

function AdvancedWindow:activateButtonByID(id)
    -- actives the button with the given id
    if self.buttons[id] == nil then -- this button doesn't exist
        return false
    else
        self.buttons[id]:flash(self.innerWin)
        local ret = self.buttons[id].callback()
        return ret
    end
end

function AdvancedWindow:activateButtonByCoord(x, y)
    
    for k, v in pairs(self.buttons) do
        if x >= v.x and y >= v.y and x <= v.x + v.w and y <= v.y + v.h then
            self:activateButtonByID(v.id)
            return true
        end
    end

    return false
end

function AdvancedWindow:clear(borderToo)

    self.innerWin.setBackgroundColour(self.backgroundColour)
    self.innerWin.setTextColour(self.foregroundColour)
    self.innerWin.clear()

    if borderToo then
        self:drawBorder()
    end
end

function AdvancedWindow:setCursorPos(x, y)
    return self.innerWin.setCursorPos(x, y)
end

function AdvancedWindow:drawBorder()
    
    local w = self.outerWin
    local wX, wY = w.getSize()
    
    -- draw corners
    --- top left
    w.setBackgroundColour(self.backgroundColour)
    w.setTextColour(self.borderColour)
    w.setCursorPos(1, 1)
    w.write(string.char(151))
    --- top right
    w.setBackgroundColour(self.borderColour) -- there is no correct character, only it's inverse, so invert colours then draw the inverse char
    w.setTextColour(self.backgroundColour)
    w.setCursorPos(wX, 1)
    w.write(string.char(148))
    --- bottom left
    w.setCursorPos(1, wY)
    w.write(string.char(138))
    --- bottom right
    w.setCursorPos(wX, wY)
    w.write(string.char(133))

    -- draw top edge
    w.setBackgroundColour(self.backgroundColour)
    w.setTextColour(self.borderColour)
    w.setCursorPos(2, 1)
    w.write(string.rep(
        string.char(131),
        wX-2
    ))

    -- draw bottom edge
    w.setBackgroundColour(self.borderColour)
    w.setTextColour(self.backgroundColour)
    w.setCursorPos(2, wY)
    w.write(string.rep(
        string.char(143),
        wX-2
    ))

    -- draw edges
    for y=2, wY-1 do -- iterate over every height where we need to draw a border char
        -- left edge
        w.setBackgroundColour(self.backgroundColour)
        w.setTextColour(self.borderColour)
        w.setCursorPos(1, y)
        w.write(string.char(149))

        -- right edge
        w.setBackgroundColour(self.borderColour)
        w.setTextColour(self.backgroundColour)
        w.setCursorPos(wX, y)
        w.write(string.char(149))
    end

end

function AdvancedWindow:setBackgroundColour(col)

    self.backgroundColour = col
    
end

function AdvancedWindow:setTextColour(col)

    self.foregroundColour = col

end

function AdvancedWindow:setBorderColour(col)

    self.borderColour = col

end

function AdvancedWindow:getBackgroundColour(col)

    return self.backgroundColour
    
end

function AdvancedWindow:getTextColour(col)

    return self.foregroundColour

end

function AdvancedWindow:getBorderColour(col)

    return self.borderColour

end

local AdvancedWindowMetatable = {
    __index = AdvancedWindow
}

function new(parent, x, y, w, h, bgcol, fgcol, bordercol)

    outerWin = window.create(
        parent,
        x,
        y,
        w,
        h
    )

    innerWin = window.create(
        outerWin,
        2, -- relative to outerWin coord space
        2,
        w-2, -- account for borders
        h-2
    )

    win = setmetatable(
        {
            x = x,
            y = y,
            width = w,
            height = h,
            backgroundColour = bgcol,
            foregroundColour = fgcol,
            borderColour = bordercol,
            outerWin = outerWin,
            innerWin = innerWin,
            buttons = {}
        },
        AdvancedWindowMetatable
    )

    win:clear(true)

    return win
end

return { new = new }
