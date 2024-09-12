RSS = require("/CCStorage.Common.RemoteStorageSystemClass")
SB = require("/CCStorage.TUI.SearchBoxClass")
CCS = require("cc.strings")
PR = require("cc.pretty")
PRW = function(obj) return PR.render(PR.pretty(obj)) end

-- this program is structured as an event loop that reacts to key press events.
-- specifically, it reacts to "char" events to type in the search box, and then
-- "key" and "key_up" events to track backspaces and ctrl-key combos

-- local dbgmon = peripheral.wrap("right")
-- dbgmon.setTextScale(0.5)
-- dbgmon.clear()

--TODO: make this use nonblocking calls

local outChest = "minecraft:chest_271"
--- @type ccTweaked.peripherals.WiredModem
--- @diagnostic disable-next-line: assign-type-mismatch
local modem = peripheral.find("modem")
modem.closeAll()
local rss = RSS.new(modem, 20, 22):unwrap()
local termx, termy = term.getSize()
print("start")
term.clear()
local sb = SB.new(
    term.current(),
    2,
    4,
    termx-2,
    termy-5,
    colours.black,
    colours.white,
    colours.grey,
    colours.lightGrey,
    colours.grey,
    colours.grey
)

local ctrlIsHeld

local function getItemList()
    local listIn = rss:organisedList():unwrap()[1]:unwrap()
    -- DBGMONPRINT(listIn)

    local largestNumber = 0
    for k, v in pairs(listIn) do
        -- DBGMONPRINT(v)
        if v >= largestNumber then largestNumber = v end
    end
    local numLength = string.len(tostring(largestNumber))
    local wordLength = table.pack(sb.win.innerWin.getSize())[1] - (numLength + 3)

    local arrOut = {} -- table in format {item_list_entry_string, count}
    for k, v in pairs(listIn) do
        local numStr = CCS.ensure_width(tostring(v), numLength)
        local nameStr = CCS.ensure_width(tostring(k), wordLength)
        table.insert(
            arrOut,
            {
                string.format(
                    "%s - %s",
                    numStr,
                    nameStr
                ),
                v
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

    return stringArrOut
end

local function refreshItemList()
    sb:setListOverride("Refreshing...")
    sb:draw()
    sb:setSearchList(
        getItemList()
    )
    sb:clearListOverride()
    sb:draw()
end

local function handleCharEv(ev)
    -- if ev[2] ~= "%" then -- don't let the user enter a "%" character because a single one breaks the find method
        sb:addToSearchTerm(ev[2])
        sb:draw()
    -- end
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
            refreshItemList()
        elseif ev[2] == 259 then
            sb:setSearchTerm("")
            sb:draw()
        elseif ev[2] == 257 then
            -- enter
            local sel = sb:getSelected()[1]
            local count, name = string.match(sel,"([0-9]+) +- ([^ ]+) +")
            sb.win:setBorderColour(colours.white)
            sb:draw()
            local res = rss:retrieve(name, outChest, math.min(count, 64*10)):unwrap()[1]
            res:handle(
                function(retrieved)
                    if retrieved then
                        sb.win:setBorderColour(colours.lime)
                    else
                        sb.win:setBorderColour(colours.red)
                    end
                    sb:draw()
                    -- DBGMONPRINT("Retrieved: "..tostring(retrieved))
                end,
                function(err)
                    sb.win:setBorderColour(colours.red)
                    sb:draw()
                    DBGMONPRINT("Failed: "..err)
                end
            )
            sleep(0.2)
            sb.win:setBorderColour(colours.grey)
            refreshItemList()
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
            local res = rss:retrieve(name, outChest, math.min(count, 64)):unwrap()[1]
            res:handle(
                function(retrieved)
                    if retrieved then
                        sb.win:setBorderColour(colours.lime)
                    else
                        sb.win:setBorderColour(colours.red)
                    end
                    sb:draw()
                    -- DBGMONPRINT("Retrieved: "..tostring(retrieved))
                end,
                function(err)
                    sb.win:setBorderColour(colours.red)
                    sb:draw()
                    DBGMONPRINT("Failed: "..err)
                end
            )
            sleep(0.2)
            sb.win:setBorderColour(colours.grey)
            refreshItemList()
        end
    end
    return false
end

local function handleKeyUpEv(ev)
    if ev[2] == 341 then
        ctrlIsHeld = false
    end
end

local list = getItemList()
sb:setSearchList(list)
sb:draw()

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
    end
end

-- term.redirect(term.native())
-- term.setCursorPos(1,1)
-- shell.run("clear")
-- print("Exited")
