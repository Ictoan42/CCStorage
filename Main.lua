print("Running Storage System")

confFilePath = "/CCStorage/CCStorage.conf"

print("Config file: " .. confFilePath)

SSML = require("/CCStorage/StorageSystemModemListener")

SSML.main(confFilePath)

print("Storage System Shut Down")
