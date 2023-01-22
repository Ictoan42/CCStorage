-- object wrapper for the storage system as a whole

ConfigFile = require("/StorageSystem/ConfigFileClass")
ChestArray = require("/StorageSystem/ChestArrayClass")
ItemHandler = require("/StorageSystem/ItemHandlerClass")
SortingList = require("/StorageSystem/SortingListClass")
CCLogger = require("/CCLogger") -- this file is in root
pr = require("cc.pretty")
prp = pr.pretty_print

local StorageSystem = {}

function isInList(listStr, s)
    -- internal func for decoding lists from the config file
    -- checks whether the given string "s" is contained within the list

    for i in listStr:gmatch("([^, ]+)") do -- iterate over items in list
        if i == s then
            return true
        end
    end

    return false -- only get here if all checks fail
end

function isInListSegment(listStr, s)
    -- internal func, used for decoding lists in config file
    -- checks whether any entries in the list are substrings of "s"

    for i in listStr:gmatch("([^, ]+)") do -- iterate over items in list
        if s:find(i) then
            return true
        end
    end

    return false
end

function StorageSystem:list(liteMode)
    return self.chestArray:list(liteMode)
end

function StorageSystem:organisedList()
    return self.chestArray:sortedList()
end

function StorageSystem:findItems(itemID)
    return self.itemHandler:findItems(itemID)
end

function StorageSystem:sortFromInput(inputChestID)
    return self.itemHandler:sortAllFromChest(inputChestID)
end

function StorageSystem:retrieve(itemID, outputChestID, count, toSlot)
    return self.itemHandler:retrieveItems(itemID, outputChestID, count, toSlot)
end

function StorageSystem:detectAndRegisterItems()
    self.logger:d("StorageSystem executing method detectAndRegisterItems")

    unregisteredItems = self.itemHandler:findUnregisteredItems()

    if unregisteredItems == false then -- no unregistered items found
        return false
    end

    -- iterate over all unregistered items, registering them
    for k, v in ipairs(unregisteredItems) do -- ipairs() to implicitly ignore the "count" entry
        -- addDest just ignores us if we register the same item twice so blind iteration is fine
        -- alright "fine" might be a stretch but it won't crash at least
        self.sortingList:addDest(
            v[4], -- item name
            v[1] -- chest name
        )
    end

end

function StorageSystem:registerItem(itemID, chestID)
    return self.sortingList:addDest(itemID, chestID)
end

function StorageSystem:forgetItem(itemID)
    return self.sortingList:removeDest(itemID)
end

function StorageSystem:cleanUnregisteredItems(dumpChest)
    return self.itemHandler:cleanUnregisteredItems(dumpChest)
end

function StorageSystem:getConfig()
    return self.confFile
end

local StorageSystemMetatable = {
    __index = StorageSystem
}

function new(confFilePath)

    -- create config file obj
    cfg = ConfigFile.new(confFilePath)

    ---------------
    -- INIT LOGGER
    ---------------
    local logger
    do

        local logFile
        local logTerm
        local enableColour

        if cfg.logFilePath ~= "" then -- if a log file has been specified
            logFile = fs.open(cfg.logFilePath, "w")
        end

        if cfg.logMonName ~= "" then -- if a log term has been specified
            peripheral.call(cfg.logMonName, "setTextScale", 0.5)
            peripheral.call(cfg.logMonName, "clear")
            peripheral.call(cfg.logMonName, "setCursorPos", 1, 1)
            logTerm = peripheral.wrap(cfg.logMonName)
        end

        -- i'm sorry
        if cfg.termLogEnableColour == "true" then
            enableColour = true
        else
            enableColour = false
        end

        logger = CCLogger.new(
            logFile,
            logTerm,
            cfg.fileLogLevel,
            cfg.termLogLevel,
            enableColour
        )

        logger:i("Logger initialised")
        logger:i("Logger file: " .. cfg.logFilePath)
        logger:i("Logger term: " .. cfg.logMonName)
        logger:i("File log level: " .. logger.fileLogLevel)
        logger:i("Term log level: " .. logger.termLogLevel)
        logger:i("Colour enabled: " .. tostring(logger.enableColour))
    end
    

    ---------------
    -- INIT CHESTARRAY
    ---------------
    local chestArray
    do
        local modem = peripheral.find("modem")
        local networkNames = modem.getNamesRemote()

        local chests = {} -- array of chests to store in

        for k, v in pairs(networkNames) do
            if isInListSegment(cfg.storageBlockIDs, v) then
                if not isInList(cfg.storageBlocksExclude, v) then
                    table.insert(chests, v)
                end
            end
        end

        chestArray = ChestArray.new(
            chests,
            logger
        )
        
    end

    ---------------
    -- INIT SORTINGLIST
    ---------------
    local sortingList
    do
        sortingList = SortingList.new(
            cfg.sortingListFilePath,
            cfg.sortingListBackupFilePath,
            cfg.sortingListBrokenFilePath,
            logger
        )
    end

    ---------------
    -- INIT ITEMHANDLER
    ---------------
    local itemHandler
    do
        itemHandler = ItemHandler.new(
            chestArray,
            sortingList,
            logger
        )
    end

    logger:i("--- INIT COMPLETE ---")

    return setmetatable(
        {
            logger = logger,
            confFile = cfg,
            chestArray = chestArray,
            sortingList = sortingList,
            itemHandler = itemHandler
        },
        StorageSystemMetatable
    )

end

return { new = new }
