RSS = require("RemoteStorageSystemClass")
SB = require("SearchBoxClass")
CCS = require("cc.strings")
PR = require("cc.pretty")

-- this program is structured as an event loop that reacts to key press events.
-- specifically, it reacts to "char" events to type in the search box, and then
-- "key" and "key_up" events to track backspaces and ctrl-key combos

dbgmon = peripheral.wrap("right")
dbgmon.setTextScale(0.5)
dbgmon.clear()

outChest = "minecraft:chest_271"
modem = peripheral.find("modem")
rss = RSS.new(modem)
termx, termy = term.getSize()
term.clear()
sb = SB.new(
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


function getItemList()
    local listIn = rss:organisedList()[1]

    local largestNumber = 0
    for k, v in pairs(listIn) do
        if v >= largestNumber then largestNumber = v end
    end
    local numLength = string.len(tostring(largestNumber))
    local wordLength = table.pack(sb.win.innerWin.getSize())[1] - (numLength + 3)

    local arrOut = {} -- table in format {item_list_entry_string, count}
    for k, v in pairs(listIn) do
        numStr = CCS.ensure_width(tostring(v), numLength)
        nameStr = CCS.ensure_width(tostring(k), wordLength)
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

function refreshItemList()
    sb:setListOverride("Refreshing...")
    sb:draw()
    sb:setSearchList(
        getItemList()
    )
    sb:clearListOverride()
    sb:draw()
end

function handleCharEv(ev)
    if ev[2] ~= "%" then -- don't let the user enter a "%" character because a single one breaks the find method
        sb:addToSearchTerm(ev[2])
        sb:draw()
    end
end

function handleKeyEv(ev)
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
            count, name = string.match(sel,"([0-9]+) +- ([^ ]+) +")
            sb.win:setBorderColour(colours.lime)
            sb:draw()
            rss:retrieve(name, outChest, math.min(count, 64))
            sb.win:setBorderColour(colours.grey)
            refreshItemList()
        end
    end
    return false
end

function handleKeyUpEv(ev)
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

term.redirect(term.native())
term.setCursorPos(1,1)
shell.run("clear")
print("Exited")