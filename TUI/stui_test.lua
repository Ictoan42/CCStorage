
dbgmon = peripheral.wrap("right")
dbgmon.setTextScale(0.5)
dbgmon.setCursorPos(1, 1)
dbgmon.setTextColour(colors.white)
dbgmon.setBackgroundColour(colors.black)
dbgmon.clear()

DBGMONPRINT = function(obj)
    term.redirect(dbgmon)
    require("cc.pretty").pretty_print(obj)
    term.redirect(term.native())
end

local status, val = pcall(function() require("STUI") end)

if status == false then
    DBGMONPRINT(val)
end
