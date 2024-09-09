-- a window that lists the most common items in the storage system

pr = require("cc.pretty")
prp = pr.pretty_print
ccs = require("cc.strings")

local ItemCountWatcher = {}

local ItemCountWatcherMetatable = {
    __index = ItemCountWatcher
}

function ItemCountWatcher:requestList()

    self.sw:setMessage({"Status: Getting item list"})
    self.sw:render()

    self.rssObj:organisedList()

    self.sw:setMessage({"Status: Idle"})
    self.sw:render()

end

function ItemCountWatcher:handleListResponse(evIn)

    self:draw(evIn[5][1])

end

function ItemCountWatcher:draw(itemsList)

    -- itemsList is an argument to pass in a premade list from rss:organisedList()
    
    local items = itemsList

    -- transform into array where entries are in format {count, name}
    local sortedList = {}
    local totalItemCount = 0
    for k, v in pairs(items) do

        local formToStore = {v, k}

        table.insert(sortedList, formToStore)
        totalItemCount = totalItemCount + v
    end

    self.win:clear(true)

    self.win:setCursorPos(1, 1)
    self.win:print(
        "Total: " .. totalItemCount .. " items"
    )

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
        local n = tostring(sortedList[y][2])
        n2 = n:sub(1, math.min(n:len(), maxNameLength - 4))

        if n:len() > maxNameLength - 4 then
            n2 = n2 .. ".."
        end

        self.win:print(c .. " - " .. n2)
    end
    
end

function new(winManObj, rssObj, name, x, y, w, h, bgcol, fgcol, bordercol, statusWindowObj)
    -- winManObj is the window manager object to draw onto
    -- rssObj is the remote storage system object to watch the size of

    local icw = {}

    icw.win = winManObj:newWindow(name, x, y, w, h, bgcol, fgcol, bordercol)

    if icw.win == false then return false end

    icw.rssObj = rssObj

    icw.sw = statusWindowObj

    icw = setmetatable(
        icw,
        ItemCountWatcherMetatable
    )

    return icw

end

return { new = new }