--[[

This program listens for modem messages and converts them into commands for a StorageSystem object
per a protocol that is agreed upon between this shim and a corresponding client elsewhere.

Each message contains a table in the "data" of a modem message

The table is structured as follows:

    {
        String: method name,
        Any: argument 1,
        Any: argument 2,
        ...etc...
    }

There is also a value in the key "n" that stores the index of the final element in the table.
This value is added automatically by the table.pack() function

if an argument is desired to be left as nil, the corresponding entry in the array should also be nil.

This program will respond with the return value, simply sending the return value as the "data" in a modem message verbatim.

This program will respond to requests on the given response port, or 21 if no response port is given

]]--

StorageSystem = require("/StorageSystem/StorageSystemClass")

modem = peripheral.find("modem")

function methodDoesNotExistReturn(storsysobj, returnPort, badMethodName)
    storsysobj.logger:e("Invalid method name: '" .. badMethodName .. "'")

    modem.transmit(returnPort, 20, false)
end

function returnResult(storsysobj, returnPort, valToReturn)
    modem.transmit(returnPort, 20, valToReturn)
end


function main(confFilePath)
    if modem.isWireless() then
        -- only wired modem will work for this
        error("Wired modem must be used")
    else
        -- the actual program
        local storsys = StorageSystem.new("/storageSystem.conf")

        modem.open(20) -- main port for inbound comms

        while true do

            local ev = table.pack(os.pullEvent("modem_message"))

            local data = ev[5]

            local returnPort = ev[4]

            local methodName = data[1]

            -- does this method exist?
            if type(storsys[methodName]) ~= "function" then
                print(methodName)
                methodDoesNotExistReturn(storsys, returnPort, methodName)
            else
                storsys.logger:d("Modem Shim calling method " .. methodName)
                returnVal = storsys[methodName](
                    storsys, -- calling with : usually sends the "self" var as the first argument, we must emulate that here
                    table.unpack(
                        data,
                        2, -- ignore first entry, which is the method name
                        data.n -- need this to make sure we get all vals, including nils
                    )
                )
                returnResult(storsys, returnPort, returnVal)
            end
        end
    end
end

return { main = main }
