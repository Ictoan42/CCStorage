-- an attempt to copy rust's Result type in a way that makes sense for lua

local Result = {}

function Result:unwrap()
    if self.status == "ok" then
        return self.val
    elseif self.status == "err" then
        error("Attempted to unwrap a Result that was err: \"" .. self.err .. "\"\n\n" .. debug.traceback(), 2)
    else
        self:brokenStateError()
    end
end

function Result:unwrap_err()
    if self.status == "err" then
        return self.err
    elseif self.status == "ok" then
        error("Attempted to unwrap_err a Result that was ok: \"" .. self.val .. "\"\n\n" .. debug.traceback(), 2)
    else
        self:brokenStateError()
    end
end

function Result:ok_or(func)
    if self:is_ok() then
        return self:unwrap()
    else
        return func(self:unwrap_err())
    end
end

function Result:is_ok()
    if self.status == "ok" then
        return true
    elseif self.status == "err" then
        return false
    else
        self:brokenStateError()
    end
end

function Result:is_err()
    if self.status == "err" then
        return true
    elseif self.status == "ok" then
        return false
    else
        self:brokenStateError()
    end
end

function Result:brokenStateError()
    error("Attempted to interact with a Result with broken state: \"" .. self.status .. "\"\n\n" .. debug.traceback(), 2)
end

local function result_tostring(result)
    if result:is_ok() then
        return "Ok(\""..result:unwrap().."\")"
    elseif result:is_err() then
        return "Err(\""..result:unwrap_err().."\")"
    else
        self:brokenStateError()
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

local function Ok(val)
    if type(val) == "nil" then
        error("Attempted to construct an Ok() Result with value of type nil\n\n"..debug.traceback(), 2)
    end
    local obj = {}
    obj["status"] = "ok"
    obj["val"] = val
    
    return setmetatable(obj, ResultMetatable)
end

local function Err(val)
    if type(val) ~= "string" then
        error("Attempted to construct a Err() Result with an error message that isn't a string\n\n"..debug.traceback(), 2)
    end
    local obj = {}
    obj["status"] = "err"
    obj["err"] = val

    return setmetatable(obj, ResultMetatable)
end

return {Ok = Ok, Err = Err}