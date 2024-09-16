if not fs.exists("/CCStorage") then
    error("Directory /CCStorage does not exist")
end

fs.makeDir("/CCStorage/Server")

-- download main files
local mainURL = "https://raw.githubusercontent.com/Ictoan42/CCStorage/main/"

local files = {
    "ChestArrayClass.lua",
    "ConfigTemplate.conf",
    "ItemHandlerClass.lua",
    "Main.lua",
    "NameStackCacheClass.lua",
    "SortingListClass.lua",
    "StorageSystemClass.lua",
    "StorageSystemModemListener.lua"
}

for k, v in pairs(files) do
    shell.run("wget " .. mainURL .. "Server/" .. v .. " /CCStorage/Server/" .. v)
end

if not fs.exists("/CCStorage/Common") or not fs.exists("/CCLogger.lua") then
    shell.run("wget run " .. mainURL .. "Common/Installer.lua")
end
