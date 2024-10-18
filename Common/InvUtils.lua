-- Some utility functions for use with generic Inventory-type peripherals

local R = require("/CCStorage.Common.ResultClass")
local Ok, Err = R.Ok, R.Err

--- @param invPeriph ccTweaked.peripherals.Inventory
--- @return Result integer
--- Get the number of slots in an inventory which are empty
local function freeSlots(invPeriph)
    if type(invPeriph) ~= "table" then
        return Err("invPeriph is not a table")
    elseif type(invPeriph.list) ~= "function" or type(invPeriph.size) ~= "function" then
        return Err("invPeriph is not a valid inventory peripheral")
    end

    local emptySlots = invPeriph.size()

    -- TODO handle peripheral calls returning nil

    for slot, item in pairs(invPeriph.list()) do
        emptySlots = emptySlots - 1
    end

    return Ok(emptySlots)
end

return { freeSlots = freeSlots }
