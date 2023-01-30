local Button = {}

function Button:draw(isActivated, window)

    local t = window

    local colToDraw
    if isActivated then
        colToDraw = self.activatedColour
    else
        colToDraw = self.idleColour
    end

    oldX, oldY = t.getCursorPos()

    t.setBackgroundColour(colToDraw)
    for y = self.y, self.y + self.h do
        t.setCursorPos(self.x, y)
        t.write(string.rep(" ", self.w))
    end

    local xMid = self.x + ( self.w / 2 )
    local labelXStart = xMid - ( string.len(self.label) / 2 )

    t.setCursorPos(labelXStart, self.y + ( self.h / 2 ))
    t.write(self.label)

    t.setBackgroundColour(colours.black)
    t.setCursorPos(oldX, oldY)

end

function Button:flash(window)
    -- briefly flashes to the "activated" colour, then back
    self:draw(true, window)
    sleep(0.1)
    self:draw(false, window)
end

local ButtonMetatable = {
    __index = Button
}

function new(id, label, x, y, w, h, idleColour, activatedColour, callback)
    return setmetatable(
        {
            id = id,
            label = label,
            x = x,
            y = y,
            w = w,
            h = h,
            idleColour = idleColour,
            activatedColour = activatedColour,
            callback = callback
        },
        ButtonMetatable
    )
end

return { new = new }