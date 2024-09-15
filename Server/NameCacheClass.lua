local R = require("/CCStorage.Common.ResultClass")
local EU = require("/CCStorage.Common.ExecUtils")
local Ok, Err = R.Ok, R.Err

--- @class NameCache
--- @field names table ["itemID"] = "Display name"
--- @field cacheFile string
--- @field backupCacheFile string
--- @field itemHandler ItemHandler
--- @field chestArray ChestArray
--- @field logger Logger
local NameCache = {}

local NameCacheMetatable = {
    __index = NameCache
}

--- @return string
--- Serialises the current list into a string
--- Format: modid:itemid 'Display Name'
function NameCache:serialise()
    local out = ""
    for k, v in pairs(self.names) do
        out = out .. k .. " '" .. v .. "'\n"
    end
    return out
end

function NameCache:saveToFile()
    fs.delete(self.backupCacheFile)
    fs.copy(self.cacheFile, self.backupCacheFile)

    local mainf, mainErr = fs.open(self.cacheFile, "w")
    if mainf == nil then
        return Err("Couldn't open main file: "..mainErr)
    end

    mainf.write(self:serialise())
    mainf.close()

    return Ok()
end

--- @param inp string
--- @return Result nil
--- Deserialises the cache from the given string
--- Format: modid:itemid 'Display Name'
function NameCache:deserialise(inp)
    -- string is the same format as is output by :serialise()

    local arrOut = {}

    -- require("cc.pretty").pretty_print(inp)

    -- iterate over every entry in the file
    local linenum = 1
    -- iterate over lines
    for entry in inp:gmatch("([^\n]+)") do

        -- I LOVE REGEX
        local itemName, displayName = entry:match("(.+) '(.+)'")

        if itemName == nil or displayName == nil then
            return Err("Malformed line "..linenum)
        end
        arrOut[itemName] = displayName
        linenum = linenum + 1
    end

    self.names = arrOut

    return Ok()
end

--- @param inp string filepath
--- @return Result nil
function NameCache:importFromFile(inp)
    local f, err = fs.open(inp, "r")
    if f == nil then
        return Err("Couldn't open file: "..err)
    end
    local fileText = f.readAll()
    f.close()

    if fileText == nil then
        return Err("Sorting list file contents are nil")
    end

    return self:deserialise(fileText)
end

--- @param itemID string
--- @return Result string
function NameCache:getDisplayName(itemID)
    if self.names[itemID] ~= nil then
        return Ok(self.names[itemID])
    else
        local res = self.itemHandler:getItemDetail(itemID):map(
            function(detail)
                self.names[itemID] = detail.displayName
                self.logger:d("Saving nameCache to file")
                self:saveToFile()
                return detail.displayName
            end
        )
        return res
    end

end

--- @return table
--- Get the current cache contents. Format:
--- ```
--- {
---   ["itemID"] = "Display Name"
--- }
--- ```
function NameCache:getDict()
    return self.names
end

--- Get the display names of every item in the system
--- @return Result nil
function NameCache:cacheAllNames()

    local listRes = self.chestArray:list()
    local list
    if listRes:is_ok() then list = listRes:unwrap()
    else return listRes end

    local funcsToExec = {}

    -- store which itemIDs already have a function generated to process
    -- to avoid generating identical functions
    local alreadyProcessed = {}

    for k1, chest in pairs(list) do
        local chestName = chest.chestName
        -- remove these two entries before iterating over items
        list.chestName = nil
        list.chestSize = nil
        for slot, item in pairs(chest) do
            if type(slot) == "string" then
                goto continue
            end
            local itemID = item.name
            if self.names[itemID] == nil and alreadyProcessed[itemID] == nil then
                -- we don't have this one, get it
                local chPeriphRes = Try(peripheral.wrap(chestName),"Peripheral '"..chestName.."' does not exist")
                local chPeriph
                if chPeriphRes:is_ok() then chPeriph = chPeriphRes:unwrap()
                else return chPeriphRes end

                table.insert(funcsToExec,
                    function()
                        local detail = chPeriph.getItemDetail(slot)
                        if detail == nil then
                            self.logger:e("cacheAllNames tried to get detail of empty slot "..slot.." in chest "..chestName)
                        else
                            self.names[itemID] = detail.name
                        end
                    end
                )

                alreadyProcessed[itemID] = true
            end
            ::continue::
        end
    end

    EU.SplitAndExecSafely(funcsToExec)

    self:saveToFile()

    return Ok()
end

--- @param cacheFile string
--- @param backupCacheFile string
--- @param muntedCacheFile string
--- @param itemHandler ItemHandler
--- @param logger Logger
--- @return Result NameCache
--- Create a new NameCache
local function new(cacheFile, backupCacheFile, muntedCacheFile, itemHandler, chestArray, logger)

    if cacheFile == nil or fs.exists(cacheFile) == false or fs.isDir(cacheFile) then
        return Err("cacheFile must be a file path")
    end
    if backupCacheFile == nil then
        return Err("backupCacheFile must be a file path")
    end
    if muntedCacheFile == nil then
        return Err("muntedCacheFile must be a string")
    end

    local nc = setmetatable(
        {
            names = {},
            cacheFile = cacheFile,
            backupCacheFile = backupCacheFile,
            itemHandler = itemHandler,
            chestArray = chestArray,
            logger = logger
        },
        NameCacheMetatable
    )

    local deserialiseRes = nc:importFromFile(cacheFile)
    if deserialiseRes:is_err() then
        logger:e("Failed to read main cache file due to error: '"..deserialiseRes:unwrap_err(logger).."'")
        -- try backup
        local backupDeserialiseRes = nc:importFromFile(backupCacheFile)
        if backupDeserialiseRes:is_err() then
            logger:e("Failed to read both cache files")
            return Err("Failed to read main cache file because '"..deserialiseRes:unwrap_err(logger).."' and failed to read backup cahce file because '"..backupDeserialiseRes:unwrap_err(logger).."'")
        else
            logger:e("Successfully read backup cache file")
            logger:e("Moving broken file to "..muntedCacheFile)
            fs.move(cacheFile, muntedCacheFile)
            fs.delete(cacheFile)
            fs.move(backupCacheFile, cacheFile)
        end
    end

    return Ok(nc)
end

return { new = new }
