--- @class Button
--- @field id string
--- @field label string
--- @field x number
--- @field y number
--- @field w number
--- @field h number
--- @field idleColour ccTweaked.colors.color
--- @field activatedColour ccTweaked.colors.color
--- @field callback function
local Button = {}

--- @param isActivated boolean
--- @param window ccTweaked.Window
function Button:draw(isActivated, window)

    local t = window

    local colToDraw
    if isActivated then
        colToDraw = self.activatedColour
    else
        colToDraw = self.idleColour
    end

    local oldX, oldY = t.getCursorPos()

    t.setBackgroundColour(colToDraw)
    for y = self.y, self.y + (self.h-1) do
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

--- @param window ccTweaked.Window
--- Flash the button for 0.1 seconds
function Button:flash(window)
    -- briefly flashes to the "activated" colour, then back
    self:draw(true, window)
    sleep(0.1)
    self:draw(false, window)
end

local ButtonMetatable = {
    __index = Button
}

--- @param id string the button's ID
--- @param label string
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param idleColour ccTweaked.colors.color
--- @param activatedColour ccTweaked.colors.color
--- @param callback function function to run when the button is pressed
--- @return table
--- Create a new button
local function new(id, label, x, y, w, h, idleColour, activatedColour, callback)
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
