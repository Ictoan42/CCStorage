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
    if stackSize == 1 then
        -- shortcut for non stackables
        return ("%d"):format(count)
    end
    local stacks = math.floor(count / stackSize)
    local remainder = math.fmod(count, stackSize)
    if stacks > 0 then
        return ("%dx%d + %2d"):format(stacks, stackSize, remainder)
    else
        return ("%d"):format(remainder)
    end
end

function ItemCountWatcher:requestList()

    self.rssObj:organisedList(true, true, true, true)

end

--- @param evIn table a modem message
function ItemCountWatcher:handleListResponse(evIn)

    --- @type Result
    local res = evIn[1]

    res:handle(
        function(val)
            self:draw(val)
        end,
        function(err)
            self.sw:setMessage({"Failed to get list:", err})
            self.sw:flash(colours.red, colours.black)
        end
    )

end

--- @param itemsList table from rss:organisedList(true, true, true, true)
function ItemCountWatcher:draw(itemsList)

    local items = itemsList

    -- filter out desired items
    local filteredList = {}
    for itemID, itemInfo in pairs(items) do
        if self.unregOnly then
            if itemInfo.reg[1] == nil then
                filteredList[itemID] = itemInfo
            end
        else
            filteredList[itemID] = itemInfo
        end
    end

    -- find how many items there are total
    local totalItemCount = 0
    for itemID, itemInfo in pairs(filteredList) do
        totalItemCount = totalItemCount + itemInfo.count
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

    -- create copy in a sortable format
    local sortedList = {}
    for itemID, itemInfo in pairs(filteredList) do
        itemInfo[1] = itemID
        table.insert(sortedList,
            itemInfo
        )
    end

    -- sort in order of count
    table.sort(
        sortedList,
        function(a1, a2)
            return a1.count > a2.count
        end
    )

    -- require("cc.pretty").pretty_print(sortedList)
    -- do return end

    local maxNumLength = 0
    if self.stackMultiple then
        -- biggest number no longer guarantees longest string, so we need to be more sophisticated

        for k, item in pairs(sortedList) do
            local len = stackMultiple(item.count, item.maxCount or 64):len()
            maxNumLength = math.max(maxNumLength, len)
        end
    else
        maxNumLength = string.len(sortedList[1].count)
    end

    local maxNameLength = self.win.width - (maxNumLength + string.len(" - "))

    -- offset of the entire list down to leave space for top lines
    local yOffset = 2

    for y=1, math.min(self.win.height, #sortedList) do
        local item = sortedList[y]
        self.win:setCursorPos(1, y + yOffset)
        local c
        if self.stackMultiple then
            local format = stackMultiple(
                item.count,
                item.maxCount or 64
            )
            local padLen = maxNumLength - format:len()
            local padding = (" "):rep(padLen)
            c = padding..format
        else
            c = ccs.ensure_width(tostring(item.count), maxNumLength)
        end
        local n
        if item.displayName ~= nil then
            n = item.displayName
        else
            n = tostring(item[1])
        end
        local n2 = n:sub(1, math.min(n:len(), maxNameLength - 4))

        if n:len() > maxNameLength - 4 then
            n2 = n2 .. ".."
        end

        -- if this item is unregistered or misplaced
        if item.reg[2] == false then
            local oldCol = self.win:getTextColour()
            self.win:write(c .. " - ")
            self.win:setTextColour(colours.red)
            self.win:write(n2)
            self.win:setTextColour(oldCol)
        elseif item.space then
            local space = item.space[1]
            -- between 0 and 1
            local numItems = item.space[2] - item.space[1]
            local percent = numItems / item.space[2]
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
        self.win.width - 7,
        5,
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
