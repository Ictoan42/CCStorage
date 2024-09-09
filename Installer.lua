-- Generic installer that asks which component to install then runs the relevant installer

local args = {...}

local toInstall = ""
local overwrite = false
local helpText = [[
Usage:
    Installer     -> Run install wizard
Shortcuts:
    Installer -S  -> Install Server
    Installer -G  -> Install Monitor_GUI
    Installer -T  -> Install TUI
Options:
    -o            -> Overwrite any existing CCStorage files
]]
for k, v in pairs(args) do
    if v == "-h" or v == "--help" then
        print(helpText)
        return
    end

    if     v == "-S" then toInstall = "Server"
    elseif v == "-G" then toInstall = "Monitor_GUI"
    elseif v == "-T" then toInstall = "TUI"
    end

    if v == "-o" then overwrite = true end
end

term.setCursorPos(1,1)
term.clear()

if not overwrite and fs.exists("/CCStorage") then
    print("CCStorage seems to already be installed.")
    print("Please wipe any existing files before reinstalling, or run with the '-o' flag to overwrite")
    return
end

local installPrompt = [[
Which component do you want to install?
    1: Server
    2: Monitor_GUI
    3: TUI
]]

if toInstall == "" then --if no shortcuts set it already
    print(installPrompt)

    while toInstall == "" do
        local response = read()
        if     response == "1" then toInstall = "Server"
        elseif response == "2" then toInstall = "Monitor_GUI"
        elseif response == "3" then toInstall = "TUI"
        else
            print("Unrecognised value, please try again")
        end
    end
end

-- safety check
if toInstall == "" then
    print("something has gone very wrong")
    return
end

-- actually do the installing

fs.makeDir("/CCStorage")

local mainURL = "https://raw.githubusercontent.com/Ictoan42/CCStorage/main/"

shell.run("wget run " .. mainURL .. toInstall .. "/Installer.lua")

--[[ while true do
    print("Would you like the component to run on startup? [Y/n]")
    local response = read()

    if response == "Y" or response == "" then
        print("Creating startup script...")

        if fs.exists("/startup.lua") then
            print("Failed to create startup script: startup.lua already exists")
        else
            local f = fs.open("/startup.lua", "w")
            f.write("term.clear()")
            f.write("term.setCursorPos(1, 1)")
            f.write("shell.run(\"CCStorage/Main.lua\")")
            f.close()
        end

        break

    elseif response == "n" then
        print("No startup script will be created")

        break
    else
        print("Unrecognised response, please re enter")
    end
end ]]

-- installer for the CCStorage main storage system program

print("")
print("Installation complete")
