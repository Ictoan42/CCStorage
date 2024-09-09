-- window that contains the "sort" and "register" buttons

local MainButtonPanel = {}

local MainButtonPanelMetatable = {
    __index = MainButtonPanel
}

function MainButtonPanel:draw2()

    self.win:clear(true)
    self.win:drawButtons()

end

function MainButtonPanel:init()

    midPoint = self.win.height / 4

    self.win:addButton("sort", "Sort", 2, 2, self.win.width - 4, 10, colours.red, colours.lime, function() self:sort() end)
    self.win:addButton("register", "Register", 2, 14, self.win.width - 4, 10, colours.red, colours.lime, function() self:register() end)

end

function MainButtonPanel:sort()

    self.sw:setMessage({"Status: Sorting from input"})
    self.sw:render()
    self.rssObj:sortFromInput(self.inputChestID)

end

function MainButtonPanel:sortHandler(evIn)

    if evIn[5][1] == true then

        self.sw:setMessage({"Status: Idle"})
        self.sw:render()
        return

    else

        self.sw:setMessage({"Unregistered items found in input", "Please manually sort the", "remaining items into the chests", "Then press 'Register'"})
        self.sw:flash(colours.red, colours.black)

        return true

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

function new(winManObj, rssObj, name, x, y, w, h, bgcol, fgcol, bordercol, statusWindowObj, inputChestID)

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