if not fs.exists("/CCStorage") then
    error("Directory /CCStorage does not exist")
end

fs.makeDir("/CCStorage/TUI")

-- download main files
local mainURL = "https://raw.githubusercontent.com/Ictoan42/CCStorage/main/"

local files = {
    "STUI.lua",
    "SearchBoxClass.lua"
}

for k, v in pairs(files) do
    shell.run("wget " .. mainURL .. "TUI/" .. v .. " /CCStorage/TUI/" .. v)
end

if not fs.exists("/CCStorage/Common") or not fs.exists("/CCLogger.lua") then
    shell.run("wget run " .. mainURL .. "Common/Installer.lua")
end