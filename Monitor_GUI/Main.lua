RSS = require("/CCStorage/Common/RemoteStorageSystemClass")
WM = require("/CCStorage/Common/WindowManagerClass")
ICW = require("/CCStorage/Monitor_GUI/ItemCountWatcherClass")
MBP = require("/CCStorage/Monitor_GUI/MainButtonPanelClass")
SW = require("/CCStorage/Monitor_GUI/StatusWindowClass")

modem = peripheral.find("modem")
mon = peripheral.wrap("left")

mon.setTextScale(0.5)
mX, mY = mon.getSize()
mon.clear()

rss = RSS.new(modem, 20, 21, true)

wm = WM.new(mon)

local inputChest = "minecraft:chest_6"

statusWindow = SW.new(wm, rss, "statusWindow", 2, 2, mX - 25, 10, colours.lightGrey, colours.black, colours.grey)
statusWindow:setMessage({"Status: Idle"})
statusWindow:render()

mainButtonPanel = MBP.new(wm, rss, "mainButtonPanel", mX - 21, 2, 20, mY-2, colours.lightGrey, colours.black, colours.grey, statusWindow, inputChest)
mainButtonPanel:draw2()

itemCounter = ICW.new(wm, rss, "itemCountWatcher", 2, 13, mX - 25, mY-13, colours.lightGrey, colours.black, colours.grey, statusWindow)

timerID = 0

function timerHandler(evIn)

    if not shouldSkipList then
        itemCounter:requestList()
    end

    timerID = os.startTimer(5)

end

function modemMessageHandler(evIn)

    if evIn[5][2] == "sortFromInput" then

        if mainButtonPanel:sortHandler(evIn) then
            os.cancelTimer(timerID)
        end

    elseif evIn[5][2] == "detectAndRegisterItems" then

        mainButtonPanel:registerHandler(evIn)
        timerID = os.startTimer(5)

    elseif evIn[5][2] == "organisedList" then

        itemCounter:handleListResponse(evIn)

    end

end

print("start loop")

os.startTimer(2)

while true do

    local mev = table.pack(os.pullEvent())

    if mev[1] == "monitor_touch" then

        wm:handleMonitorTouch(table.unpack(mev))

    elseif mev[1] == "timer" then

        timerHandler(mev)

    elseif mev[1] == "modem_message" then

        modemMessageHandler(mev, timerID)

    end

end
