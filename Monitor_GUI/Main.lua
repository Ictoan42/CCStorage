RSS = require("/CCStorage.Common.RemoteStorageSystemClass")
WM = require("/CCStorage.Common.WindowManagerClass")
ICW = require("/CCStorage.Monitor_GUI.ItemCountWatcherClass")
MBP = require("/CCStorage.Monitor_GUI.MainButtonPanelClass")
SW = require("/CCStorage.Monitor_GUI.StatusWindowClass")
R = require("/CCStorage.Common.ResultClass")
local Ok, Err = R.Ok, R.Err
local prp = require("cc.pretty").pretty_print

--TODO: This should use a config file

--- @type ccTweaked.peripherals.WiredModem
--- @diagnostic disable-next-line: assign-type-mismatch
local modem = peripheral.find("modem")

--- @type ccTweaked.peripherals.Monitor
---@diagnostic disable-next-line: assign-type-mismatch
local mon = peripheral.wrap("left")
if mon == nil then return end

mon.setTextScale(0.5)
local mX, mY = mon.getSize()
mon.clear()

modem.closeAll()
local rss = RSS.new(modem, 20, 21, true):unwrap()

local wm = WM.new(mon)

local inputChest = "ironchest:crystal_chest_0"

local statusWindow = SW.new(wm, rss, "statusWindow", 2, 2, mX - 25, 10, colours.lightGrey, colours.black, colours.grey)
if type(statusWindow) == "boolean" then return end
statusWindow:setMessage({"Status: Idle"})
statusWindow:render()

local mainButtonPanel = MBP.new(wm, rss, "mainButtonPanel", mX - 21, 2, 20, mY-2, colours.lightGrey, colours.black, colours.grey, statusWindow, inputChest)
if type(mainButtonPanel) == "boolean" then return end
mainButtonPanel:draw2()

-- needs to be accessible from inside callbacks
ItemCounter = ICW.new(wm, rss, "itemCountWatcher", 2, 13, mX - 25, mY-13, colours.lightGrey, colours.black, colours.grey, statusWindow)
if type(ItemCounter) == "boolean" then return end

SortTimerID = 0
local shouldSkipList

local function timerHandler(evIn)

    if not shouldSkipList then
        ItemCounter:requestList()
    end

    SortTimerID = os.startTimer(1)

end

local function modemMessageHandler(evIn)

    local decoded = RSS.DecodeResponse(evIn[5]):unwrap()

    if decoded[2] == "sortFromInput" then

        mainButtonPanel:sortHandler(decoded)
        os.cancelTimer(SortTimerID)
        SortTimerID = os.startTimer(0.1)

    elseif decoded[2] == "detectAndRegisterItems" then

        mainButtonPanel:registerHandler(decoded)
        os.cancelTimer(SortTimerID)
        SortTimerID = os.startTimer(0.1)

    elseif decoded[2] == "organisedList" then

        ItemCounter:handleListResponse(decoded)

    elseif decoded[2] == "getDisplayNameTable" then

        ItemCounter:handleCacheResponse(decoded)

    elseif decoded[2] == "cleanUnregisteredItems" then

        mainButtonPanel:cleanUnregisteredHandler(decoded)

    elseif decoded[2] == "cleanMisplacedItems" then

        mainButtonPanel:cleanMisplacedHandler(decoded)
        os.cancelTimer(SortTimerID)
        SortTimerID = os.startTimer(0.1)

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

        modemMessageHandler(mev)

    end

end
