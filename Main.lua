print("Running Storage System")

confFilePath = "/storageSystem.conf"

print("Config file: " .. confFilePath)

SSML = require("/StorageSystem/StorageSystemModemListener")

SSML.main(confFilePath)

print("Storage System Shut Down")
