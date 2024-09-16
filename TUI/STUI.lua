RSS = require("/CCStorage.Common.RemoteStorageSystemClass")
SB = require("/CCStorage.TUI.SearchBoxClass")
SW = require("/CCStorage.Common.StatusWindowClass")
WM = require("/CCStorage.Common.WindowManagerClass")
CCS = require("cc.strings")
PR = require("cc.pretty")
PRW = function(obj) return PR.render(PR.pretty(obj)) end

--TODO: this should use a config file

local outChest = "minecraft:chest_271"
--- @type ccTweaked.peripherals.WiredModem
--- @diagnostic disable-next-line: assign-type-mismatch
local modem = peripheral.find("modem")
modem.closeAll()
local rss = RSS.new(modem, 20, 22, true):unwrap()
local termx, termy = term.getSize()
print("start")
term.clear()
local wm = WM.new(term.current())
local sw, swerr = SW.new(wm, "statusWindow", 2, 2, termx-2, 3, colours.black, colours.white, colours.grey)
if sw == nil then
    error("sw is nil: "..swerr)
end
local sb = SB.new(wm, 2, 6, termx-2, termy-6, colours.black, colours.white, colours.grey, colours.lightGrey, colours.grey, colours.grey)

local ctrlIsHeld
local resetBorderColourTimerID = -1 -- i don't think timer IDs can be negative???

local function requestItemList()
    sb:setListOverride("Refreshing...")
    sb:draw()
    rss:organisedList()
end

--- @param colour ccTweaked.colors.color
local function flashBorderColour(colour)
    sb.win:setBorderColour(colour)
    os.cancelTimer(resetBorderColourTimerID)
    resetBorderColourTimerID = os.startTimer(0.2)
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

local function handleModemMessageEv(ev)

    local decoded = RSS.DecodeResponse(ev[5]):unwrap()

    if decoded[2] == "organisedList" then
        handleItemListResponse(decoded)
    elseif decoded[2] == "retrieve" then
        handleRetrieveResponse(decoded)
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
        ctrlIsHeld = true
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
        elseif ev[2] == 257 then
            -- enter
            local sel = sb:getSelected()[1]
            local count, name = string.match(sel,"([0-9]+) +- ([^ ]+) +")
            sb.win:setBorderColour(colours.white)
            sb:draw()
            rss:retrieve(name, outChest, math.min(count, 64*10))
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
            rss:retrieve(name, outChest, math.min(count, 64))
        end
    end
    return false
end

local function handleKeyUpEv(ev)
    if ev[2] == 341 then
        ctrlIsHeld = false
    end
end

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

-- term.redirect(term.native())
-- term.setCursorPos(1,1)
-- shell.run("clear")
-- print("Exited")
