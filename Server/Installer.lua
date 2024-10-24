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

while true do
    print("Would you like the Server to run on startup? [Y/n]")
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
                f.write("shell.run(\"CCStorage/Server/Main.lua\")")
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
