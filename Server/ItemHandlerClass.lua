-- a machine that handles items
-- it can:
--     sort items with the given sortingList into the given chestArray
--     retrieve items from the given chestArray
--     find items in the given chestArray
--     find any items that aren't registered in the given sortingList

local EU = require("/CCStorage.Common.ExecUtils")
local R = require("/CCStorage.Common.ResultClass")
local IU = require("/CCStorage.Common.InvUtils")
local Ok, Err, Try = R.Ok, R.Err, R.Try
local SplitAndExecSafely = EU.SplitAndExecSafely
local PRP = require("cc.pretty").pretty_print

--- @class ItemHandler
--- @field chestArray ChestArray
--- @field sortingList SortingList
--- @field logger Logger
local itemSorter = {}

--- @param slot number
--- @param from string
--- @param itemObj? table
--- @return Result table whether the item was sorted, and a reason if it wasn't
--- Sort an item from 'from' into the system. itemObj can be passed in to avoid a peripheral call.
--- Return format:
--- ```
--- {
---   boolean,                                 -- true if there were no issues, false otherwise
---   "unregistered"|"no_item"|"no_space"|nil, -- a reason if it wasn't
---   integer,                                 -- the number of items that couldn't be sorted
---   integer,                                 -- the number of items that were sorted successfuly
--- }
--- ```
function itemSorter:sortItem(slot, from, itemObj)
    -- uses the stored sortingList to sort the item in the given slot
    -- of the given input chest into the stored chestArray
    --
    -- returns Result<bool> where bool encodes whether an item was moved

    self.logger:d("ItemHandle executing method sortItem")

    local fromPeriphRes = Try(peripheral.wrap(from), "Peripheral '"..from.."' does not exist")
    local fromPeriph
    if fromPeriphRes:is_ok() then
        fromPeriph = fromPeriphRes:unwrap()
    else
        self.logger:e("Tried to sort item from peripheral '"..from..", which doesn't exist")
        return fromPeriphRes
    end

    -- itemObj can be passed in to dodge a peripheral call
    itemObj = itemObj or fromPeriph.getItemDetail(slot)

    if itemObj == nil then -- if the given slot in "from" is empty
        return Ok({false, "no_item", 0, 0})
    end

    local itemID = itemObj["name"]

    local dest = self.sortingList:getDest(itemID)

    if dest == nil then
        -- if the given item doesn't have a stored dest
        return Ok({false, "unregistered", itemObj["count"], 0})
    else
        if not peripheral.isPresent(dest) then
            self.logger:e("sortItem failed to sort item '"..itemID.."' because peripheral '"..dest.."' does not exist")
            return Err("Peripheral '"..dest.."' does not exist")
        end
        local moved = fromPeriph.pushItems(dest, slot)
        if moved == itemObj["count"] then -- if all items in the slot were moved
            return Ok({true, nil, 0, moved})
        else
            return Ok({false, "no_space", itemObj["count"] - moved, moved}) -- how many were left over
        end
    end
end

--- @class SortOutcome
--- @field [integer] boolean success
--- @field unregistered integer the number of items found that are unregistered
--- @field no_space integer the number of items found that couldn't be moved due to lack of space
--- @field successful integer the number of items that were successfully sorted
local SortOutcome = {}

--- @param from string
--- @return Result SortOutcome info about what the outcome was
--- Sort all items from the given chest into the system
--- Return format:
--- ```
--- {
---   boolean, -- true if there were no problems, false if there were
---   ["unregistered"] = integer, -- how many items couldn't be sorted because they are not registered
---   ["no_space"] = integer, -- how many items couldn't be sorted because their dest chest is full
---   ["successful"] = integer, -- how many items were sorted successfully
--- }
--- ```
function itemSorter:sortAllFromChest(from)
    -- uses the stored sortingList to sort all items in the given chest into the stored chestArray

    if type(from) ~= "string" then
        return Err("Source peripheral ID must be a string")
    end

    self.logger:d("ItemHandler executing method sortAllFromChest")

    local fromPeriphRes = Try(peripheral.wrap(from), "Peripheral '"..from.."' does not exist")
    local fromPeriph
    if fromPeriphRes:is_ok() then
        fromPeriph = fromPeriphRes:unwrap()
    else
        self.logger:e("Tried to sort items from chest '"..from.."', which doesn't exist")
        return fromPeriphRes
    end

    local list = fromPeriph.list()

    local unregisteredFound = false

    local retInfo = {true}
    retInfo["no_space"] = 0
    retInfo["unregistered"] = 0
    retInfo["successful"] = 0

    local funcsToExec = {}

    -- iterate over every slot in the chest, sorting the items in parallel
    for k, v in pairs(list) do
        table.insert(
            funcsToExec,
            function()
                local result = self:sortItem(k, from, v)
                result:handle(
                    function(outcomeInfo)
                        retInfo["successful"] = retInfo["successful"] + outcomeInfo[4]
                        if not outcomeInfo[1] then -- if not all items were sorted
                            retInfo[1] = false
                            local reason = outcomeInfo[2]
                            retInfo[reason] = retInfo[reason] + outcomeInfo[3]
                            -- if reason == "unregistered" then
                            --     retInfo["unregistered"] = retInfo["unregistered"] + outcomeInfo[3]
                            -- elseif reason == "no_space" then
                            --     retInfo["no_space"] = retInfo["no_space"] + outcomeInfo[3]
                            -- end
                        end
                    end,
                    function(err)
                        self.logger:e("Failed to sort item: '"..err.."'")
                    end
                )
            end
        )
    end

    SplitAndExecSafely(funcsToExec)

    -- return Ok(not unregisteredFound) -- invert to align with system-wide concept of "false" meaning bad and "true" meaning good
    return Ok(retInfo)
end

--- @return Result table list of items, maybe empty
--- Finds all items in the system which don't have a registered storage location
--- Return format:
--- {
---  {chestName, slot, count, itemName},
---  {chestName, slot, count, itemName}
--- }
function itemSorter:findUnregisteredItems()
    -- returns the items found in the system which were not registered
    -- return format is the same as :findItems()

    self.logger:d("ItemHandler executing method findUnregisteredItems")

    local bigList
    local res = self.chestArray:list()
    if res:is_ok() then
        bigList = res:unwrap()
    else
        return res
    end
    local arrOut = {}
    arrOut["count"] = 0

    -- copied from :findItems() with minor changes
    for k, i in pairs(bigList) do -- iterate over every chest
        -- "i" is an array like how chestPeriph.list() returns
        for l, j in pairs(i) do -- iterate over every entry in array
            if l ~= "chestName" and l ~= "chestSize" then -- ignore the special entries
                if self.sortingList:getDest(j["name"]) == nil then -- the item in this slot is unregistered

                    table.insert(arrOut,
                        {
                            i["chestName"], -- the name of the chest
                            l, -- the slot it's in (the index in the list() result)
                            j["count"],
                            j["name"]
                        }
                    )

                    arrOut["count"] = arrOut["count"] + j["count"]

                end
            end
        end
    end

    return Ok(arrOut)
end

--- @return Result table list of items, maybe empty
--- Finds all items in the system which are registered, but in the wrong place
--- Return format:
--- {
---  {chestName, slot, count, itemName},
---  {chestName, slot, count, itemName}
--- }
function itemSorter:findMisplacedItems()
    -- returns the items found in the system which were not registered
    -- return format is the same as :findItems()

    self.logger:d("ItemHandler executing method findMisplaceddItems")

    local bigList
    local res = self.chestArray:list()
    if res:is_ok() then
        bigList = res:unwrap()
    else
        return res
    end
    local arrOut = {}
    arrOut["count"] = 0

    -- copied from :findItems() with minor changes
    for k, i in pairs(bigList) do -- iterate over every chest
        -- "i" is an array like how chestPeriph.list() returns
        for l, j in pairs(i) do -- iterate over every entry in array
            if l ~= "chestName" and l ~= "chestSize" then -- ignore the special entries
                if
                    -- if this item is in a different chest to the one it's registered to
                    self.sortingList:getDest(j["name"]) ~= i["chestName"]
                    -- but the item IS registered _somewhere_
                    and self.sortingList:getDest(j["name"]) ~= nil
                then
                    table.insert(arrOut,
                        {
                            i["chestName"], -- the name of the chest
                            l, -- the slot it's in (the index in the list() result)
                            j["count"],
                            j["name"]
                        }
                    )
                    arrOut["count"] = arrOut["count"] + j["count"]

                end
            end
        end
    end

    return Ok(arrOut)
end

--- @param dumpChest string peripheral ID
--- @return Result integer the number of items that have been moved
--- Moves any unregistered items into dumpChest
function itemSorter:cleanUnregisteredItems(dumpChest)
    -- moves all unregistered items to the given output chest

    if type(dumpChest) ~= "string" then
        return Err("Output chest ID must be a string")
    end

    self.logger:d("ItemHandler executing method cleanUnregisteredItems")

    -- find all unregistered items
    local itemsToClean
    local res = self:findUnregisteredItems()
    if res:is_err() then return res
    else itemsToClean = res:unwrap() end

    --- @type ccTweaked.peripherals.Inventory
    local dumpChestPeriph
    local dumpChestPeriphRes = Try(
        peripheral.wrap(dumpChest), "Peripheral '"..dumpChest.."' does not exist"
    )
    if dumpChestPeriphRes:is_ok() then
        dumpChestPeriph = dumpChestPeriphRes:unwrap()
    else return dumpChestPeriphRes end

    local freeSpace = IU.freeSlots(dumpChestPeriph):unwrap()

    if freeSpace < #itemsToClean then -- not enough space to safely move items
        return Err("Ran out of space in dump chest")
    end

    -- iterate over every unregistered item that was found
    local itemsMoved = 0
    for k, v in ipairs(itemsToClean) do -- using ipairs ignores the "count" entry without an explicit check
        -- move the item to the output
        itemsMoved = itemsMoved + dumpChestPeriph.pullItems(v[1], v[2])
    end

    return Ok(itemsMoved)
end

--- @param dumpChest string|nil Peripheral ID to dump items into if there isn't space in their correct chest. If nil, this function will err if it runs out of space
--- @return Result table {numberOfItemsCleaned, numberOfItemsDumped}
--- Finds any items in the system that are registered but misplaced, and moves them to the right place
function itemSorter:cleanMisplacedItems(dumpChest)
    -- find all misplaced items, sort each one
    self.logger:d("ItemHandler executing method cleanMisplacedItems")

    if type(dumpChest) ~= "string" and type(dumpChest) ~= "nil" then
        return Err("Dump chest ID must be a string or nil")
    end

    --- @type ccTweaked.peripherals.Inventory|nil
    local dumpChestPeriph
    local dumpFreeSpace
    if dumpChest ~= nil then
        local dumpChestPeriphRes = Try(
            peripheral.wrap(dumpChest), "Peripheral '"..dumpChest.."' does not exist"
        )
        if dumpChestPeriphRes:is_ok() then
            dumpChestPeriph = dumpChestPeriphRes:unwrap()
        else return dumpChestPeriphRes end
        dumpFreeSpace = IU.freeSlots(dumpChestPeriph):unwrap()
    end


    -- find all misplaced items

    -- ```
    -- {
    --  {chestName, slot, count, itemName},
    --  {chestName, slot, count, itemName}
    -- }
    -- ```
    --- @type table
    local itemsToClean
    local res = self:findMisplacedItems()
    if res:is_err() then return res
    else itemsToClean = res:unwrap() end

    -- iterate over every misplaced item that was found
    local itemsCleaned = 0
    local itemsDumped = 0
    for k, v in ipairs(itemsToClean) do -- using ipairs ignores the "count" entry without an explicit check
        -- move the item to the output
        -- itemsMoved = itemsMoved + dumpChestPeriph.pullItems(v[1], v[2])
        local sortRes = self:sortItem(v[2], v[1])
        if sortRes:is_ok() then
            --- {
            ---   boolean,                                 -- true if there were no issues, false otherwise
            ---   "unregistered"|"no_item"|"no_space"|nil, -- a reason if it wasn't
            ---   integer,                                 -- the number of items that couldn't be sorted
            ---   integer,                                 -- the number of items that were sorted successfuly
            --- }
            local sortOutcome = sortRes:unwrap()
            itemsCleaned = itemsCleaned + sortOutcome[4]
            if sortOutcome[1] == false then -- if some items couldn't be moved
                if sortOutcome[2] == "unregistered" then
                    return Err("Tried to sort an unregistered item? findMisplacedItems fucked up")
                elseif sortOutcome[2] == "no_item" then
                    return Err("Tried to sort an item that doesn't exist? findMisplacedItems fucked up")
                elseif sortOutcome[2] == "no_space" then
                    if dumpChestPeriph == nil then
                        return Err("Ran out of space (no dump chest specified)")
                    else
                        local moved = dumpChestPeriph.pullItems(v[1], v[2])
                        if moved < sortOutcome[3] then
                            return Err("Ran out of space in dump chest")
                        else
                            itemsDumped = itemsDumped + moved
                        end
                    end
                end
            end
        else
            return sortRes
        end
    end

    return Ok({itemsCleaned, itemsDumped})
end

--- @param itemName string
--- @return Result table list of items
--- Finds the specified item in the system.
--- Return format:
--- ```
--- {
---   {chestName, slot, count, itemName},
---   {chestName, slot, count, itemName},
---   ["count"] = totalCountInt
--- }
--- ```
function itemSorter:findItems(itemName)
    self.logger:d("ItemHandler executing method findItems")

    if type(itemName) ~= "string" then
        return Err("Item ID must be a string")
    end

    local bigList
    local res = self.chestArray:list()
    if res:is_ok() then
        bigList = res:unwrap()
    else
        return res
    end
    local arrOut = {}
    arrOut["count"] = 0

    for k, i in pairs(bigList) do -- iterate over every chest
        -- "i" is an array like how chestPeriph.list() returns
        for l, j in pairs(i) do -- iterate over every entry in array
            if l ~= "chestName" and l ~= "chestSize" then -- ignore the special entries
                if j["name"] == itemName then

                    table.insert(arrOut,
                        {
                            i["chestName"], -- the name of the chest
                            l, -- the slot it's in (the index in the list() result)
                            j["count"],
                            j["name"]
                        }
                    )

                    arrOut["count"] = arrOut["count"] + j["count"]

                end
            end
        end
    end

    return Ok(arrOut)
end

--- @param itemName string item ID
--- @param destination string peripheral ID
--- @param count? number default 64
--- @param toSlot? number
--- @return Result boolean if any items were retrieved
--- Finds the desired item, and moves `count` of that item
--- to `destination`.
function itemSorter:retrieveItems(itemName, destination, count, toSlot)
    -- search through the system, find the first 'count' instances of 'itemName'

    if type(itemName) ~= "string" then
        return Err("Item ID must be a string")
    elseif type(destination) ~= "string" then
        return Err("Destination peripheral ID must be a string")
    end

    self.logger:d("ItemHandler executing method retrieveItems")

    --TODO: find the correct stack size
    local stackSize = 64
    count = count or stackSize -- if count is not specified, assume a stack

    --- @type ccTweaked.peripherals.Inventory
    local toPeriph
    local toPeriphRes = Try(
        peripheral.wrap(destination), "Peripheral '"..destination.."' does not exist"
    )
    if toPeriphRes:is_ok() then toPeriph = toPeriphRes:unwrap()
    else return toPeriphRes end

    -- find item
    local itemsRes = self:findItems(itemName)
    local allItems
    local filteredItems = {}
    filteredItems.count = 0
    if itemsRes:is_ok() then
        allItems = itemsRes:unwrap()
        if allItems.count < count then
            return Err("Not enough items in the system")
        end
        -- filter list to only get the right number of items
        for k, v in pairs(allItems) do
            if
                type(v) == "table" and
                filteredItems.count < allItems.count
            then
                local stillToMove = count - filteredItems.count
                if stillToMove == 0 then
                    break
                end
                if stillToMove >= stackSize then
                    -- move this whole stack
                    table.insert(filteredItems, v)
                    filteredItems.count = filteredItems.count + v[3]
                elseif stillToMove < stackSize then
                    -- move only what we need to
                    table.insert(filteredItems,
                        {v[1],v[2],stillToMove,v[4]}
                    )
                    filteredItems.count = filteredItems.count + stillToMove
                end
            end
        end
    else
        return itemsRes
    end

    local spaceInDest = IU.freeSlots(toPeriph):unwrap()

    if #filteredItems > spaceInDest then
        return Err("Not enough space in destination")
    end

    -- construct a function to move each item in filteredList
    local funcsToExec = {}

    for k,v in pairs(filteredItems) do
        table.insert(funcsToExec,
            function()
                if type(v) == "table" then -- skip "count"
                    toPeriph.pullItems(
                        v[1],
                        v[2],
                        v[3]
                    )
                end
            end
        )
    end

    SplitAndExecSafely(funcsToExec)

    return Ok(true)
end

local itemSorterMetatable = {
    __index = itemSorter,
}

--- @param chestArray ChestArray
--- @param sortingList SortingList
--- @param logger Logger
--- @return ItemHandler
--- Creates a new ItemHandler
local function new(chestArray, sortingList, logger)
    return setmetatable(
        {
            chestArray = chestArray,
            sortingList = sortingList,
            logger = logger
        },
        itemSorterMetatable
    )
end

return { new = new }
