-- a machine that handles items
-- it can:
--     sort items with the given sortingList into the given chestArray
--     retrieve items from the given chestArray
--     find items in the given chestArray
--     find any items that aren't registered in the given sortingList

local EU = require("/CCStorage.Common.ExecUtils")
local R = require("/CCStorage.Common.ResultClass")
local Ok, Err, Try = R.Ok, R.Err, R.Try
local SplitAndExecSafely = EU.SplitAndExecSafely

--- @class ItemHandler
--- @field chestArray ChestArray
--- @field sortingList SortingList
--- @field logger Logger
local itemSorter = {}

--- @param slot number
--- @param from InventoryPeripheral
--- @param itemObj? table
--- @return Result
--- Sort an item from 'from' into the system. itemObj can be
--- passed in to avoid a peripheral call
function itemSorter:sortItem(slot, from, itemObj)
    -- uses the stored sortingList to sort the item in the given slot
    -- of the given input chest into the stored chestArray
    --
    -- returns Result<bool> where bool encodes whether an item was moved

    self.logger:d("ItemHandler executing method sortItem")

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
        return Ok(false)
    end

    local itemID = itemObj["name"]

    local dest = self.sortingList:getDest(itemID)

    if dest == nil then
        self.logger:d("ItemHandler:sortItem returning false: item has no stored dest")
        -- if the given item doesn't have a stored dest
        return Ok(false)
    else
        self.logger:d("ItemHandler:sortItem finished successfully")
        fromPeriph.pushItems(dest, slot)
        return Ok(true)
    end
end

local todo = [[

TODO:

convert all the other stuff to use Results
make sortItem resilient to the system running out of space

]]

--- @param from string
--- @return Result
--- Sort all items from the given chest into the system
function itemSorter:sortAllFromChest(from)
    -- uses the stored sortingList to sort all items in the given chest into the stored chestArray

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

    local funcsToExec = {}

    -- iterate over every slot in the chest, sorting the items in parallel
    for k, v in pairs(list) do
        table.insert(
            funcsToExec,
            function()
                local result = self:sortItem(k, from, v)
                result:handle(
                    function(itemMoved)
                        if not itemMoved then
                            self.logger:d("ItemHandler:sortAllFromChest found unregistered item: " .. v["name"])
                            unregisteredFound = true
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

    return Ok(not unregisteredFound) -- invert to align with system-wide concept of "false" meaning bad and "true" meaning good
end

--- @return Result (list of items OR false)
--- Finds a list of items in the system that aren't currently
--- registered and returns it
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

    if #arrOut == 0 then -- if we didn't find anything
        return Ok(false)
    else
        return Ok(arrOut)
    end
end

--- @param dumpChest string
--- @return Result
--- Moves any unregistered items into dumpChest
function itemSorter:cleanUnregisteredItems(dumpChest)
    -- moves all unregistered items to the given output chest

    self.logger:d("ItemHandler executing method cleanUnregisteredItems")

    -- find all unregistered items
    local itemsToClean
    local res = self:findUnregisteredItems() -- if we never found any unregistered items if itemsToClean == false then return false end -- check there's actually enough space
    if res:is_err() then return res
    else itemsToClean = res:unwrap() end

    local dumpChestPeriph
    local dumpChestPeriphRes = Try(
        peripheral.wrap(dumpChest), "Peripheral '"..dumpChest.."' does not exist"
    )
    if dumpChestPeriphRes:is_ok() then
        dumpChestPeriph = dumpChestPeriphRes:unwrap()
    else return dumpChestPeriphRes end

    local freeSpace = dumpChestPeriph.size() - #dumpChestPeriph.list() -- "size of chest" - "number of occupied slots"

    if freeSpace < #res then -- not enough space to safely move items
        return Err("Not enough free space in output")
    end

    -- iterate over every unregistered item that was found
    for k, v in ipairs(itemsToClean) do -- using ipairs ignores the "count" entry without an explicit check
        -- move the item to the output
        dumpChestPeriph.pullItems(v[1], v[2])
    end

    return Ok(nil)
end

--- @param itemName string
--- @return Result
--- Finds the specified item in the system.
--- Return format:
--- {
---  {chestName, slot, count, itemName},
---  {chestName, slot, count, itemName}
--- }
function itemSorter:findItems(itemName)
    -- return the chest name(s) and slot number(s) of all occurrences of the item
    -- returned as an array of array, structured like this:
    -- {
    --  {chestName, slot, count, itemName},
    --  {chestName, slot, count, itemName}
    -- }
    --
    -- also a special entry under the index "count" which is the total number of that item
    --
    -- will still be returned in this format even if only one item is found
    -- will return false if no item is found

    self.logger:d("ItemHandler executing method findItems")

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

    if #arrOut == 0 then -- if we didn't find anything
        return Ok(false)
    else
        return Ok(arrOut)
    end
end

--- @param itemName string
--- @param to string
--- @param count? number
--- @param toSlot? number
--- @return Result
--- Finds the desired item, and moves 'count' of that item
--- to 'to'. 'count' is 64 by default.
function itemSorter:retrieveItems(itemName, to, count, toSlot)
    -- retrieves the given item from the chestArray and places it in the given destination chest

    self.logger:d("ItemHandler executing method retrieveItems")

    count = count or 64 -- if count is not specified, assume a stack

    local toPeriph
    local toPeriphRes = Try(
        peripheral.wrap(to), "Peripheral '"..to.."' does not exist"
    )
    if toPeriphRes:is_ok() then toPeriph = toPeriphRes:unwrap()
    else return toPeriphRes end

    -- find item
    local chestName = self.sortingList:getDest(itemName)

    -- if the item isn't registered
    if chestName == nil then
        --TODO: an item not being registered shouldn't mean it can't be retrieved
        self.logger:d("Cannot retrieve item '"..itemName.."' because it is not registered")
        return Ok(false)
    end

    local itemsInChest = peripheral.call(chestName, "list")

    -- does the chest array contain at least {count} of the item
    if count > self.chestArray:sortedList()[itemName] then -- if we do not have enough
        self.logger:d("Cannot retrieve "..count.." of item '"..itemName.."'; not enough in storage")
        return Ok(false)
    end

    -- iterate over every slot in the chest
    for i=1, peripheral.call(chestName, "size") do

        if itemsInChest[i] ~= nil then -- if this slot contains an item
            if itemsInChest[i]["name"] == itemName then
                -- we found the item
                if itemsInChest[i]["count"] >= count then
                    -- there is enough of this item in the first stack to do the move in one go
                    toPeriph.pullItems(
                        chestName, -- to pull from the chest we found the item in
                        i, -- from the slot we found the item in
                        count, -- with the count that was specified
                        toSlot -- to the slot specified
                    )
                    return Ok(true)
                else
                    -- move what is there, then recur this function with a reduced desired count
                    print("Moving what's there")
                    local numberOfItemsMoved = toPeriph.pullItems(
                        chestName,
                        i,
                        nil, -- don't specify a count so it moves all items there
                        toSlot
                    )

                    self:retrieveItems(
                        itemName,
                        to,
                        count - numberOfItemsMoved, -- no need to clamp because count has to be larger than numberOfItemsMoved for us to be here in the first place
                        toSlot
                    )
                    return Ok(true)
                end
            end
        end
    end

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
