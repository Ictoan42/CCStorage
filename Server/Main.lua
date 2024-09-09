print("Running Storage System..")

confFilePath = "/CCStorage/Server.conf"

if fs.exists(confFilePath) then
    print("Found config file: " .. confFilePath)
    SSML = require("/CCStorage/Server/StorageSystemModemListener")
    SSML.main(confFilePath)
else
    print("There is no config file!")
    print("Would you like to generate one now? [Y/n]")
    while true do
        local res = read()
        if res == "Y" or res == "y" or res == "" then
            print("Generating config file..")
            fs.copy("/CCStorage/Server/ConfigTemplate.conf", confFilePath)
            print("New config file generated at \"" .. confFilePath .. "\"")
            print("Make sure to edit it before trying to run the server again")
            break
        elseif res == "N" or res == "n" then
            print("Not generating config file.")
            break
        else
            print("Unrecognised option, please try again")
        end
    end
end
