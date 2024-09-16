-- window for communicating with the user

--- @class StatusWindow
--- @field win AdvancedWindow
local StatusWindow = {}

local StatusWindowMetatable = {
    __index = StatusWindow
}

--- @param message table array of strings, each is a line
function StatusWindow:setMessage(message)

    -- message should be an array of string
    -- each entry is a line

    self.message = message

end

--- @param bgcol ccTweaked.colors.color
--- @param tcol ccTweaked.colors.color
function StatusWindow:flash(bgcol, tcol)
    -- flash the entire window to the given colours
    -- render through any stored message while we're at it

    local oldbgcol = self.win:getBackgroundColour()
    local oldtcol = self.win:getTextColour()

    self.win:setBackgroundColour(bgcol)
    self.win:setTextColour(tcol)

    self:render()

    self.win:setBackgroundColour(oldbgcol)
    self.win:setTextColour(oldtcol)

    sleep(0.1)

    self:render()

    self.win:setBackgroundColour(bgcol)
    self.win:setTextColour(tcol)

    sleep(0.1)

    self:render()

    self.win:setBackgroundColour(oldbgcol)
    self.win:setTextColour(oldtcol)

    sleep(0.1)

    self:render()

end

function StatusWindow:render()

    self.win:clear(true)

    local topLineY = ( self.win.height - #self.message ) / 2

    for k, v in pairs(self.message) do

        local cX = ( self.win.width - string.len(v) ) / 2

        self.win:setCursorPos(cX, topLineY + (k - 1))

        self.win:write(v)

    end

end

--- @param winManObj WindowManager
--- @param name string the name of the window
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param bgcol ccTweaked.colors.color
--- @param fgcol ccTweaked.colors.color
--- @param bordercol ccTweaked.colors.color
--- @return StatusWindow|nil
--- @return string|nil
local function new(winManObj, name, x, y, w, h, bgcol, fgcol, bordercol)

    local sw = {}

    local win, err = winManObj:newWindow(name, x, y, w, h, bgcol, fgcol, bordercol)

    if win == nil then
        return nil, err
    else
        sw.win = win
    end

    sw = setmetatable(
        sw,
        StatusWindowMetatable
    )

    return sw

end

return { new = new }
