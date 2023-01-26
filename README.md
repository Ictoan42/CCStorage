# CCStorage - Client API
This is the basic client API for interacting with a CCStorage system.

<br/>

## Basic usage:

    -- import the API
    RemoteStorageSystem = require("RemoteStorageSystemClass")

    -- wrap modem peripheral (must be wired!)
    modem = peripheral.find("modem")

    -- create object
    rss = RemoteStorageSystem.new(
        modem, -- modem object
        20, -- port to send messages TO main storage on
        21 -- port to recieve incoming messages FROM main storage on
    )

<br/>

## Methods:

<br/>

`RemoteStorageSystem:list(liteMode)`

Returns a list of items in the storage system. Format returned is an array, where every entry is itself an array, representing a single chest in the system. The per-chest array is identical to that returns by the built in function `inventory.list()`, but with added entries `chestName` and `chestSize` for every entry. These extra entries do make the function slower however, so the boolean `liteMode` is accepted, which will disable those entries if set to `true`. Defaults to `false` though.

<br/>

`RemoteStorageSystem:organisedList(liteMode)`

Returns a list of items in the storage system, but in an organised format. Return format is a table, in which indexing with an item ID e.g. `minecraft:stone` will return the number of that item in the system (total), or `nil` if none exist.

<br/>

`RemoteStorageSystem:findItems(itemID)`

Returns an array, where every entry is an array representing a single instance of that item, in the format `{chestName, slot, count, itemName}`. `itemName` is a string, of the itemID to search for, e.g. `minecraft:dirt`.

<br/>

`RemoteStorageSystem:sortFromInput(inputChestID)`

Instructs the storage system to search through the chest with ID `inputChestID` (e.g. `minecraft:chest_0`) and sort all items inside into the system. Returns `true` if successful, or `false` if the chest contained items that the system didn't recognise.

<br/>

`RemoteStorageSystem:retrieve(itemID, outputChestID, count, toSlot)`

Instructs the storage system to move find `count` number of `itemID`, and move them to `toSlot` in chest `outputChestID`. `toSlot` is optional, the rest are not. Returns `true` if successful, `false` if not.

<br/>

`RemoteStorageSystem:detectAndRegisterItems()`

Instructs the storage system to search through all of its chests, find any items that it doesn't recognise, and register them to be stored in the chest they were found in.

<br/>

`RemoteStorageSystem:registerItem(itemID, chestID)`

Instructs the storage system to register the item `itemID` to chest `chestID`.

<br/>

`RemoteStorageSystem:forgetItem(itemID)`

Instructs the storage system to unregister the given item, allowing it to be re-registered to a different chest.

<br/>

`RemoteStorageSystem:cleanUnregisteredItems(dumpChest)`

Instructs the storage system to search for any items it doesn't recognise and move them into `dumpChest`.

<br/>

`RemoteStorageSystem:getConfig()`

Returns the configuration settings of the storage system, in the form of a `ConfigFile` object.