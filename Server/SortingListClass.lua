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
--- @return Result (boolean)
--- Deserializes a list from the given string
function sortingList:importFromText(str)
    -- imports a list from a string
    -- string is the same format as is output by :serialize()

    self.logger:d("SortingList executing method importFromText")

    local arrOut = {}

    -- iterate over every entry in the file
    -- entries are in form: "modid:itemid modid:chestname_id"
    local linenum = 1
    for entry in str:gmatch("([^\n]+)") do -- regex bollocks to seperate with the newlines

        local spacePos = entry:find(" ")
        if spacePos == nil then -- this line is munted
            return Err("Malformed line "..linenum.." (no space)")
        end

        local itemName = entry:sub(1, spacePos-1) -- everything before the space
        if itemName == nil or itemName == "" then -- this line is munted (again)
            return Err("Malformed line "..linenum.." (no itemid)")
        end

        local destName = entry:sub(spacePos+1, -1) -- everything after the space
        if destName == nil or destName == "" then -- this line is, once again, munted
            return Err("Malformed line "..linenum.." (no periphid)")
        end
        arrOut[itemName] = destName
        linenum = linenum + 1
    end

    self.dests = arrOut

    return Ok(true)
end

--- @param filePath string path of the sorting list file
--- @param backupFilePath string path of the backup sorting list file
--- @param muntedFilePath string path of where to put the broken file in case of failure
--- @return Result (boolean)
--- Deserializes a list from the given file
function sortingList:importFromFile(filePath, backupFilePath, muntedFilePath)
    -- simple function to read a file and pass it to :importFromText()

    self.logger:d("SortingList executing method importFromFile")

    local f, err = fs.open(filePath, "r")
    if f == nil then
        return Err("Couldn't open file: "..err)
    end
    local fileText = f.readAll()
    f.close()

    local result = self:importFromText(fileText)

    if result:is_err() then -- failed to import
        self.logger:e("SORTING LIST IMPORT FAILED")
        self.logger:e("Attempting to load backup...")

        -- try importing from backup
        local f2, err2 = fs.open(backupFilePath, "r")
        if f2 == nil then
            return Err("Failed to open backup file: "..err2)
        end
        local fileText2 = f2.readAll()
        f2.close()
        local result2 = self:importFromText(fileText2)

        if result2:is_err() then -- if shit is REALLY munted

            self.logger:f("FAILED TO LOAD BACKUP")
            self.logger:f("Sorting list file is absolutely fucked and needs to be fixed manually")
            self.logger:f("(sorry)")
            return result2

        else

            self.logger:e("Backup loaded successfully")
            self.logger:e("Saving broken file for potential manual recovery...")

            fs.move(filePath, muntedFilePath)

            self.logger:e("Rewriting main file from backup...")

            local f3, err3 = fs.open(filePath, "w")
            if f3 == nil then
                return Err("Failed to open file: "..err3)
            end
            f3.write(self:serialize())
            f3.close()

            self.logger:e("Backup recover complete")

        end
    end

    return Ok(true)
end

--- @param itemName string
--- @param chestName string
--- @return Result (boolean)
--- Registers the given item to the given chest
function sortingList:addDest(itemName, chestName)
    -- add a destination to local memory and disk
    -- saved to disk by appending in the standard format to the storageFile

    self.logger:d("SortingList executing method addDest")

    if self.dests[itemName] ~= nil then
        return Ok(false)
    else
        -- save to memory
        self.dests[itemName] = chestName

        -- add dest to storageFile
        local f, err = fs.open(self.file, "a")
        if f == nil then
            return Err("Failed to open storage file: "..err)
        end
        f.write(itemName .. " " .. chestName .. "\n") -- newline because append mode doesn't do that automatically for some reason
        f.close()

        return Ok(true)
    end
end

--- @param itemName string
--- @return Result (boolean)
--- Unregisters the given item from the system
function sortingList:removeDest(itemName)
    -- remove the specified destination from local memory and disk storage

    self.logger:d("SortingList executing method removeDest")

    -- abort if there isn't actually a dest stored for this item
    if self:getDest(itemName) == nil then
        return Err("This item has no destination stored")
    end

    -- remove from memory
    self.dests[itemName] = nil

    -- backup file
    fs.delete(self.backupFile)
    fs.copy(self.file, self.backupFile)

    -- remove from disk
    -- kinda difficult actually, so just wipe the file and resave with the dest removed from memory
    local f, err = fs.open(self.file, "w")
    if f == nil then
        return Err("Couldn't open storage file: "..err)
    end
    f.write(self:serialize())
    f.close()

    return Ok(true)
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
--- @return Result (SortingList)
--- Creates a new Sorting List
local function new(storageFile, backupFile, muntedFilePath, logger)

    if storageFile == nil then
        -- storage file must be specified
        return Err("No storage file specified")
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

    local res = sl:importFromFile(storageFile, backupFile, muntedFilePath)
    if res:is_ok() then
        return Ok(sl)
    else
        -- failed to import list from file, abort
        return res
    end

end

return { new = new }
