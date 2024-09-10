-- object wrapper for the array of storage chests

local EU = require("CCStorage.Common.ExecUtils")
local SplitAndExecSafely = EU.SplitAndExecSafely

local chestArray = {}

function chestArray:list(liteMode)
    -- takes the list() func of every chest in the array and concatenates them together
    -- adds special "chestName" and "chestSize" entries in the per-chest array to allow for finding items
    -- "liteMode" is a bool that, if enabled, does not put the "chestName" and "chestSize" entries, to save on periph calls

    self.logger:d("ChestArray executing method list with liteMode setting " .. tostring(liteMode))

    liteMode = liteMode or false

    local arrOut = {}

    local funcsToExec = {}
    for k, v in pairs(self.chests) do
        if not liteMode then
            
            table.insert(
                funcsToExec,
                
                function()
                    local contents = peripheral.call(v, "list")
                    contents["chestName"] = v
                    contents["chestSize"] = self.chestSizes[v]
                    table.insert(arrOut, contents)
                end

            )

        else
            
            table.insert(
                funcsToExec,

                function()
                    local contents = peripheral.call(v, "list")
                    table.insert(arrOut, contents)
                end
                
            )

        end
    end

    SplitAndExecSafely(funcsToExec)

    return arrOut
end

function chestArray:sortedList()
    -- takes the output of :list() and organises it

    self.logger:d("ChestArray executing method sortedList")

    -- returns an array with the key-value relationship being "modid:itemid" - numOfItem

    local arrOut = {}
    local arrIn = self:list(true)
    
    for i=1, #arrIn do -- iterate over every chest
        for k, v in pairs(arrIn[i]) do -- iterate over every item in the chest
            if k ~= "chestName" and k ~= "chestSize" then -- do not iterate over the special entries
                if v ~= nil then -- if there is an item here
                    if arrOut[v["name"]] == nil then -- if this items has not been encountered yet
                        arrOut[v["name"]] = v["count"] -- set this item's entry to the count of the currently iterated upon stack
                    else -- if this item has been encountered before
                        arrOut[v["name"]] = arrOut[v["name"]] + v["count"] -- add the count of the current stack to the existing entry
                    end
                end
            end
        end
    end

    return arrOut
end

local CAmetatable = {
    __index = chestArray
}

local function new(chestArr, logger)
    -- chestArr is a 1-indexed array of chest identifiers, e.g. minecraft:chest_0

    -- get sizes of chests
    local funcsToExec = {}
    local chestSizesTable = {}

    for k, v in pairs(chestArr) do
        table.insert(
            funcsToExec,
            function()
                chestSizesTable[v] = peripheral.call(v, "size")
            end
        )
    end

    SplitAndExecSafely(funcsToExec)

    return setmetatable({
        chests = chestArr,
        chestSizes = chestSizesTable,
        logger = logger
    }, CAmetatable)
end

return { new = new }