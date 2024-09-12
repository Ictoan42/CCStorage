
DBGMON = peripheral.wrap("right")
DBGMON.setTextScale(0.5)
DBGMON.setCursorPos(1, 1)
DBGMON.setTextColour(colors.white)
DBGMON.setBackgroundColour(colors.black)
DBGMON.clear()

DBGMONPRINT = function(obj)
    --- @diagnostic disable-next-line: param-type-mismatch
    term.redirect(DBGMON)
    require("cc.pretty").pretty_print(obj)
    term.redirect(term.native())
end

local status, val = pcall(function() require("STUI") end)

if status == false then
    DBGMONPRINT(val)
end
