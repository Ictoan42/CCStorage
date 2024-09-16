-- a window that lists the most common items in the storage system

local pr = require("cc.pretty")
local prp = pr.pretty_print
local ccs = require("cc.strings")

--- @class ItemCountWatcher
--- @field win AdvancedWindow
--- @field rssObj RemoteStorageSystem
--- @field sw StatusWindow
--- @field unregOnly boolean
--- @field nameTable table
--- @field list table
local ItemCountWatcher = {}

local ItemCountWatcherMetatable = {
    __index = ItemCountWatcher
}

function ItemCountWatcher:requestList()

    self.rssObj:organisedList(true)

end

--- @param evIn table a modem message
function ItemCountWatcher:handleListResponse(evIn)

    --- @type Result
    local res = evIn[1]

    res:handle(
        function(val)
            self.list = val
            self.rssObj:getDisplayNameTable()
        end,
        function(err)
            print("Failed to parse response to list request: "..err)
        end
    )

end

--- @param evIn table a modem message
function ItemCountWatcher:handleNamesResponse(evIn)

    --- @type Result
    local res = evIn[1]

    res:handle(
        function(val)
            self.nameTable = val
            self:draw(self.list, self.nameTable)
        end,
        function(err)
            print("Failed to parse name table response: "..err)
        end
    )
end

--- @param itemsList table from rss:organisedList(true)
--- @param nameTable table from rss:getDisplayNameTable()
function ItemCountWatcher:draw(itemsList, nameTable)

    -- itemsList is an argument to pass in a premade list from rss:organisedList(true)

    local items = itemsList

    -- transform into array where entries are in format {count, name, regStatus}
    local sortedList = {}
    local totalItemCount = 0
    for k, v in pairs(items) do

        if type(v) ~= "table" then
            -- organisedList was called by a different client without requesting
            -- reg info, we should ignore this call
            return
        end

        local formToStore = {v[1], k, v["regStatus"]}

        if self.unregOnly and v["regStatus"] == false then
            table.insert(sortedList, formToStore)
            totalItemCount = totalItemCount + v[1]
        elseif self.unregOnly == false then
            table.insert(sortedList, formToStore)
            totalItemCount = totalItemCount + v[1]
        end

    end

    self.win:clear(true)

    self.win:setCursorPos(1, 1)
    if self.unregOnly then
        self.win:write(
            "Total: "..totalItemCount.." unregistered/misplaced item(s)"
        )
    else
        self.win:write(
            "Total: " .. totalItemCount .. " item(s)"
        )
    end

    if totalItemCount == 0 then
        return
    end

    -- sort in order of count
    table.sort(
        sortedList,
        function(a1, a2)
            return a1[1] > a2[1]
        end
    )

    --local maxNumLength = math.max(
    --    string.len(sortedList[1][1]),
    --    string.len("Count")
    --)
    local maxNumLength = string.len(sortedList[1][1])

    --self.win:print(
    --    ccs.ensure_width("Count", maxNumLength) .. " - " .. "Name"
    --)

    local maxNameLength = self.win.width - (maxNumLength + string.len(" - "))

    -- offset of the entire list down to leave space for top lines
    local yOffset = 2

    for y=1, math.min(self.win.height, #sortedList) do
        self.win:setCursorPos(1, y + yOffset)
        local c = ccs.ensure_width(tostring(sortedList[y][1]), maxNumLength)
        local n
        if nameTable[sortedList[y][2]] ~= nil then
            n = nameTable[sortedList[y][2]]
        else
            n = tostring(sortedList[y][2])
        end
        local n2 = n:sub(1, math.min(n:len(), maxNameLength - 4))

        if n:len() > maxNameLength - 4 then
            n2 = n2 .. ".."
        end

        if sortedList[y][3] == false then
            local oldCol = self.win:getTextColour()
            self.win:setTextColour(colours.red)
            self.win:write(c .. " - " .. n2)
            self.win:setTextColour(oldCol)
        else
            self.win:write(c .. " - " .. n2)
        end
    end

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
--- @return ItemCountWatcher|boolean
local function new(winManObj, rssObj, name, x, y, w, h, bgcol, fgcol, bordercol, statusWindowObj)
    -- winManObj is the window manager object to draw onto
    -- rssObj is the remote storage system object to watch the size of

    local icw = {
        nameTable = {},
        list = {}
    }

    icw.win = winManObj:newWindow(name, x, y, w, h, bgcol, fgcol, bordercol)

    if icw.win == nil then return false end

    icw.unregOnly = false

    icw.win:addButton(
        "unregOnly",
        "U",
        icw.win.width - 7,
        1,
        5,
        3,
        colours.red,
        colours.lime,
        function()
            ItemCounter.unregOnly = true
            os.cancelTimer(SortTimerID)
            SortTimerID = os.startTimer(0.1)
        end,
        true,
        function()
            ItemCounter.unregOnly = false
            os.cancelTimer(SortTimerID)
            SortTimerID = os.startTimer(0.1)
        end
    )

    icw.rssObj = rssObj

    icw.sw = statusWindowObj

    icw = setmetatable(
        icw,
        ItemCountWatcherMetatable
    )

    return icw

end

return { new = new }
