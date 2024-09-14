-- object wrapper for the storage system as a whole

ConfigFile = require("/CCStorage.Common.ConfigFileClass")
Result = require("/CCStorage.Common.ResultClass")
ChestArray = require("/CCStorage.Server.ChestArrayClass")
ItemHandler = require("/CCStorage.Server.ItemHandlerClass")
SortingList = require("/CCStorage.Server.SortingListClass")
CCLogger = require("/CCLogger") -- this file is in root
local pr = require("cc.pretty")
local prp = pr.pretty_print
Ok, Err, Try = Result.Ok, Result.Err, Result.Try

--TODO:
--add function to find how much space the system has left for any single item
--add function to find how much space the system has left total

--- @class StorageSystem
--- @field logger Logger
--- @field confFile ConfigFile
--- @field chestArray ChestArray
--- @field sortingList SortingList
--- @field itemHandler ItemHandler
local StorageSystem = {}

--- @param listStr string
--- @param s string
--- @return boolean
local function isInList(listStr, s)
    -- internal func for decoding lists from the config file
    -- checks whether the given string "s" is contained within the list

    for i in listStr:gmatch("([^, ]+)") do -- iterate over items in list
        if i == s then
            return true
        end
    end

    return false -- only get here if all checks fail
end

--- @param listStr string
--- @param s string
--- @return boolean
local function isInListSegment(listStr, s)
    -- internal func, used for decoding lists in config file
    -- checks whether any entries in the list are substrings of "s"

    for i in listStr:gmatch("([^, ]+)") do -- iterate over items in list
        if s:find(i) then
            return true
        end
    end

    return false
end

--- @param liteMode? boolean
--- @return Result
--- Passthrough to ChestArray:list()
function StorageSystem:list(liteMode)
    return self.chestArray:list(liteMode)
end

--- @param getRegistration? boolean
--- @return Result
--- Passthrough to ChestArray:sortedList()
function StorageSystem:organisedList(getRegistration)
    return self.chestArray:sortedList(getRegistration)
end

--- @param itemID string
--- @return Result
--- Passthrough to ItemHandler:findItems()
function StorageSystem:findItems(itemID)
    return self.itemHandler:findItems(itemID)
end

--- @param inputChestID string
--- @return Result unregisteredFound
--- Passthrough to ItemHandler:sortAllFromChest()
function StorageSystem:sortFromInput(inputChestID)
    return self.itemHandler:sortAllFromChest(inputChestID)
end

--- @param itemID string
--- @param outputChestID string
--- @param count? number
--- @param toSlot? number
--- @return Result boolean
--- Passthrough to ItemHandler:retrieveItems()
function StorageSystem:retrieve(itemID, outputChestID, count, toSlot)
    return self.itemHandler:retrieveItems(itemID, outputChestID, count, toSlot)
end

--- @return Result integer number of items which have been registered
--- Find all unregistered items in the system and register to the chest they were found in
function StorageSystem:detectAndRegisterItems()
    self.logger:d("StorageSystem executing method detectAndRegisterItems")

    local res = self.itemHandler:findUnregisteredItems()
    local unregisteredItems
    if res:is_ok() then
        unregisteredItems = res:unwrap()
    else return res end

    if unregisteredItems == false then -- no unregistered items found
        return Ok(0)
    end

    -- iterate over all unregistered items, registering them
    local itemsRegistered = 0
    for k, v in ipairs(unregisteredItems) do -- ipairs() to implicitly ignore the "count" entry
        -- addDest just ignores us if we register the same item twice so blind iteration is fine
        -- alright "fine" might be a stretch but it won't crash at least
        local res2 = self.sortingList:addDest(
            v[4], -- item name
            v[1] -- chest name
        )
        if res2:is_err() then return res2
        else itemsRegistered = itemsRegistered + 1 end
    end

    return Ok(itemsRegistered)
end

--- @param itemID string
--- @param chestID string
--- @return Result boolean
--- Passthrough to SortingList:addDest()
function StorageSystem:registerItem(itemID, chestID)
    return self.sortingList:addDest(itemID, chestID)
end

--- @param itemID string
--- @return Result boolean
--- Passthrough to SortingList:removeDest()
function StorageSystem:forgetItem(itemID)
    return self.sortingList:removeDest(itemID)
end

--- @param dumpChest string
--- @return Result integer
--- Passthrough to ItemHandler:cleanUnregisteredItems()
function StorageSystem:cleanUnregisteredItems(dumpChest)
    return self.itemHandler:cleanUnregisteredItems(dumpChest)
end

--- @param dumpChest string|nil
--- @return Result table
--- Passthrough to ItemHandler:cleanMisplacedItems()
function StorageSystem:cleanMisplacedItems(dumpChest)
    return self.itemHandler:cleanMisplacedItems(dumpChest)
end

--- @return Result cfg the ConfigFile object
--- Get the system's configuration
function StorageSystem:getConfig()
    self.logger:d("Running GetConfig")
    return Ok(self.confFile)
end

local StorageSystemMetatable = {
    __index = StorageSystem
}

--- @param confFilePath string
--- @return StorageSystem
--- Create a new StorageSystem object, loading it's config from the
--- given file
local function new(confFilePath)

    -- create config file obj
    local cfg = ConfigFile.new(confFilePath)

    ---------------
    -- INIT LOGGER
    ---------------
    local logger
    do

        local logFile
        local logTerm
        local enableColour

        if cfg.logFilePath ~= "" then -- if a log file has been specified
            --- @type ccTweaked.fs.WriteHandle
            logFile = fs.open(cfg.logFilePath, "w")
            print("Log file is " .. cfg.logFilePath)
        else
            local c = term.getTextColour()
            term.setTextColour(colours.yellow)
            print("No log file was specified")
            term.setTextColour(c)
        end

        if cfg.logMonName ~= "" then -- if a log term has been specified
            peripheral.call(cfg.logMonName, "setTextScale", 0.5)
            peripheral.call(cfg.logMonName, "clear")
            peripheral.call(cfg.logMonName, "setCursorPos", 1, 1)
            --- @type ccTweaked.peripherals.Monitor
            logTerm = peripheral.wrap(cfg.logMonName)
            print("Log monitor is " .. cfg.logMonName)
        else
            local c = term.getTextColour()
            term.setTextColour(colours.yellow)
            print("No log monitor was specified")
            term.setTextColour(c)
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

        if logger == nil then
            error("Could not instantiate logger")
        end

        logger:i("Logger initialised")
        logger:i("Logger file: " .. cfg.logFilePath)
        logger:i("Logger term: " .. cfg.logMonName)
        logger:i("File log level: " .. logger.fileLogLevel)
        logger:i("Term log level: " .. logger.termLogLevel)
        logger:i("Colour enabled: " .. tostring(logger.enableColour))
    end

    ---------------
    -- INIT SORTINGLIST
    ---------------

    -- if sorting list storage file does not exist, create a blank on
    if not fs.exists(cfg.sortingListFilePath) then
        --- @type ccTweaked.fs.WriteHandle
        --- @diagnostic disable-next-line: assign-type-mismatch
        local f = fs.open(cfg.sortingListFilePath, "w")
        f.write("\n")
        f.close()
    end

    local sortingList
    do
        sortingList = SortingList.new(
            cfg.sortingListFilePath,
            cfg.sortingListBackupFilePath,
            cfg.sortingListBrokenFilePath,
            logger
        ):unwrap(logger)
    end

    ---------------
    -- INIT CHESTARRAY
    ---------------
    local chestArray
    do
        --- @type ccTweaked.peripherals.WiredModem
        --- @diagnostic disable-next-line: assign-type-mismatch
        local modem = peripheral.find("modem")
        local networkNames = modem.getNamesRemote()

        local chests = {} -- array of chests to store in

        if cfg.storageBlocksExclude == "" then
            local c = term.getTextColour()
            term.setTextColour(colours.yellow)
            print("No storage blocks have been excluded, is that intentional?")
            print("(Have you set up the config?)")
            term.setTextColour(c)
        end

        for k, v in pairs(networkNames) do
            if isInListSegment(cfg.storageBlockIDs, v) then
                if not isInList(cfg.storageBlocksExclude, v) then
                    table.insert(chests, v)
                end
            end
        end

        chestArray = ChestArray.new(
            chests,
            sortingList,
            logger
        ):unwrap(logger)

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

    local c1 = term.getTextColour()
    term.setTextColour(colours.green)
    print("Initialisation complete")
    term.setTextColour(c1)

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
