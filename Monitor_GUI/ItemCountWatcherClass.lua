-- a window that lists the most common items in the storage system

local pr = require("cc.pretty")
local prp = pr.pretty_print
local ccs = require("cc.strings")

--- @class ItemCountWatcher
--- @field win AdvancedWindow
--- @field rssObj RemoteStorageSystem
--- @field sw StatusWindow
--- @field unregOnly boolean whether to only list unregistered items
--- @field stackMultiple boolean whether to list item count as a number of stacks instead of a total count
--- @field cacheTable table
--- @field list table
local ItemCountWatcher = {}

local ItemCountWatcherMetatable = {
    __index = ItemCountWatcher
}

--- converts a simple number into a string representing the number of stacks and remainder
local function stackMultiple(count, stackSize)
    local stacks = math.floor(count / stackSize)
    local remainder = math.fmod(count, stackSize)
    if stacks > 0 then
        return ("%dx%d + %2d"):format(stacks, stackSize, remainder)
    else
        return ("%d"):format(remainder)
    end
end

function ItemCountWatcher:requestList()

    self.rssObj:organisedList(true)

end

--- @param evIn table a modem message
function ItemCountWatcher:handleListResponse(evIn)
    -- just store the result from the list, we still need the cache and spaces before we can draw

    --- @type Result
    local res = evIn[1]

    res:handle(
        function(val)
            self.list = val
            self.rssObj:getCacheTable()
        end,
        function(err)
            print("Failed to parse response to list request: "..err)
        end
    )

end

--- @param evIn table a modem message
function ItemCountWatcher:handleCacheResponse(evIn)
    -- just store the cache, we still need the spaces before we can draw

    --- @type Result
    local res = evIn[1]

    res:handle(
        function(val)
            self.cacheTable = val
            self.rssObj:getAllItemSpaces()
        end,
        function(err)
            print("Failed to parse name table response: "..err)
        end
    )
end

--- @param evIn table a modem message
function ItemCountWatcher:handleSpacesResponse(evIn)
    --- @type Result
    local res = evIn[1]
    res:handle(
        function(val)
            self:draw(self.list, self.cacheTable, val)
        end,
        function(err)
            print("Failed to parse spaces table response: "..err)
        end
    )
end

--- @param itemsList table from rss:organisedList(true)
--- @param cacheTable table from rss:getCacheTable()
--- @param spacesTable table from rss:getAllItemSpaces()
function ItemCountWatcher:draw(itemsList, cacheTable, spacesTable)

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
            "Total: "..totalItemCount.." Unregistered/Misplaced item(s)"
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
    local maxNumLength = 0
    if self.stackMultiple then
        -- biggest number no longer guarantees longest string, so we need to be more sophisticated

        -- {count, name, regStatus}
        for k, v in pairs(sortedList) do
            local len = stackMultiple(v[1], cacheTable[v[2]][2]):len()
            maxNumLength = math.max(maxNumLength, len)
        end

        -- maxNumLength = string.len(stackMultiple(
        --     sortedList[1][1],
        --     cacheTable[sortedList[1][2]][2]
        -- ))
    else
        maxNumLength = string.len(sortedList[1][1])
        -- maxNumLength = ("%d/%d"):format(
        --     sortedList[1][1],
        --     spacesTable[sortedList[1][2]]
        -- ):len()
    end

    --self.win:print(
    --    ccs.ensure_width("Count", maxNumLength) .. " - " .. "Name"
    --)

    local maxNameLength = self.win.width - (maxNumLength + string.len(" - "))

    -- offset of the entire list down to leave space for top lines
    local yOffset = 2

    for y=1, math.min(self.win.height, #sortedList) do
        self.win:setCursorPos(1, y + yOffset)
        local c
        if self.stackMultiple then
            local format = stackMultiple(
                sortedList[y][1],
                cacheTable[sortedList[y][2]][2]
            )
            local padLen = maxNumLength - format:len()
            local padding = (" "):rep(padLen)
            c = padding..format
        else
            -- c = ccs.ensure_width(("%d/%d"):format(
            --     sortedList[y][1],
            --     spacesTable[sortedList[y][2]]
            -- ), maxNumLength)
            c = ccs.ensure_width(tostring(sortedList[y][1]), maxNumLength)
        end
        local n
        if cacheTable[sortedList[y][2]] ~= nil then
            n = cacheTable[sortedList[y][2]][1]
        else
            n = tostring(sortedList[y][2])
        end
        local n2 = n:sub(1, math.min(n:len(), maxNameLength - 4))

        if n:len() > maxNameLength - 4 then
            n2 = n2 .. ".."
        end

        -- if this item is unregistered
        if sortedList[y][3] == false then
            local oldCol = self.win:getTextColour()
            self.win:write(c .. " - ")
            self.win:setTextColour(colours.red)
            self.win:write(n2)
            self.win:setTextColour(oldCol)
        elseif spacesTable[sortedList[y][2]] then
            local space = spacesTable[sortedList[y][2]]
            local maxNum = sortedList[y][1] + space
            -- between 0 and 1
            local percent = sortedList[y][1] / maxNum
            local oldCol = self.win:getTextColour()
            if percent == 1 then
                self.win:setTextColour(colours.red)
            elseif percent > 0.9 then
                self.win:setTextColour(colours.orange)
            elseif percent > 0.75 then
                self.win:setTextColour(colours.yellow)
            end
            self.win:write(c)
            self.win:setTextColour(oldCol)
            self.win:write(" - " .. n2)
        end
    end

end

function ItemCountWatcher:setupButtons()
    self.win:addButton(
        "unregOnly",
        "U",
        self.win.width - 7,
        1,
        5,
        3,
        colours.red,
        colours.lime,
        function()
            self.unregOnly = true
            os.cancelTimer(RefreshTimerID)
            RefreshTimerID = os.startTimer(0.1)
        end,
        true,
        function()
            self.unregOnly = false
            os.cancelTimer(RefreshTimerID)
            RefreshTimerID = os.startTimer(0.1)
        end
    )

    self.win:addButton(
        "stackMultiple",
        "S",
        self.win.width - 13,
        1,
        5,
        3,
        colours.red,
        colours.lime,
        function()
            self.stackMultiple = true
            os.cancelTimer(RefreshTimerID)
            RefreshTimerID = os.startTimer(0.1)
        end,
        true,
        function()
            self.stackMultiple = false
            os.cancelTimer(RefreshTimerID)
            RefreshTimerID = os.startTimer(0.1)
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
    icw.stackMultiple = false

    icw.rssObj = rssObj

    icw.sw = statusWindowObj

    icw = setmetatable(
        icw,
        ItemCountWatcherMetatable
    )

    icw:setupButtons()

    return icw

end

return { new = new }
