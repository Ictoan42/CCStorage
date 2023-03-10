-- object wrapper for the array of storage chests

local chestArray = {}

function splitAndExecSafely(execTable, execLimit)
    -- like parallel.waitForAny(), but splits the table in 224-piece (by default) chunks to avoid filling the event queue
    execLimit = execLimit or 224
    local n = #execTable
    
    if n < execLimit then -- no need to do any of this shit
        parallel.waitForAll(table.unpack(execTable))
    else
        -- actually gotta do the thing
        
        -- how many times will we need to run through?
        local loopCount = math.ceil(n / execLimit)

        -- loop that many times
        for i=1, loopCount do
            -- take items out of the table and exec them
            parallel.waitForAll(
                table.unpack(
                    execTable,
                    ((i-1) * execLimit)+1,
                    math.min(i * execLimit, n)
                )
            )
        end
    end
end

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

    splitAndExecSafely(funcsToExec)

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

function new(chestArr, logger)
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

    splitAndExecSafely(funcsToExec)

    return setmetatable({
        chests = chestArr,
        chestSizes = chestSizesTable,
        logger = logger
    }, CAmetatable)
end

return { new = new }