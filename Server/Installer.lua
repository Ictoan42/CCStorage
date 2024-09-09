print("Stub")

-- download CCLogger (dependency)
shell.run("wget " .. "https://raw.githubusercontent.com/Ictoan42/CCLogger/main/CCLogger.lua" .. " /CCLogger.lua")

if not fs.exists("/CCStorage") then
    error("Directory /CCStorage does not exist")
end

fs.makeDir("/CCStorage/Server")

-- download main files
local mainURL = "https://raw.githubusercontent.com/Ictoan42/CCStorage/main/"

local files = [
    "ChestArrayClass.lua",
    "ConfigTemplate.conf",
    "ItemHandlerClass.lua",
    "Main.lua",
    "SortingListClass.lua",
    "StorageSystemClass.lua",
    "StorageSystemModemListener.lua"
]

for k, v in pairs(files) do
    shell.run("wget " .. mainURL .. "Server/" .. v)
end