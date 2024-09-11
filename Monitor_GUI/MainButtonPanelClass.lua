-- window that contains the "sort" and "register" buttons

--- @class MainButtonPanel
--- @field win AdvancedWindow
--- @field rssObj RemoteStorageSystem
--- @field sw StatusWindow
--- @field inputChestID string
local MainButtonPanel = {}

local MainButtonPanelMetatable = {
    __index = MainButtonPanel
}

function MainButtonPanel:draw2()

    self.win:clear(true)
    self.win:drawButtons()

end

function MainButtonPanel:init()

    local midPoint = self.win.height / 4

    self.win:addButton("sort", "Sort", 2, 2, self.win.width - 4, 10, colours.red, colours.lime, function() self:sort() end)
    self.win:addButton("register", "Register", 2, 14, self.win.width - 4, 10, colours.red, colours.lime, function() self:register() end)

end

function MainButtonPanel:sort()

    self.sw:setMessage({"Status: Sorting from input"})
    self.sw:render()
    self.rssObj:sortFromInput(self.inputChestID)

end

--- @param evIn table modem message
--- @return boolean unregisteredFound whether any unregistered items were found in the input chest
function MainButtonPanel:sortHandler(evIn)

    local prp = require("cc.pretty").pretty_print
    prp(evIn)

    --- @type Result
    local res = evIn[1]
    if res:is_ok() then
        if res:unwrap() then
            self.sw:setMessage({"Status: Idle"})
            self.sw:render()
            return false
        else
            self.sw:setMessage({"Unregistered items found in input", "Please manually sort the", "remaining items into the chests", "Then press 'Register'"})
            self.sw:flash(colours.red, colours.black)
            return true
        end
    else
        self.sw:setMessage({"Failed to sort items due to error:", res:unwrap_err()})
        self.sw:flash(colours.red, colours.black)
        return false
    end

end

function MainButtonPanel:register()

    self.sw:setMessage({"Status: Registering unknown items"})
    self.rssObj:detectAndRegisterItems()

end

function MainButtonPanel:registerHandler(evIn)

    self.sw:setMessage({"Status: Idle"})
    self.sw:render()

end

--- @param winManObj WindowManager
--- @param rssObj RemoteStorageSystem
--- @param name string
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param bgcol ccTweaked.colors.color
--- @param fgcol ccTweaked.colors.color
--- @param bordercol ccTweaked.colors.color
--- @param statusWindowObj StatusWindow
--- @param inputChestID string
--- @return MainButtonPanel|boolean
local function new(winManObj, rssObj, name, x, y, w, h, bgcol, fgcol, bordercol, statusWindowObj, inputChestID)

    local mbp = {}

    mbp.win = winManObj:newWindow(name, x, y, w, h, bgcol, fgcol, bordercol)

    if mbp.win == false then return false end

    mbp.rssObj = rssObj

    mbp.sw = statusWindowObj

    mbp.inputChestID = inputChestID

    mbp = setmetatable(
        mbp,
        MainButtonPanelMetatable
    )

    mbp:init()

    return mbp
end

return { new = new }
