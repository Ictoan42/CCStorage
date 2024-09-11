-- window for communicating with the user

local StatusWindow = {}

local StatusWindowMetatable = {
    __index = StatusWindow
}

function StatusWindow:setMessage(message)

    -- message should be an array of string
    -- each entry is a line

    self.message = message

end

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

        self.win:print(v)

    end

end

local function new(winManObj, rssObj, name, x, y, w, h, bgcol, fgcol, bordercol)

    local sw = {}

    sw.win = winManObj:newWindow(name, x, y, w, h, bgcol, fgcol, bordercol)

    if sw.win == false then return false end

    sw.rssObj = rssObj

    sw = setmetatable(
        sw,
        StatusWindowMetatable
    )

    sw:setMessage({"Status: Idle"})

    sw:render()

    return sw

end

return { new = new }
