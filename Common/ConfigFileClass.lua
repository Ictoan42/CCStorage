-- object wrapper for the storage system config file

--- @class ConfigFile
--- @field [string] string
local ConfigFile = {}

local ConfigFileMetatable = {
    __index = ConfigFile
}

--- @param filePath string
--- @return ConfigFile
--- Import a config file from the given path
local function new(filePath)

    -- "new" basically just imports and interprets the file into a set of table entries to be accessed as a dict

    local file = fs.open(filePath, "r")

    local fileContents = file.readAll()

    file.close()

    -- all config options
    local opts = {}

    for line in fileContents:gmatch("([^\n]+)") do -- iterate over everything between the "\n"s (iterate over every line)

        if line:sub(1,1) ~= "#" and line:sub(1,2) ~= "--" then -- "if this line is not a comment"

            -- find the " = " that seperates key from value
            local splitStart, splitEnd = line:find(" = ")

            if splitStart ~= nil then -- if this is a valid key-val pair

                -- extract the key and value strings
                local keyName = line:sub(1, splitStart-1)
                local valName = line:sub(splitEnd+1, -1):gsub("'", "")

                -- register that option
                opts[keyName] = valName
            end

        end

    end

    -- the "opts" table already has all the properties of the object, now just slap on the methods
    -- (there are no methods)
    return setmetatable(opts, ConfigFileMetatable)
end

return { new = new }
