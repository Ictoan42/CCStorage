local Main = require("/CCStorage.Monitor_GUI.Main")

local args = {...}

local confFilePath
for k, v in pairs(args) do
    if v == "-c" then
        -- get next arg
        local nextArg = args[k+1]
        if type(nextArg) == "string" then
            confFilePath = nextArg
            print("Got config path '"..confFilePath.."' from arguments")
        else
            error("Monitor_GUI Main was passed the -c flag, but no path")
        end
    end
end
if confFilePath == nil then
    confFilePath = "/CCStorage/Monitor_GUI.conf"
    print("Defaulting to config path '"..confFilePath.."'")
end
if fs.exists(confFilePath) then
    print("Found config file")
    return Main.main(confFilePath)
else
    print("There is no config file!")
    print("Would you like to generate one now? [Y/n]")
    while true do
        local res = read()
        if res == "Y" or res == "y" or res == "" then
            print("Generating config file..")
            fs.copy("/CCStorage/Monitor_GUI/ConfigTemplate.conf", confFilePath)
            print("New config file generated at \"" .. confFilePath .. "\"")
            print("Make sure to edit it before trying to run the GUI again")
            break
        elseif res == "N" or res == "n" then
            print("Not generating config file.")
            break
        else
            print("Unrecognised option, please try again")
        end
    end
end
