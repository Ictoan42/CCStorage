RSS = require("/CCStorage.Common.RemoteStorageSystemClass")
WM = require("/CCStorage.Common.WindowManagerClass")
ICW = require("/CCStorage.Monitor_GUI.ItemCountWatcherClass")
MBP = require("/CCStorage.Monitor_GUI.MainButtonPanelClass")
SW = require("/CCStorage.Monitor_GUI.StatusWindowClass")
R = require("/CCStorage.Common.ResultClass")
CF = require("/CCStorage.Common.ConfigFileClass")
local Ok, Err = R.Ok, R.Err
local prp = require("cc.pretty").pretty_print

--- @param mbp MainButtonPanel
--- @param icw ItemCountWatcher
--- @param sw StatusWindow
--- @param timerRefresh integer
local function timerHandler(evIn, mbp, icw, sw, timerRefresh)

    if evIn[2] == RefreshTimerID then
        icw:requestList()
        RefreshTimerID = os.startTimer(timerRefresh)
    elseif evIn[2] == IdleTimerID then
        sw:setMessage({"Idle"})
        sw:render()
    end

end

--- @param mbp MainButtonPanel
--- @param icw ItemCountWatcher
--- @param defaultIdleTimer integer
--- @param errorIdleTimer integer
local function modemMessageHandler(evIn, mbp, icw, defaultIdleTimer, errorIdleTimer)

    local decoded = RSS.DecodeResponse(evIn[5]):unwrap()

    if decoded[2] == "sortFromInput" then

        if mbp:sortHandler(decoded) then
            IdleTimerID = os.startTimer(defaultIdleTimer)
        else
            IdleTimerID = os.startTimer(errorIdleTimer)
        end
        os.cancelTimer(RefreshTimerID)
        RefreshTimerID = os.startTimer(0.1)

    elseif decoded[2] == "detectAndRegisterItems" then

        if mbp:registerHandler(decoded) then
            IdleTimerID = os.startTimer(defaultIdleTimer)
        else
            IdleTimerID = os.startTimer(errorIdleTimer)
        end
        os.cancelTimer(RefreshTimerID)
        RefreshTimerID = os.startTimer(0.1)

    elseif decoded[2] == "organisedList" then

        icw:handleListResponse(decoded)

    elseif decoded[2] == "getCacheTable" then

        icw:handleCacheResponse(decoded)

    elseif decoded[2] == "cleanUnregisteredItems" then

        mbp:cleanUnregisteredHandler(decoded)

    elseif decoded[2] == "cleanMisplacedItems" then

        if mbp:cleanMisplacedHandler(decoded) then
            IdleTimerID = os.startTimer(defaultIdleTimer)
        else
            IdleTimerID = os.startTimer(errorIdleTimer)
        end
        os.cancelTimer(RefreshTimerID)
        RefreshTimerID = os.startTimer(0.1)

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

    local statusWindow = SW.new(wm, rss, "statusWindow", 2, 2, mX - 25, 10, colours.lightGrey, colours.black, colours.grey)
    if type(statusWindow) == "boolean" then return end
    statusWindow:setMessage({"Status: Idle"})
    statusWindow:render()

    local mainButtonPanel = MBP.new(wm, rss, "mainButtonPanel", mX - 21, 2, 20, mY-2, colours.lightGrey, colours.black, colours.grey, statusWindow, inputChest)
    if type(mainButtonPanel) == "boolean" then return end
    mainButtonPanel:draw2()

    -- needs to be accessible from inside callbacks
    local itemCounter = ICW.new(wm, rss, "itemCountWatcher", 2, 13, mX - 25, mY-13, colours.lightGrey, colours.black, colours.grey, statusWindow)
    if type(itemCounter) == "boolean" then return end

    RefreshTimerID = 0
    IdleTimerID = 0
    local idleTimerLength = tonumber(Config.idleTimer)
    if idleTimerLength == nil then
        error("idleTimer must be a number")
    end
    local errorIdleTimerLength = tonumber(Config.errorIdleTimer)
    if errorIdleTimerLength == nil then
        error("errorIdleTimer must be a number")
    end
    local listRefreshInterval = tonumber(Config.listRefreshInterval)
    if listRefreshInterval == nil then
        error("listRefreshInterval must be a number")
    end
    local shouldSkipList

    RefreshTimerID = os.startTimer(0.1)

    while true do

        local mev = table.pack(os.pullEvent())

        if mev[1] == "monitor_touch" and mev[2] == Config.monitor then

            wm:handleMonitorTouch(table.unpack(mev))

        elseif mev[1] == "timer" then

            timerHandler(mev, mainButtonPanel, itemCounter, statusWindow, listRefreshInterval)

        elseif mev[1] == "modem_message" then

            modemMessageHandler(mev, mainButtonPanel, itemCounter, idleTimerLength, errorIdleTimerLength)

        end

    end
end

return { main = main }
