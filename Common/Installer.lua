local args = {...}

local overwrite = false
for k, v in pairs(args) do
    if v == "-o" then overwrite = true end
end

-- download CCLogger (dependency)
if overwrite then
    fs.delete("/CCLogger.lua")
end
shell.run("wget " .. "https://raw.githubusercontent.com/Ictoan42/CCLogger/main/CCLogger.lua" .. " /CCLogger.lua")

if not fs.exists("/CCStorage") then
    error("Directory /CCStorage does not exist")
end

fs.makeDir("/CCStorage/Common")

-- download main files
local mainURL = "https://raw.githubusercontent.com/Ictoan42/CCStorage/main/"

local files = {
    "AdvancedWindowClass.lua",
    "ButtonClass.lua",
    "ConfigFileClass.lua",
    "ExecUtils.lua",
    "InvUtils.lua",
    "RemoteStorageSystemClass.lua",
    "ResultClass.lua",
    "StatusWindowClass.lua",
    "WindowManagerClass.lua",
    "BlitUtils.lua"
}

for k, v in pairs(files) do
    if overwrite then
        fs.delete("/CCStorage/Common/"..v)
    end
    shell.run("wget " .. mainURL.."Common/"..v .. " /CCStorage/Common/"..v)
end
