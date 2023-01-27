-- installer for the CCStorage main storage system program

-- safety check
if fs.exists("/CCStorage") then
    print("CCStorage seems to already be installed, please wipe any existing files before reinstalling")
    return
end

-- create folder
fs.makeDir("/CCStorage")

-- download files into folder

local mainURL = "https://raw.githubusercontent.com/Ictoan42/CCStorage/main/"

shell.run("wget " .. mainURL .. "ChestArrayClass.lua" .. " /CCStorage/ChestArrayClass.lua")

shell.run("wget " .. mainURL .. "ConfigFileClass.lua" .. " /CCStorage/ConfigFileClass.lua")

shell.run("wget " .. mainURL .. "ItemHandlerClass.lua" .. " /CCStorage/ItemHandlerClass.lua")

shell.run("wget " .. mainURL .. "Main.lua" .. " /CCStorage/Main.lua")

shell.run("wget " .. mainURL .. "SortingListClass.lua" .. " /CCStorage/SortingListClass.lua")

shell.run("wget " .. mainURL .. "StorageSystemClass.lua" .. " /CCStorage/StorageSystemClass.lua")

shell.run("wget " .. mainURL .. "StorageSystemModemListener.lua" .. " /CCStorage/StorageSystemModemListener.lua")
