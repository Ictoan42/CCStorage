local args = {...}

local overwrite = false
for k, v in pairs(args) do
    if v == "-o" then overwrite = true end
end

if not fs.exists("/CCStorage") then
    error("Directory /CCStorage does not exist")
end

fs.makeDir("/CCStorage/TUI")

-- download main files
local mainURL = "https://raw.githubusercontent.com/Ictoan42/CCStorage/main/"

local files = {
    "STUI.lua",
    "SearchBoxClass.lua",
    "ConfigTemplate.conf",
    "Wrapper.lua"
}

for k, v in pairs(files) do
    if overwrite then
        fs.delete("/CCStorage/TUI/"..v)
    end
    shell.run("wget " .. mainURL .. "TUI/" .. v .. " /CCStorage/TUI/" .. v)
end

if
    not fs.exists("/CCStorage/Common")
    or not fs.exists("/CCLogger.lua")
then
    shell.run("wget run " .. mainURL .. "Common/Installer.lua")
elseif overwrite then
    shell.run("wget run " .. mainURL .. "Common/Installer.lua -o")
end

while true do
    print("Would you like the TUI to run on startup? [Y/n]")
    local response = read()

    if response == "Y" or response == "" then
        print("Creating startup script...")

        if fs.exists("/startup.lua") then
            print("Failed to create startup script: startup.lua already exists")
        else
            local f, err = fs.open("/startup.lua", "w")
            if f == nil then
                print("Failed to create startup file: "..err)
            else
                f.write("term.clear()")
                f.write("term.setCursorPos(1, 1)")
                f.write("shell.run(\"CCStorage/TUI/Wrapper.lua\")")
                f.close()
            end
        end

        break

    elseif response == "n" then
        print("No startup script will be created")

        break
    else
        print("Unrecognised response, please re enter")
    end
end
