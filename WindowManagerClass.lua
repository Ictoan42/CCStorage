AdvancedWindow = require("AdvancedWindowClass")
Button = require("ButtonClass")

local WindowManager = {}

function WindowManager:newWindow(name, x, y, w, h, bgcol, fgcol, bordercol)

    -- check if it overlaps with any existing window
    for k, v in pairs(self.windows) do -- iterate over every window
        -- get existing window corner
        local vx1 = v.x
        local vx2 = v.x + v.width
        local vy1 = v.y
        local vy2 = v.y + v.height
        -- get new window corner
        local nx1 = x
        local nx2 = x + w
        local ny1 = y
        local ny2 = y + h
        -- horrific if statement to see if they overlap
        if vx1 <= nx2 and vx2 >= nx1 and vy1 <= ny2 and vy2 >= ny1 then
            return false -- they overlap
        end
    end


    if self.windows[name] ~= nil then
        return false
    else
        self.windows[name] = AdvancedWindow.new(self.term, x, y, w, h, bgcol, fgcol, bordercol)
        return self.windows[name]
    end
end

function WindowManager:removeWindow(name)

    self.windows[name] = nil

end

function WindowManager:handleMonitorTouch(evName, side, x, y)
    
    -- find which window this touch was on
    local windowToUse
    for k, v in pairs(self.windows) do

        -- find if the touch was on this window
        if x >= v.x and y >= v.y and x <= v.x + v.width and y <= v.y + v.height then
            windowToUse = v
        end
    end

    if windowToUse == nil then
        return false -- this click wasn't on any window
    end

    return windowToUse:activateButtonByCoord(x - windowToUse.x, y - windowToUse.y)
end

function WindowManager:monTouchListener()

    while not self.shuttingDown do
        self:handleMonitorTouch(os.pullEvent("mouse_click"))
    end

end

function WindowManager:stopListener()
    self.shuttingDown = true
end

local WindowManagerMetatable = {
    __index = WindowManager
}

function new(term)

    local o = setmetatable(
        {
            term = term,
            shuttingDown = false,
            windows = {},
            listener = nil,
        },
        WindowManagerMetatable
    )

    return o

end

return { new = new }