RSS = require("/CCStorage.Common.RemoteStorageSystemClass")
WM = require("/CCStorage.Common.WindowManagerClass")
ICW = require("/CCStorage.Monitor_GUI.ItemCountWatcherClass")
MBP = require("/CCStorage.Monitor_GUI.MainButtonPanelClass")
SW = require("/CCStorage.Monitor_GUI.StatusWindowClass")
R = require("/CCStorage.Common.ResultClass")
CF = require("/CCStorage.Common.ConfigFileClass")
local Ok, Err = R.Ok, R.Err
local prp = require("cc.pretty").pretty_print

--TODO: This should use a config file

local function timerHandler(evIn)

    if not shouldSkipList then
        ItemCounter:requestList()
    end

    SortTimerID = os.startTimer(tonumber(Config.listRefreshInterval))

end

local function modemMessageHandler(evIn)

    local decoded = RSS.DecodeResponse(evIn[5]):unwrap()

    if decoded[2] == "sortFromInput" then

        MainButtonPanel:sortHandler(decoded)
        os.cancelTimer(SortTimerID)
        SortTimerID = os.startTimer(0.1)

    elseif decoded[2] == "detectAndRegisterItems" then

        MainButtonPanel:registerHandler(decoded)
        os.cancelTimer(SortTimerID)
        SortTimerID = os.startTimer(0.1)

    elseif decoded[2] == "organisedList" then

        ItemCounter:handleListResponse(decoded)

    elseif decoded[2] == "getCacheTable" then

        ItemCounter:handleCacheResponse(decoded)

    elseif decoded[2] == "cleanUnregisteredItems" then

        MainButtonPanel:cleanUnregisteredHandler(decoded)

    elseif decoded[2] == "cleanMisplacedItems" then

        MainButtonPanel:cleanMisplacedHandler(decoded)
        os.cancelTimer(SortTimerID)
        SortTimerID = os.startTimer(0.1)

    end

end

--- @param confFilePath string
local function main(confFilePath)
    Config = CF.new(confFilePath)
    --- @type ccTweaked.peripherals.WiredModem
    --- @diagnostic disable-next-line: assign-type-mismatch
    local modem = peripheral.find("modem")

    --- @type ccTweaked.peripherals.Monitor
    ---@diagnostic disable-next-line: assign-type-mismatch
    local mon = peripheral.wrap(Config.monitor)
    if mon == nil then return end

    mon.setTextScale(0.5)
    local mX, mY = mon.getSize()
    mon.clear()

    modem.closeAll()
    local portOut = tonumber(Config.portOut)
    if portOut == nil then
        error("portOut must be a number")
    end
    local portIn = tonumber(Config.portIn)
    if portIn == nil then
        error("portIn must be a number")
    end
    local rss = RSS.new(modem, tonumber(Config.portOut), tonumber(Config.portIn), true):unwrap()

    local wm = WM.new(mon)

    local inputChest = Config.inputChest

    StatusWindow = SW.new(wm, rss, "statusWindow", 2, 2, mX - 25, 10, colours.lightGrey, colours.black, colours.grey)
    if type(StatusWindow) == "boolean" then return end
    StatusWindow:setMessage({"Status: Idle"})
    StatusWindow:render()

    MainButtonPanel = MBP.new(wm, rss, "mainButtonPanel", mX - 21, 2, 20, mY-2, colours.lightGrey, colours.black, colours.grey, StatusWindow, inputChest)
    if type(MainButtonPanel) == "boolean" then return end
    MainButtonPanel:draw2()

    -- needs to be accessible from inside callbacks
    ItemCounter = ICW.new(wm, rss, "itemCountWatcher", 2, 13, mX - 25, mY-13, colours.lightGrey, colours.black, colours.grey, StatusWindow)
    if type(ItemCounter) == "boolean" then return end

    SortTimerID = 0
    local shouldSkipList

    os.startTimer(0.1)

    while true do

        local mev = table.pack(os.pullEvent())

        if mev[1] == "monitor_touch" and mev[2] == Config.monitor then

            wm:handleMonitorTouch(table.unpack(mev))

        elseif mev[1] == "timer" then

            timerHandler(mev)

        elseif mev[1] == "modem_message" then

            modemMessageHandler(mev)

        end

    end
end

return { main = main }
