---@diagnostic disable: lowercase-global
RSS = require("/CCStorage.Common.RemoteStorageSystemClass")
SB = require("/CCStorage.TUI.SearchBoxClass")
SW = require("/CCStorage.Common.StatusWindowClass")
WM = require("/CCStorage.Common.WindowManagerClass")
CF = require("/CCStorage.Common.ConfigFileClass")
CCS = require("cc.strings")
PR = require("cc.pretty")
PRW = function(obj) return PR.render(PR.pretty(obj)) end

local function requestItemList()
    sb:setListOverride("Refreshing...")
    sb:draw()
    rss:organisedList(false, true)
end

--- @param colour ccTweaked.colors.color
local function flashBorderColour(colour)
    sb.win:setBorderColour(colour)
    os.cancelTimer(resetBorderColourTimerID)
    resetBorderColourTimerID = os.startTimer(0.2)
end

local function redraw()
    term.clear()
    if not help:isVisible() then
        term.setCursorPos(1,1)
        term.write("Hold <Ctrl+C> to view help")
    end
    sb:draw()
    sw:render()
    help:clear(true)
    help:setCursorPos(2,1)
    help:write("Controls:")
    help:setCursorPos(3,3)
    help:write(string.char(24).." "..string.char(25).."              - Move cursor")
    help:setCursorPos(3,4)
    help:write("<Shift+Enter>    - Retrieve 1")
    help:setCursorPos(3,5)
    help:write("<Enter>          - Retrieve 1 stack")
    help:setCursorPos(3,6)
    help:write("<Ctrl+Enter>     - Retrieve 10 stacks")
    help:setCursorPos(3,7)
    help:write("<Ctrl+R>         - Refresh list")
    help:setCursorPos(3,8)
    help:write("<Ctrl+S>         - Sort back into system")
    help:setCursorPos(3,9)
    help:write("<Ctrl+Backspace> - Clear search box")
    help:setCursorPos(3,10)
    help:write("<Ctrl+Q>         - Exit program")
end

--- @param evIn table modem_message event
local function handleItemListResponse(evIn)
    -- DBGMONPRINT(listIn)
    --- @type Result
    local res = evIn[1]
    local listIn
    if res:is_ok() then
        listIn = res:unwrap()
    else
        error("Couldn't decode list response: "..res:unwrap_err())
    end

    latestList = listIn

    local largestNumber = 0
    for itemID, item in pairs(listIn) do
        -- DBGMONPRINT(v)
        if item.count >= largestNumber then largestNumber = item.count end
    end
    local numLength = string.len(tostring(largestNumber))
    local wordLength = table.pack(sb.win.innerWin.getSize())[1] - (numLength + 3)

    local arrOut = {} -- table in format {item_list_entry_string, count}
    for itemID, item in pairs(listIn) do
        local numStr = CCS.ensure_width(tostring(item.count), numLength)
        local nameStr = CCS.ensure_width(tostring(itemID), wordLength)
        table.insert(
            arrOut,
            {
                string.format(
                    "%s - %s",
                    numStr,
                    nameStr
                ),
                item.count
            }
        )
    end

    -- sort by count
    table.sort(
        arrOut,
        function(a1, a2)
            return a1[2] > a2[2]
        end
    )

    local stringArrOut = {}
    for k, v in pairs(arrOut) do
        -- copy across only the list entry string
        table.insert(
            stringArrOut,
            v[1]
        )
    end

    sb:setSearchList(stringArrOut)
    sb:clearListOverride()
    sb:draw()
end

local function handleRetrieveResponse(evIn)
    --- @type Result
    local res = evIn[1]
    res:handle(
        function(retrieved)
            if retrieved then
                flashBorderColour(colours.lime)
            else
                flashBorderColour(colours.red)
            end
            sb:draw()
            sw:setMessage({"Retrieved items successfully"})
            sw:render()
            -- DBGMONPRINT("Retrieved: "..tostring(retrieved))
        end,
        function(err)
            flashBorderColour(colours.red)
            sw:setMessage({err})
            sw:render()
        end
    )
    requestItemList()
end

local function handleSortResponse(evIn)
    --- @type Result
    local res = evIn[1]
    requestItemList()
    res:handle(
        function(sorted)
            if sorted.successful > 0 then
                if sorted.unregistered > 0 or sorted.no_space > 0 then
                    -- some were sorted correctly, but others weren't
                    flashBorderColour(colours.orange)
                    sb:draw()
                    sw:setMessage({"Some items sorted successfully"})
                    sw:render()
                else
                    -- there were no issues
                    flashBorderColour(colours.lime)
                    sb:draw()
                    sw:setMessage({"All items sorted successfully"})
                    sw:render()
                end
            else
                if sorted[1] == true then
                    -- there were no problems
                    sw:setMessage({"No items were sorted"})
                    sw:render()
                else
                    -- there were problems
                    flashBorderColour(colours.red)
                    sb:draw()
                    sw:setMessage({"No items were sorted"})
                    sw:render()
                end
            end
        end,
        function(err)
            sw:setMessage({"Error:", err})
            flashBorderColour(colours.red)
        end
    )
end

local function handleModemMessageEv(ev)

    local decoded = RSS.DecodeResponse(ev[5]):unwrap()

    if decoded[2] == "organisedList" then
        handleItemListResponse(decoded)
    elseif decoded[2] == "retrieve" then
        handleRetrieveResponse(decoded)
    elseif decoded[2] == "sortFromInput" then
        handleSortResponse(decoded)
    end
end

local function handleTimerEv(ev)
    if ev[2] == resetBorderColourTimerID then
        sb.win:setBorderColour(colours.grey)
        sb:draw()
    end
end

local function handleCharEv(ev)
    sb:addToSearchTerm(ev[2])
    sb:draw()
end

local function handleKeyEv(ev)
    if ev[2] == 341 then
        lctrl = true
        ctrlIsHeld = lctrl or rctrl
    elseif ev[2] == 345 then
        rctrl = true
        ctrlIsHeld = lctrl or rctrl
    elseif ev[2] == 340 then
        lshift = true
        shiftIsHeld = lshift or rshift
    elseif ev[2] == 344 then
        rshift = true
        shiftIsHeld = lshift or rshift
    end
    if ctrlIsHeld then
        if ev[2] == 81 then
            -- 81 -> q
            return true -- whether the program should exit
        elseif ev[2] == 74 then
            -- j
            sb:moveSelectedDown()
            sb:draw()
        elseif ev[2] == 75 then
            -- k
            sb:moveSelectedUp()
            sb:draw()
        elseif ev[2] == 82 then
            -- r
            requestItemList()
        elseif ev[2] == 259 then
            sb:setSearchTerm("")
            sb:draw()
        elseif ev[2] == 67 then
            -- c
            help:setVisible(true)
            redraw()
        elseif ev[2] == 83 then
            -- s
            rss:sortFromInput(Config.outputChest)
        elseif ev[2] == 257 and help:isVisible() == false then
            -- enter
            local sel = sb:getSelected()[1]
            local count, name = string.match(sel,"([0-9]+) +- ([^ ]+) +")
            sb.win:setBorderColour(colours.white)
            sb:draw()
            local stackSize = latestList[name].maxCount
            rss:retrieve(name, Config.outputChest, math.min(count, stackSize*10))
        end
    elseif shiftIsHeld then
        if ev[2] == 257 and help:isVisible() == false then
            -- enter
            local sel = sb:getSelected()[1]
            local count, name = string.match(sel,"([0-9]+) +- ([^ ]+) +")
            sb.win:setBorderColour(colours.white)
            sb:draw()
            local stackSize = latestList[name].maxCount
            rss:retrieve(name, Config.outputChest, 1)
        end
    else
        if ev[2] == 259 then
            -- backspace
            sb:removeFromSearchTerm(1)
            sb:draw()
        elseif ev[2] == 264 then
            -- down arrow
            sb:moveSelectedDown()
            sb:draw()
        elseif ev[2] == 265 then
            -- up arrow
            sb:moveSelectedUp()
            sb:draw()
        elseif ev[2] == 257 then
            -- enter
            local sel = sb:getSelected()[1]
            local count, name = string.match(sel,"([0-9]+) +- ([^ ]+) +")
            sb.win:setBorderColour(colours.white)
            sb:draw()
            local stackSize = latestList[name].maxCount
            rss:retrieve(name, Config.outputChest, math.min(count, stackSize))
        end
    end
    return false
end

local function handleKeyUpEv(ev)
    if ev[2] == 341 then
        lctrl = false
        ctrlIsHeld = lctrl or rctrl
    elseif ev[2] == 345 then
        rctrl = false
        ctrlIsHeld = lctrl or rctrl
    elseif ev[2] == 340 then
        lshift = false
        shiftIsHeld = lshift or rshift
    elseif ev[2] == 344 then
        rshift = false
        shiftIsHeld = lshift or rshift
    elseif ev[2] == 67 then
        -- c
        help:setVisible(false)
        redraw()
    end
end

local function main(confFilePath)
    Config = CF.new(confFilePath)

    --- @type ccTweaked.peripherals.WiredModem
    --- @diagnostic disable-next-line: assign-type-mismatch
    local modem = peripheral.find("modem")
    modem.closeAll()
    rss = RSS.new(
        modem,
        tonumber(Config.portOut),
        tonumber(Config.portIn),
        true
    ):unwrap()
    local termx, termy = term.getSize()
    print("start")
    term.clear()
    term.setCursorPos(1,1)
    term.write("Hold <Ctrl+C> to view controls")
    wm = WM.new(term.current())
    help = wm:newWindow("helpPage", 4, 4, 45, 13, colours.black, colours.white, colours.grey, true, false)
    sw, swerr = SW.new(wm, "statusWindow", 2, 2, termx-2, 3, colours.black, colours.white, colours.grey)
    if sw == nil then
        error("sw is nil: "..swerr)
    end
    sw:setMessage({""})
    sb = SB.new(wm, 2, 6, termx-2, termy-6, colours.black, colours.white, colours.grey, colours.lightGrey, colours.grey, colours.grey)

    -- redraw()

    lctrl = false
    rctrl = false
    ctrlIsHeld = false
    lshift = false
    rshift = false
    shiftIsHeld = false
    resetBorderColourTimerID = -1 -- i don't think timer IDs can be negative???
    latestList = {}

    requestItemList()

    ctrlIsHeld = false
    while true do
        local ev = table.pack(os.pullEvent())
        if ev[1] == "char" then
            handleCharEv(ev)
        elseif ev[1] == "key" then
            if handleKeyEv(ev) then
                break
            end
        elseif ev[1] == "key_up" then
            handleKeyUpEv(ev)
        elseif ev[1] == "modem_message" then
            handleModemMessageEv(ev)
        elseif ev[1] == "timer" then
            handleTimerEv(ev)
        end
    end
end

return {main = main}
