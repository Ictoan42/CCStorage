--- @class Blit
--- @field ts string the next to write
--- @field fgs string foreground colour string
--- @field bgs string background colour string
--- @field dbg ccTweaked.colors.color default background colour
--- @field dfg ccTweaked.colors.color default foreground colour
local Blit = {}

--- @param text string the text to write
--- @param fgcol ccTweaked.colors.color|nil foreground colour to set, or default
--- @param bgcol ccTweaked.colors.color|nil background colour to set, or default
function Blit:write(text, fgcol, bgcol)
    self.ts = self.ts..text
    local fgc = colours.toBlit(fgcol or self.dfg)
    local bgc = colours.toBlit(bgcol or self.dbg)
    self.fgs = self.fgs..fgc:rep(text:len())
    self.bgs = self.bgs..bgc:rep(text:len())
end

--- @param t ccTweaked.term.Redirect|ccTweaked.peripherals.Monitor|nil where to render to, term.current() by default
function Blit:render(t)
    t = t or term.current()
    t.blit(self.ts, self.fgs, self.bgs)
end

local blitMetatable = {
    __index = Blit
}

local function new(fgCol, bgCol)
    local blit = {
        ts = "",
        fgs = "",
        bgs = "",
        dfg = fgCol,
        dbg = bgCol
    }

    return setmetatable(blit, blitMetatable)
end

return { new = new }
