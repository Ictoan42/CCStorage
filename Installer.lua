-- installer for the CCStorage main storage system program

-- parse args
local args = {...}

for k, v in pairs(args) do

    if v == "-o" then ArgOverwrite = true end

end

-- safety check
if not ArgOverwrite and fs.exists("/CCStorage") then
    print("CCStorage seems to already be installed, please wipe any existing files before reinstalling")
    return
end

-- create folder
fs.makeDir("/CCStorage")

-- download main files into folder
local mainURL = "https://raw.githubusercontent.com/Ictoan42/CCStorage/main/"

shell.run("wget " .. mainURL .. "ChestArrayClass.lua" .. " /CCStorage/ChestArrayClass.lua")

shell.run("wget " .. mainURL .. "ConfigFileClass.lua" .. " /CCStorage/ConfigFileClass.lua")

shell.run("wget " .. mainURL .. "ItemHandlerClass.lua" .. " /CCStorage/ItemHandlerClass.lua")

shell.run("wget " .. mainURL .. "Main.lua" .. " /CCStorage/Main.lua")

shell.run("wget " .. mainURL .. "SortingListClass.lua" .. " /CCStorage/SortingListClass.lua")

shell.run("wget " .. mainURL .. "StorageSystemClass.lua" .. " /CCStorage/StorageSystemClass.lua")

shell.run("wget " .. mainURL .. "StorageSystemModemListener.lua" .. " /CCStorage/StorageSystemModemListener.lua")

shell.run("wget " .. mainURL .. "ConfigTemplate.conf" .. " /CCStorage/CCStorage.conf")

-- download CCLogger (dependency)
shell.run("wget " .. "https://raw.githubusercontent.com/Ictoan42/CCLogger/main/CCLogger.lua" .. " /CCLogger.lua")
