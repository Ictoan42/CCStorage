print("Running Storage System")

confFilePath = "/CCStorage/Server/CCStorage.conf"

print("Config file: " .. confFilePath)

SSML = require("/CCStorage/Server/StorageSystemModemListener")

SSML.main(confFilePath)

print("Storage System Shut Down")
