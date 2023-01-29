-- installer for the CCStorage main storage system program

-- parse args
local args = {...}

local ArgOverwrite = false

for k, v in pairs(args) do

    if v == "-o" then ArgOverwrite = true end

end

-- safety check
if not ArgOverwrite and fs.exists("/CCStorage") then
    print("CCStorage seems to already be installed.")
    print("Please wipe any existing files before reinstalling, or run with the '-o' flag to redownload missing files")
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

-- setup startup script
print("Would you like CCStorage to run on startup? [Y/n]")
local response = read()

if response == "Y" or response == "" then
    print("Creating startup script...")

    if fs.exists("/startup.lua") then
        print("Failed to create startup script: startup.lua already exists")
    else
        local f = fs.open("/startup.lua", "w")
        f.write("shell.run(\"CCStorage/Main.lua\")")
        f.close()
    end
else
    print("No startup script will be created")
end

print("")
print("Installation complete")
