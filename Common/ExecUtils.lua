
local function SplitAndExecSafely(execTable, execLimit)
    -- like parallel.waitForAny(), but splits the table in 224-piece (by default) chunks to avoid filling the event queue
    execLimit = execLimit or 224
    local n = #execTable
    
    if n < execLimit then -- no need to do any of this shit
        parallel.waitForAll(table.unpack(execTable))
    else
        -- actually gotta do the thing
        
        -- how many times will we need to run through?
        local loopCount = math.ceil(n / execLimit)

        -- loop that many times
        for i=1, loopCount do
            -- take items out of the table and exec them
            parallel.waitForAll(
                table.unpack(
                    execTable,
                    ((i-1) * execLimit)+1,
                    math.min(i * execLimit, n)
                )
            )
        end
    end
end

return { SplitAndExecSafely = SplitAndExecSafely }