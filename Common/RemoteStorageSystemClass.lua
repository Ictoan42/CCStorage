-- a class representing a remote storage system manager

-- effectively just a shim API to send standard method calls over a modem connection

local RemoteStorageSystem = {}

function RemoteStorageSystem:list(liteMode)
    return self:sendReq({"list", liteMode})
end

function RemoteStorageSystem:organisedList()
    return self:sendReq({"organisedList"})
end

function RemoteStorageSystem:findItems(itemID)
    return self:sendReq({"findItems", itemID})
end

function RemoteStorageSystem:sortFromInput(inputChestID)
    return self:sendReq({"sortFromInput", inputChestID})
end

function RemoteStorageSystem:retrieve(itemID, outputChestID, count, toSlot)
    return self:sendReq({"retrieve", itemID, outputChestID, count, toSlot})
end

function RemoteStorageSystem:detectAndRegisterItems()
    return self:sendReq({"detectAndRegisterItems"})
end

function RemoteStorageSystem:registerItem(itemID, chestID)
    return self:sendReq({"registerItem", itemID, chestID})
end

function RemoteStorageSystem:forgetItem(itemID)
    return self:sendReq({"forgetItem", itemID})
end

function RemoteStorageSystem:cleanUnregisteredItems(dumpChest)
    return self:sendReq({"cleanUnregisteredItems", dumpChest})
end

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
    return resEv[5]
end

function RemoteStorageSystem:sendNonBlockingReq(arr)
    -- should also only be used internally
    -- instead of waiting for a response, this simply doesn't
    -- self:handleNonBlockingResponse should be used to interpret
    if type(arr) ~= "table" then -- bug in this very class
        error("RemoteStorageSystemClass shat itself, non-table passed to sendBlockingReq")
    end
    self.modem.transmit(self.outPort, self.inPort, arr)
    return
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

return { new = new }