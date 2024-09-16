-- object wrapper for the array of storage chests

local EU = require("/CCStorage.Common.ExecUtils")
local R = require("/CCStorage.Common.ResultClass")
local SplitAndExecSafely = EU.SplitAndExecSafely
local Ok, Err, Try = R.Ok, R.Err, R.Try

--- @class ChestArray
--- @field chests table
--- @field sortingList SortingList
--- @field nameCache NameStackCache
--- @field itemHandler ItemHandler
--- @field chestSizes table
--- @field logger Logger
local chestArray = {}

--- @param liteMode? boolean
--- @return Result table
--- Get a list of all items in the system.
--- Return format:
--- ```
--- {
---   {
---     [1] = { -- if slot 1 contains 8 grass blocks
---       count = 8,
---       name = "minecraft:grass_block"
---     },
---     [2] = nil, -- if slot 2 is empty
---     ... for each item in this chest
---
---     -- VV These two only if liteMode==false
---     ["chestName"] = "minecraft:chest_42",
---     ["chestSize"] = 27
---   },
---   ... for each chest
--- }
--- ```
function chestArray:list(liteMode)
    -- takes the list() func of every chest in the array and concatenates
    -- them together adds special "chestName" and "chestSize" entries in
    -- the per-chest array to allow for finding items "liteMode" is a bool
    -- that, if enabled, does not put the "chestName" and "chestSize" entries,
    -- to save on periph calls
    --
    -- returns Result<list> where list is the above described list of items

    self.logger:d("ChestArray executing method list with liteMode setting " .. tostring(liteMode))

    liteMode = liteMode or false

    local arrOut = {}

    local funcsToExec = {}
    for k, v in pairs(self.chests) do
        if not liteMode then

            table.insert(
                funcsToExec,

                function()
                    local contentsRes = Try(
                        peripheral.call(v, "list"), "Peripheral '"..v.."' does not exist"
                    )
                    contentsRes:handle(
                        function(contents)
                            contents["chestName"] = v
                            contents["chestSize"] = self.chestSizes[v]
                            table.insert(arrOut, contents)
                        end,
                        function(err)
                            self.logger:e("ChestArray:list() error: "..err)
                        end
                    )
                end

            )

        else

            table.insert(
                funcsToExec,

                function()
                    local ret = Try(
                        peripheral.call(v, "list"), "Peripheral '"..v.."' does not exist"
                    )
                    ret:handle(
                        function(contents)
                            table.insert(arrOut, contents)
                        end,
                        function(err)
                            self.logger:e("ChestArray:list() error: "..err)
                        end
                    )
                end
            )

        end
    end

    SplitAndExecSafely(funcsToExec)

    return Ok(arrOut)
end

--- @param getReg? boolean whether to include item registration data
--- @param getDisplayName? boolean
--- @param getMaxCount? boolean
--- @param getSpace? boolean
--- @return Result table
--- Get a list of every item in the system.
---
--- Return format:
--- ```
--- {
---   ["minecraft:grass_block"] = {
---     ["count"] = integer,
---     ["reg"] = {"destinationPeriphID"|nil, isCorrectBool}, -- only if getReg == true
---     ["maxCount"] = integer, -- only if getMaxCount == true AND item is registered
---     ["displayName"] = "Display Name"|nil, -- only if getDisplayName == true AND item is registered
---     ["space"] = {spaceLeftInt, chestCapacityInt}, -- only if getSpace == true AND item is registered
---   },
--- }
--- ```
function chestArray:sortedList(getReg, getMaxCount, getDisplayName, getSpace)

    getReg = getReg or false
    getMaxCount = getMaxCount or false
    getDisplayName = getDisplayName or false
    getSpace = getSpace or false

    local arrOut = {}
    local itemList
    local listR = self:list()
    if listR:is_ok() then
        itemList = listR:unwrap()
    else
        return listR
    end

    local cache = self.nameCache:getDict()

    local spaces
    if getSpace then
        local spacesR = self.itemHandler:getAllItemSpaces()
        if spacesR:is_ok() then spaces = spacesR:unwrap()
        else return spacesR end
    end

    for k1, chestContents in pairs(itemList) do
        local chestName = chestContents.chestName
        local chestSize = chestContents.chestSize
        for slot, item in pairs(chestContents) do -- iterate over every item in the chest
            if type(slot) == "string" then
                goto continue
            end
            local itemName = item.name
            if arrOut[itemName] == nil then -- if this items has not been encountered yet

                local thisItem = {}

                thisItem.count = item.count

                if getReg then
                    local dest = self.sortingList:getDest(itemName)
                    local isCorrect = (chestName == self.sortingList:getDest(itemName))
                    thisItem.reg = {dest, isCorrect}
                end

                if getMaxCount then
                    local itemCache = cache[itemName]
                    local maxCount
                    if itemCache ~= nil then
                        maxCount = itemCache[2]
                    else
                        maxCount = nil
                    end
                    thisItem.maxCount = maxCount
                end

                if getDisplayName then
                    local itemCache = cache[itemName]
                    local displayName
                    if itemCache ~= nil then
                        displayName = itemCache[1]
                    else
                        displayName = nil
                    end
                    thisItem.displayName = displayName
                end

                if getSpace then
                    local spaceLeft = spaces[itemName]
                    local itemCache = cache[itemName]
                    if spaceLeft ~= nil and itemCache ~= nil then
                        thisItem.space = {spaceLeft, chestSize*itemCache[2]}
                    end
                end

                arrOut[itemName] = thisItem

            else -- if this item has been encountered before

                arrOut[itemName].count = arrOut[itemName].count + item.count

                if getReg then
                    arrOut[itemName].reg[2] =
                        arrOut[itemName].reg[2]
                            and
                        (chestName == self.sortingList:getDest(itemName))
                end

            end
            ::continue::
        end
    end

    return Ok(arrOut)
end

local CAmetatable = {
    __index = chestArray
}

--- @param chestArr table array of chest ID string, e.g. "minecraft:chest_17"
--- @param sortingList SortingList
--- @param nameCache NameStackCache
--- @param itemHandler ItemHandler
--- @param logger Logger
--- @return Result ChestArray
--- Create a new ChestArray object.
local function new(chestArr, sortingList, nameCache, itemHandler, logger)

    -- safety check
    if #chestArr == 0 then
        return Err("Given array of peripheral IDs is empty")
    end

    -- get sizes of chests
    local funcsToExec = {}
    local chestSizesTable = {}

    for k, v in pairs(chestArr) do
        table.insert(
            funcsToExec,
            function()
                chestSizesTable[v] = Try(
                    peripheral.call(v, "size"), "Peripheral '"..v.."' does not exist"
                ):ok_or(function(err)
                    logger:e("Failed to get size of storage block while constructing ChestArray: "..err)
                    logger:e("Ignoring specified peripheral ID")
                    chestArr[k] = nil
                end)
            end
        )
    end

    SplitAndExecSafely(funcsToExec)

    return Ok(setmetatable({
        chests = chestArr,
        sortingList = sortingList,
        chestSizes = chestSizesTable,
        nameCache = nameCache,
        itemHandler = itemHandler,
        logger = logger
    }, CAmetatable))
end

return { new = new }
