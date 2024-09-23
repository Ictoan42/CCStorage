-- a window that lists the most common items in the storage system

local BU = require("/CCStorage.Common.BlitUtils")

local pr = require("cc.pretty")
local prp = pr.pretty_print
local ccs = require("cc.strings")

--- @class ItemCountWatcher
--- @field win AdvancedWindow
--- @field rssObj RemoteStorageSystem
--- @field sw StatusWindow
--- @field unregOnly boolean whether to only list unregistered items
--- @field stackMultiple boolean whether to list item count as a number of stacks instead of a total count
--- @field percent boolean whether to list item's percent full next to the number
--- @field cacheTable table
--- @field list table
local ItemCountWatcher = {}

local ItemCountWatcherMetatable = {
    __index = ItemCountWatcher
}

--- @param percent number|nil between 0 and 1
--- @return ccTweaked.colors.color|nil
local function spaceWarningCol(percent)
    local col
    if percent and percent == 1 then col = colours.red
    elseif percent and percent >= 0.9 then col = colours.orange
    elseif percent and percent >= 0.75 then col = colours.yellow
    else col = nil end
    return col
end

--- @param percent number|nil between 0 and 1
--- @return Blit
local function percentStr(percent)
    local b = BU.new(colours.black, colours.lightGrey)
    local col = spaceWarningCol(percent)
    if percent then
        b:write((" (%3d%%)"):format(percent*100), col)
    else
        b:write(" ( ??%)", col)
    end
    return b
end

--- @param itemCount integer item count
--- @param stackSize integer stack size
--- @param percent number percent full
--- @param shouldRenderPercent boolean should render percent
local function renderStackMultiple(itemCount, stackSize, percent, shouldRenderPercent)
    local bout = BU.new(colours.black, colours.lightGrey)

    local col -- colour to indicate percent
    if percent and percent == 1 then col = colours.red
    elseif percent and percent >= 0.9 then col = colours.orange
    elseif percent and percent >= 0.75 then col = colours.yellow
    else col = nil end

    local stacks = math.floor(itemCount / stackSize)
    local remainder = math.fmod(itemCount, stackSize)
    if stackSize == 1 then
        -- shortcut for non stackables
        bout:write(("%d"):format(itemCount), col)
    elseif stacks > 0 then
        bout:write(
            ("%dx%d + %2d"):format(stacks, stackSize, remainder),
            col
        )
    else
        bout:write(("%d"):format(remainder), col)
    end
    if shouldRenderPercent then
        bout:concat(percentStr(percent))
    end
    return bout
end

--- @param itemCount integer item count
--- @param percent number percent full
--- @param shouldRenderPercent boolean should render percent
local function renderCount(itemCount, percent, shouldRenderPercent)
    local bout = BU.new(colours.black, colours.lightGrey)

    local col -- colour to indicate percent
    if percent and percent == 1 then col = colours.red
    elseif percent and percent >= 0.9 then col = colours.orange
    elseif percent and percent >= 0.75 then col = colours.yellow
    else col = nil end

    bout:write(("%d"):format(itemCount), col)

    if shouldRenderPercent then
        bout:concat(percentStr(percent))
    end

    return bout
end

--- @param displayName string|nil
--- @param itemID string
--- @param regStatus boolean whether the item is stored correctly
local function renderItemName(displayName, itemID, regStatus)
    local bout = BU.new(colours.black, colours.lightGrey)
    local name = displayName or itemID
    local col
    if regStatus == false then col = colours.red end
    bout:write(name, col)
    return bout
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

    -- filter out undesired items
    local filteredList = {}
    for itemID, itemInfo in pairs(items) do
        if self.unregOnly then
            if itemInfo.reg[2] == false then
                filteredList[itemID] = itemInfo
            end
        else
            filteredList[itemID] = itemInfo
        end
    end

    -- find how many items there are total and the largest count
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

    -- format {itemCount, countBlit, nameBlit}
    local renderedArr = {}

    -- render count and name blits
    -- also keep track of some useful metrics
    local maxNumLen = 0
    local maxNameLen = 0
    for itemID, itemInfo in pairs(filteredList) do
        local itemArr = {itemInfo.count}
        local percent
        if itemInfo.space then
            local space = itemInfo.space[1]
            local numItems = itemInfo.space[2] - itemInfo.space[1]
            -- between 0 and 1
            percent = numItems / itemInfo.space[2]
        end
        if self.stackMultiple then
            itemArr[2] = renderStackMultiple(itemInfo.count, itemInfo.maxCount, percent, self.percent)
        else
            itemArr[2] = renderCount(itemInfo.count, percent, self.percent)
        end
        itemArr[3] = renderItemName(itemInfo.displayName, itemID, itemInfo.reg[2])
        table.insert(
            renderedArr,
            itemArr
        )
        if itemArr[2]:len() > maxNumLen then
            maxNumLen = itemArr[2]:len()
        end
        if itemArr[3]:len() > maxNameLen then
            maxNameLen = itemArr[3]:len()
        end
    end

    -- sort by count
    table.sort(
        renderedArr,
        function(a1, a2)
            return a1[1] > a2[1]
        end
    )

    -- draw to screen
    --
    local cursorY = 2 -- skip two lines at the top
    for k, item in pairs(renderedArr) do
        local countBlit = item[2]
        local nameBlit = item[3]

        cursorY = cursorY + 1
        self.win:setCursorPos(1, cursorY)
        countBlit:padLeft(maxNumLen)
        countBlit:render(self.win)
        self.win:write(" - ")
        nameBlit:pad(maxNameLen)
        nameBlit:render(self.win)
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

    self.win:addButton(
        "percent",
        "P",
        self.win.width - 7,
        9,
        5,
        3,
        colours.red,
        colours.lime,
        function()
            self.percent = true
            os.cancelTimer(RefreshTimerID)
            RefreshTimerID = os.startTimer(0.1)
        end,
        true,
        function()
            self.percent = false
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
    icw.percent = false

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
