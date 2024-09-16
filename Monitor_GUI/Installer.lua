if not fs.exists("/CCStorage") then
    error("Directory /CCStorage does not exist")
end

fs.makeDir("/CCStorage/Monitor_GUI")

-- download main files
local mainURL = "https://raw.githubusercontent.com/Ictoan42/CCStorage/main/"

local files = {
    "ItemCountWatcherClass.lua",
    "Main.lua",
    "MainButtonPanelClass.lua",
    "StatusWindowClass.lua",
    "Wrapper.lua",
    "ConfigTemplate.conf"
}

for k, v in pairs(files) do
    shell.run("wget " .. mainURL .. "Monitor_GUI/" .. v .. " /CCStorage/Monitor_GUI/" .. v)
end

if not fs.exists("/CCStorage/Common") or not fs.exists("/CCLogger.lua") then
    shell.run("wget run " .. mainURL .. "Common/Installer.lua")
end
