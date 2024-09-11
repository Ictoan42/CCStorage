-- a class representing a remote storage system manager

-- effectively just a shim API to send standard method calls over a modem connection

local R = require("/CCStorage/Common/ResultClass")
local PR = require("cc.pretty")
local PRW = function(str) return PR.render(PR.pretty(str)) end
local Ok, Err, Try, Coerce = R.Ok, R.Err, R.Try, R.Coerce

--- @param response table
--- @return Result (Result<{Result, "methodName"}>)
--- Parses a table of format { RetValTable, "methodName"} into { Result, "methodName"}
local function decodeResponse(response)
    if response == nil then
        return Err("Argument is nil")
    elseif response[2] == nil then
        return Err("Input contains no method name")
    end

    local outTab = {}
    local convertRes = Coerce(response[1])
    if convertRes:is_ok() then
        outTab[1] = convertRes:unwrap()
    else
        return Err("Does not contain a valid result:\n\n"..PRW(response))
    end
    outTab[2] = response[2]
    return Ok(outTab)
end

--- @class RemoteStorageSystem
--- @field cfg ConfigFile
--- @field outPort number
--- @field inPort number
--- @field modem modem
--- @field blocking boolean
local RemoteStorageSystem = {}

--- @param liteMode? boolean
--- @return Result
--- Get a list of all items in the system. Return format is and array,
--- in which every entry is the table returned from an individual
--- chestPeriph.list() call. If liteMode == false, each entry also
--- contains a chestName and chestSize entry
function RemoteStorageSystem:list(liteMode)
    return self:sendReq({"list", liteMode})
end

--- @return Result
--- Returns a list of every item in the system. Format is
--- a table where t["itemID"] = itemCount
function RemoteStorageSystem:organisedList()
    return self:sendReq({"organisedList"})
end

--- @param itemID string
--- @return Result
--- Finds the specified item in the system.
--- Return format:
--- {
---  {chestName, slot, count, itemName},
---  {chestName, slot, count, itemName}
--- }
function RemoteStorageSystem:findItems(itemID)
    return self:sendReq({"findItems", itemID})
end

--- @param inputChestID string
--- @return Result unregisteredFound whether or not any unregistered items were found in the input chest
--- Sort all items from the given chest into the system
function RemoteStorageSystem:sortFromInput(inputChestID)
    return self:sendReq({"sortFromInput", inputChestID})
end

--- @param itemID string
--- @param outputChestID string
--- @param count? number
--- @param toSlot? number
--- @return Result returned Result<bool> if any items were retrieved
--- Finds the desired item, and moves 'count' of that item
--- to 'to'. 'count' is 64 by default.
function RemoteStorageSystem:retrieve(itemID, outputChestID, count, toSlot)
    return self:sendReq({"retrieve", itemID, outputChestID, count, toSlot})
end

--- @return Result (number of items registered)
--- Find all unregistered items in the system and register to the
--- chest they were found in
function RemoteStorageSystem:detectAndRegisterItems()
    return self:sendReq({"detectAndRegisterItems"})
end

--- @param itemID string
--- @param chestID string
--- @return Result (boolean)
--- Registers the given item to the given chest
function RemoteStorageSystem:registerItem(itemID, chestID)
    return self:sendReq({"registerItem", itemID, chestID})
end

--- @param itemID string
--- @return Result (boolean)
--- Unregisters the given item from the system
function RemoteStorageSystem:forgetItem(itemID)
    return self:sendReq({"forgetItem", itemID})
end

--- @param dumpChest string
--- @return Result itemsMoved the number of items that have been moved
--- Moves any unregistered items into dumpChest
function RemoteStorageSystem:cleanUnregisteredItems(dumpChest)
    return self:sendReq({"cleanUnregisteredItems", dumpChest})
end

--- @return Result cfg the ConfigFile object
--- Get the system's configuration
function RemoteStorageSystem:getConfig()
    return self:sendReq({"getConfig"})
end

function RemoteStorageSystem:sendReq(arr)
    -- sends the request in either blocking or non blocking mode depending
    -- on what the RSS was set to do on object creation

    if self.blocking then
        return self:sendBlockingReq(arr)
    else
        self:sendNonBlockingReq(arr)
    end

end

function RemoteStorageSystem:sendBlockingReq(arr)
    -- this should only be used internally
    if type(arr) ~= "table" then -- bug in this very class
        error("RemoteStorageSystemClass shat itself, non-table passed to sendBlockingReq")
    end
    self.modem.transmit(self.outPort, self.inPort, arr)
    local resEv = table.pack(os.pullEvent("modem_message"))
    return decodeResponse(resEv[5])
end

function RemoteStorageSystem:sendNonBlockingReq(arr)
    -- should also only be used internally
    -- instead of waiting for a response, this simply doesn't
    -- self:handleNonBlockingResponse should be used to interpret
    if type(arr) ~= "table" then -- bug in this very class
        error("RemoteStorageSystemClass shat itself, non-table passed to sendBlockingReq")
    end
    self.modem.transmit(self.outPort, self.inPort, arr)
end

local RemoteStorageSystemMetatable = {
    __index = RemoteStorageSystem
}

local function new(modem, port, returnPort, isNonBlocking)
    -- args:
    --  - modem: modem object to send data through
    --  - port: integer - port for outbound comms, defaults to 20
    --  - returnPort: integer - port for inbound comms, defaults to 21
    --  - isNonBlocking: boolean - whether the RSS will leave it to the user to handle responses, defaults to false

    port = port or 20
    returnPort = returnPort or 21
    isNonBlocking = isNonBlocking or false

    -- get config
    modem.open(returnPort)
    modem.transmit(port, returnPort, {"getConfig"})
    local responseEv = table.pack(os.pullEvent("modem_message"))
    local cfgResponse = responseEv[5]

    return setmetatable({
            cfg = cfgResponse,
            outPort = port,
            inPort = returnPort,
            modem = modem,
            blocking = not isNonBlocking
        },
        RemoteStorageSystemMetatable
    )

end

return { new = new, DecodeResponse = decodeResponse }
