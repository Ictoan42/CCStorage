-- object wrapper for the list to sort items with

--- @class SortingList
--- @field dests table
--- @field file string
--- @field backupFile string
--- @field logger Logger
local sortingList = {}

--- @return string
--- Converts the stored list to a single string, and returns it
function sortingList:serialize()
    -- converts the stored list into a single string
    -- each entry is in format "modid:itemid modid:chestname_id"
    -- entries are seperated by newlines

    self.logger:d("SortingList executing method serialize")

    local strOut = ""
    for k, v in pairs(self.dests) do
        strOut = strOut .. k .. " " .. v .. "\n"
    end
    return strOut
end

--- @param str string
--- @return boolean
--- Deserializes a list from the given string
function sortingList:importFromText(str)
    -- imports a list from a string
    -- string is the same format as is output by :serialize()

    self.logger:d("SortingList executing method importFromText")

    local arrOut = {}

    -- iterate over every entry in the file
    -- entries are in form: "modid:itemid modid:chestname_id"
    for entry in str:gmatch("([^\n]+)") do -- regex bollocks to seperate with the newlines

        local spacePos = entry:find(" ")
        if spacePos == nil then -- this line is munted
            return false
        end

        local itemName = entry:sub(1, spacePos-1) -- everything before the space
        if itemName == nil or itemName == "" then -- this line is munted (again)
            return false
        end

        local destName = entry:sub(spacePos+1, -1) -- everything after the space
        if destName == nil or destName == "" then -- this line is, once again, munted
            return false
        end
        arrOut[itemName] = destName
    end

    self.dests = arrOut

    return true
end

--- @param filePath string path of the sorting list file
--- @param backupFilePath string path of the backup sorting list file
--- @param muntedFilePath string path of where to put the broken file in case of failure
--- @return boolean
--- Deserializes a list from the given file
function sortingList:importFromFile(filePath, backupFilePath, muntedFilePath)
    -- simple function to read a file and pass it to :importFromText()

    self.logger:d("SortingList executing method importFromFile")

    local f = fs.open(filePath, "r")
    local fileText = f.readAll()
    f.close()

    if f == nil then
        -- if the file doesn't exist
        return false
    end

    local result = self:importFromText(fileText)

    if result == false then -- failed to import
        self.logger:e("SORTING LIST IMPORT FAILED")
        self.logger:e("Attempting to load backup...")

        -- try importing from backup
        local f2 = fs.open(backupFilePath, "r")
        local fileText2 = f2.readAll()
        f2.close()
        local result2 = self:importFromText(fileText2)

        if result2 == false then -- if shit is REALLY munted

            self.logger:f("FAILED TO LOAD BACKUP")
            self.logger:f("Sorting list file is absolutely fucked and needs to be fixed manually")
            self.logger:f("(sorry)")
            error("Failed to import sorting list")

        else

            self.logger:e("Backup loaded successfully")
            self.logger:e("Saving broken file for potential manual recovery...")

            fs.move(filePath, muntedFilePath)

            self.logger:e("Rewriting main file from backup...")

            local f3 = fs.open(filePath, "w")
            f3.write(self:serialize())
            f3.close()

            self.logger:e("Backup recover complete")

        end
    end

    return true
end

--- @param itemName string
--- @param chestName string
--- @return boolean
--- Registers the given item to the given chest
function sortingList:addDest(itemName, chestName)
    -- add a destination to local memory and disk
    -- saved to disk by appending in the standard format to the storageFile

    self.logger:d("SortingList executing method addDest")

    if self.dests[itemName] ~= nil then
        print("SortingList.addDest() error - item already has destination")
        return false
    else
        -- save to memory
        self.dests[itemName] = chestName

        -- add dest to storageFile
        local f = fs.open(self.file, "a")
        f.write(itemName .. " " .. chestName .. "\n") -- newline because append mode doesn't do that automatically for some reason
        f.close()

        return true
    end
end

--- @param itemName string
--- @return boolean
--- Unregisters the given item from the system
function sortingList:removeDest(itemName)
    -- remove the specified destination from local memory and disk storage

    self.logger:d("SortingList executing method removeDest")

    -- abort if there isn't actually a dest stored for this item
    if self:getDest(itemName) == nil then return false end

    -- remove from memory
    self.dests[itemName] = nil

    -- backup file
    fs.delete(self.backupFile)
    fs.copy(self.file, self.backupFile)

    -- remove from disk
    -- kinda difficult actually, so just wipe the file and resave with the dest removed from memory
    local f = fs.open(self.file, "w")
    f.write(self:serialize())
    f.close()

end

--- @param itemName string
--- @return string
function sortingList:getDest(itemName)
    self.logger:d("SortingList executing method getDest")

    -- will just return nil if the dest doesn't exist
    return self.dests[itemName]
end

local sortingListMetatable = {
    __index = sortingList,
}

--- @param storageFile string path of the sorting list file
--- @param backupFile string path of the backup sorting list file
--- @param muntedFilePath string path of where to put the broken file in case of failure
--- @param logger Logger
--- @return SortingList
--- Creates a new Sorting List
local function new(storageFile, backupFile, muntedFilePath, logger)

    if storageFile == nil then
        -- storage file must be specified
        return false
    end

    local sl = setmetatable(
        {
            dests = {}, --"dests" is a 1-indexed array with a key-value relationship of "modid:itemid"-"modid:chestName_id"
            file = storageFile, -- string representing the filesystem path to the file
            backupFile = backupFile,
            logger = logger
        },
        sortingListMetatable
    )

    if sl:importFromFile(storageFile, backupFile, muntedFilePath) then
        return sl
    else
        -- failed to import list from file, abort
        return false
    end

end

return { new = new }
