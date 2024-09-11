-- object wrapper for the array of storage chests

local EU = require("/CCStorage.Common.ExecUtils")
local R = require("/CCStorage.Common.ResultClass")
local SplitAndExecSafely = EU.SplitAndExecSafely
local Ok, Err, Try = R.Ok, R.Err, R.Try

--- @class ChestArray
--- @field chests table
--- @field sortingList SortingList
--- @field chestSizes table
--- @field logger Logger
local chestArray = {}

--- @param liteMode? boolean
--- @return Result
--- Get a list of all items in the system. Return format is and array,
--- in which every entry is the table returned from an individual
--- chestPeriph.list() call. If liteMode == false, each entry also
--- contains a chestName and chestSize entry
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

--- @param getRegistration? boolean whether to include item registration data
--- @return Result
--- Returns a list of every item in the system. Format is a table where:
--- t.itemID = {
---     itemCount,
---     ["reg"] = "destination"|nil, -- chest this item is registered to, if it is registered
---     ["regStatus"] = boolean -- if all instances of this item are in the right chest
--- }
--- OR if getRegistration is false or nil, then the return table
--- is in the format t.itemID = itemCount
function chestArray:sortedList(getRegistration)

    self.logger:d("ChestArray executing method sortedList with getRegistration: "..tostring(getRegistration))

    getRegistration = getRegistration or false

    local arrOut = {}
    local arrIn
    local ret = self:list()
    if ret:is_ok() then
        arrIn = ret:unwrap()
    else
        return ret
    end

    for i=1, #arrIn do -- iterate over every chest
        for k, v in pairs(arrIn[i]) do -- iterate over every item in the chest
            if k ~= "chestName" and k ~= "chestSize" then -- do not iterate over the special entries
                if v ~= nil then -- if there is an item here
                    local itemName = v["name"]
                    if arrOut[itemName] == nil then -- if this items has not been encountered yet

                        if not getRegistration then
                            arrOut[itemName] = v["count"] -- set this item's entry to the count of the currently iterated upon stack
                        else
                            arrOut[itemName] = {v["count"]}
                            arrOut[itemName]["reg"] = self.sortingList:getDest(itemName)
                            arrOut[itemName]["regStatus"] =
                                (arrIn[i]["chestName"] == self.sortingList:getDest(itemName))
                        end

                    else -- if this item has been encountered before

                        if not getRegistration then
                            arrOut[itemName] = arrOut[itemName] + v["count"] -- add the count of the current stack to the existing entry
                        else
                            arrOut[itemName][1] = arrOut[itemName][1] + v["count"]
                            arrOut[itemName]["regStatus"] =
                                arrOut[itemName]["regStatus"]
                                    and
                                (arrIn[i]["chestName"] == self.sortingList:getDest(itemName))
                        end

                    end
                end
            end
        end
    end

    return Ok(arrOut)
end

local CAmetatable = {
    __index = chestArray
}

--- @param chestArr table
--- @param sortingList SortingList
--- @param logger Logger
--- @return Result
--- Create a new ChestArray object. chestArr is an array of chest IDs
local function new(chestArr, sortingList, logger)
    -- chestArr is a 1-indexed array of chest identifiers, e.g. minecraft:chest_0

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
        logger = logger
    }, CAmetatable))
end

return { new = new }
