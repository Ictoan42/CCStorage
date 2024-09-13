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
--- @field toggle boolean if this button is a togglebutton
--- @field toggleState boolean the current state of this toggleButton
--- @field callbackOff function callback to run when a togglebutton is turned off
local Button = {}

--- @param isActivated boolean ignored for togglebuttons
--- @param window ccTweaked.Window
function Button:draw(isActivated, window)

    local t = window

    local colToDraw
    if (self.toggle and self.toggleState) or isActivated then
    -- if isActivated then
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

--- @param window ccTweaked.Window
--- @return any callbackReturn
function Button:activate(window)
    if self.toggle then
        return self:activate_toggle(window)
    else
        return self:activate_nontoggle(window)
    end
end

--- @param window ccTweaked.Window
--- @return any callbackReturn
function Button:activate_nontoggle(window)
    self:flash(window)
    return self.callback()
end

--- @param window ccTweaked.Window
--- @return any callbackReturn
function Button:activate_toggle(window)
    -- toggles the colour of a togglebutton and runs the corresponding callback
    self.toggleState = not self.toggleState
    if self.toggleState == true then
        -- button was just turned on by the above toggle
        self:draw(true, window)
        return self.callback()
    else
        self:draw(false, window)
        return self.callbackOff()
    end
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
--- @param toggle boolean|nil whether this button is a togglebutton
--- @param callbackOff function|nil function to run when this togglebutton is turned off
--- @return table
--- Create a new button
local function new(id, label, x, y, w, h, idleColour, activatedColour, callback, toggle, callbackOff)
    toggle = toggle or false
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
            callback = callback,
            toggle = toggle,
            callbackOff = callbackOff,
        },
        ButtonMetatable
    )
end

return { new = new }
