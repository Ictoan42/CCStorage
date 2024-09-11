-- an attempt to copy rust's Result type in a way that makes sense for lua

--- @class Result
--- @field private status string
--- @field private val any
--- @field private err string
local Result = {}

--- @param logger? Logger
--- @return any
--- If the Result is Ok, returns the contained value.
--- If the result is Err, throws an error with a stack trace
function Result:unwrap(logger) -- logger is optional
    if self.status == "ok" then
        return self.val
    elseif self.status == "err" then
        if logger ~= nil and type(logger.f) == "function" then
            logger:f("Attempted to unwrap a Result that was err:\n\"" .. self.err .. "\"\n\n" .. debug.traceback())
        end
        error("Attempted to unwrap a Result that was err: \"" .. self.err .. "\"\n\n" .. debug.traceback(), 2)
    else
        self:brokenStateError()
    end
end

--- @param logger? Logger
--- @return any
--- If the Result is Err, returns the contained error.
--- If the result is Ok, throws an error with a stack trace
function Result:unwrap_err(logger) -- logger is option
    if self.status == "err" then
        return self.err
    elseif self.status == "ok" then
        if logger ~= nil and type(logger.f) == "function" then
            logger:f("Attempted to unwrap_err a Result that was ok:\n\"" .. self.err .. "\"\n\n" .. debug.traceback())
        end
        error("Attempted to unwrap_err a Result that was ok: \"" .. self.val .. "\"\n\n" .. debug.traceback(), 2)
    else
        self:brokenStateError()
    end
end

--- @param okFunc function
--- @param errFunc function
--- @return any
--- Runs okFunc() with the contained value if the result
--- is Ok,or errFunc()with the error if the result is Err
function Result:handle(okFunc, errFunc)
    if type(okFunc) ~= "function" or type(errFunc) ~= "function" then
        error("Attempted to call Result:handle() with a non-function argument\n\n"..debug.traceback(), 2)
    end
    if self:is_ok() then
        return okFunc(self:unwrap())
    else
        return errFunc(self:unwrap_err())
    end
end

--- @param func function
--- @returns any
--- If the Result is Ok, returns it's contained value.
--- If the Result is Err, runs func() with the contained
--- error as the first parameter
function Result:ok_or(func)
    if self:is_ok() then
        return self:unwrap()
    else
        return func(self:unwrap_err())
    end
end

--- @param func function
--- @return any
--- If the Result is Err, returns it's contained error.
--- If the Result is Ok, runs func() with the contained
--- value as the first parameter
function Result:err_or(func)
    if self:is_err() then
        return self:unwrap_err()
    else
        return func(self:unwrap())
    end
end

--- @return boolean
--- Returns true if the Result is Ok or false otherwise
function Result:is_ok()
    if self.status == "ok" then
        return true
    elseif self.status == "err" then
        return false
    else
        self:brokenStateError()
        return false -- unreachable but still here to make lua_ls happy
    end
end

--- @return boolean
--- Returns true if the Result is an error or false otherwise
function Result:is_err()
    if self.status == "err" then
        return true
    elseif self.status == "ok" then
        return false
    else
        self:brokenStateError()
        return false -- unreachable but still here to make lua_ls happy
    end
end

--- @private
--- Prints an error describing the broken state
--- that a Result has got itself into
function Result:brokenStateError()
    error("Attempted to interact with a Result with broken state: \"" .. self.status .. "\"\n\n" .. debug.traceback(), 2)
end

local function result_tostring(result)
    if result:is_ok() then
        return "Ok(\""..tostring(result:unwrap()).."\")"
    elseif result:is_err() then
        return "Err(\""..result:unwrap_err().."\")"
    else
        result:brokenStateError()
    end
end

local function result_index(result, key)
    if Result[key] ~= nil then
        return Result[key]
    else
        error("Attempted to access non-existent field or method \""..key.."\" of a Result\n\n" .. debug.traceback(), 2)
    end
end

local ResultMetatable = {
    __index = result_index,
    __tostring = result_tostring
}

--- @param val any
--- @return Result
--- Returns an Ok-variant Result containing val
local function Ok(val)
    if type(val) == "nil" then
        error("Attempted to construct an Ok() Result with value of type nil\n\n"..debug.traceback(), 2)
    end
    local obj = {}
    obj["status"] = "ok"
    obj["val"] = val

    return setmetatable(obj, ResultMetatable)
end

--- @param err string
--- @return Result
--- Returns an Err-variant Result containing err
local function Err(err)
    if type(err) ~= "string" then
        error("Attempted to construct a Err() Result with an error message that isn't a string\n\n"..debug.traceback(), 2)
    end
    local obj = {}
    obj["status"] = "err"
    obj["err"] = err

    return setmetatable(obj, ResultMetatable)
end

--- @param val any
--- @param err string
--- @return Result
--- Returns Ok(val) if val is non-nil, or Err(err) otherwise
local function Try(val, err)
    -- returns Ok(val) if it's not nil, or Err(err) if it is
    if val == nil then
        return Err(err)
    else
        return Ok(val)
    end
end

--- @param result table
--- @return Result (Result<Result>)
--- Attempts to coerce the given table into being a Result
local function Coerce(result)
    if result == nil then
        return Err("Input was nil")
    end
    if result.status ~= "ok" and result.status ~= "err" then
        return Err("Input was not a valid result")
    end
    if result.status == "ok" and result.val ~= nil and result.err == nil then
        return Ok(setmetatable(
            {status = "ok", val = result.val},
            ResultMetatable
        ))
    end
    if result.status == "err" and type(result.err) == "string" and result.val == nil then
        return Ok(setmetatable(
            {status = "err", err = result.err},
            ResultMetatable
        ))
    end
    return Err("Input was not a valid result")
end

return {Ok = Ok, Err = Err, Try = Try, Coerce = Coerce}
