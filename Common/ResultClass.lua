-- an attempt to copy rust's Result type in a way that makes sense for lua

Result = {}

function Result:unwrap()
    if self.status == "ok" then
        return self.val
    elseif self.status == "err" then
        error("Attempted to unwrap a Result that was err: " .. self.err .. "\n\n" .. debug.traceback(), 2)
    else
        error("Attempted to tostring a Result with broken state:" .. self.status .. "\n\n" .. debug.traceback(), 2)
    end
end

function Result:unwrap_err()
    if self.status == "err" then
        return self.err
    elseif self.status == "ok" then
        error("Attempted to unwrap_err a Result that was ok:" .. self.val .. "\n\n" .. debug.traceback(), 2)
    else
        error("Attempted to tostring a Result with broken state:" .. self.status .. "\n\n" .. debug.traceback(), 2)
    end
end

function Result:is_ok()
    return self.status == "ok"
end

function Result:is_err()
    return self.status == "err"
end

function result_tostring(result)
    if result:is_ok() then
        return "Ok("..result:unwrap()..")"
    elseif result:is_err() then
        return "Err("..result:unwrap_err()..")"
    else
        error("Attempted to tostring a Result with broken state:" .. self.status .. "\n\n" .. debug.traceback(), 2)
    end
end

ResultMetatable = {
    __index = Result,
    __tostring = result_tostring
}

function Ok(val)
    if type(val) == "nil" then
        error("Attempted to construct an Ok() Result with value of type nil\n\n"..debug.traceback(), 2)
    end
    local obj = {}
    obj["status"] = "ok"
    obj["val"] = val
    
    return setmetatable(obj, ResultMetatable)
end

function Err(val)
    if type(val) ~= "string" then
        error("Attempted to construct a Err() Result with an error message that isn't a string\n\n"..debug.traceback(), 2)
    end
    local obj = {}
    obj["status"] = "err"
    obj["err"] = val

    return setmetatable(obj, ResultMetatable)
end

return {Ok = Ok, Err = Err}