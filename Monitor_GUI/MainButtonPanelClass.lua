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

    local termH = self.win.height
    -- reduce height to the maximum possible while
    -- still fitting 4 equally sized buttons with padding
    termH = termH - math.fmod(termH-5, 4)
    local bh = (termH - 5) / 4
    local bw = self.win.width - 4 --button width

    self.win:addButton("sort", "Sort", 2, 2, bw, bh, colours.red, colours.lime,
        function() self:sort() end
    )
    self.win:addButton("register", "Register", 2, 3+bh, bw, bh, colours.red, colours.lime,
        function() self:register() end
    )
    self.win:addButton("clean", "Clean", 2, 4+(2*bh), bw, bh, colours.red, colours.lime,
        function() self:clean() end
    )
    self.win:addButton("forget", "Forget", 2, 5+(3*bh), bw, bh, colours.red, colours.lime,
        function() self:forget() end
    )

end

function MainButtonPanel:clean()
    self.rssObj:cleanUnregisteredItems(self.inputChestID)
end

function MainButtonPanel:cleanHandler(response)

    --- @type Result
    local res = response[1]
    if res:is_ok() then
        self.sw:setMessage({"Moved "..res:unwrap().." unregistered item(s) into the input chest"})
        self.sw:render()
    else
        self.sw:setMessage({"Failed to clean items due to error:", res:unwrap_err()})
        self.sw:flash(colours.red, colours.black)
    end
end

function MainButtonPanel:forget()
    --TODO: this
    self.sw:setMessage({"The Forget button doesn't do anything yet"," ",":)"})
    self.sw:render()
end

function MainButtonPanel:sort()

    self.sw:setMessage({"Status: Sorting from input"})
    self.sw:render()
    self.rssObj:sortFromInput(self.inputChestID)

end

--- @param evIn table modem message
--- @return boolean unregisteredFound whether any unregistered items were found in the input chest
function MainButtonPanel:sortHandler(evIn)

    --- @type Result
    local res = evIn[1]
    local outcome
    if res:is_ok() then
        --- @type SortOutcome
        outcome = res:unwrap()
    else
        self.sw:setMessage({"Failed to sort items due to error:", res:unwrap_err()})
        self.sw:flash(colours.red, colours.black)
        return false
    end

    if outcome[1] then
        self.sw:setMessage({"Sorted "..outcome.successful.." item(s)"})
        self.sw:render()
        return false
    else
        local message = {"Failed to sort some items:", ""}
        if outcome.unregistered > 0 then
            table.insert(message, outcome.unregistered.." item(s) are not registered")
        end
        if outcome.no_space > 0  then
            table.insert(message, outcome.no_space.." item(s) weren't sorted due to lack of space")
        end
        if outcome.successful > 0 then
            table.insert(message, "")
            table.insert(message, outcome.successful.." item(s) were sorted successfully")
        end
        self.sw:setMessage(message)
        self.sw:flash(colours.red, colours.black)
        return true
    end

end

function MainButtonPanel:register()

    self.sw:setMessage({"Status: Registering unknown items"})
    self.rssObj:detectAndRegisterItems()

end

function MainButtonPanel:registerHandler(evIn)

    evIn[1]:handle(
        function(registered)
            self.sw:setMessage({"Registered "..registered.." item(s)"})
            self.sw:render()
        end,
        function(err)
            self.sw:setMessage({
                "Failed to register items:",
                err
            })
            self.sw:render()
        end
    )
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

    if mbp.win == nil then return false end

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
