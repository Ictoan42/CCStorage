-- a class representing a search box, which takes lists of entries
-- as strings, a search value to look for, and a function to run when
-- an entry is clicked on

local AW = require("AdvancedWindowClass")

local SearchBox = {}

function SearchBox:draw()
    self.win:clear(true) -- clear window
    local windowW = self.w - 2
    local windowH = self.h - 2
    self.win:setCursorPos(1, 1)
    self.win:setBackgroundColour(self.searchTermCol)
    self.win:print(self.searchTerm) -- print current search term
    self.win:setCursorPos(1, 2)
    self.win:setBackgroundColour(self.bgCol)
    self.win:print( -- seperator
        string.rep("-", windowW)
    )

    self:getCurrentSearchListLen()
    self:rectifySelectedPos()

    -- print list
    if self.listOverride == nil then
        local searchedList = self:filterSearchList(self.searchTerm)
        local maxHeight = windowH - 2
        local listLen = #searchedList

        local targetHeight
        local listLenOverflow = 0
        if listLen > maxHeight then
            targetHeight = maxHeight - 1 -- leave last line for a "this goes further" marker
            listLenOverflow = listLen - (maxHeight - 1)
        else
            targetHeight = listLen
        end

        for i=1,targetHeight,1 do
            local bg
            if i == self.selectedEntry then
                bg = self.selectedCol
            else
                bg = self.bgCol
            end
            local e = searchedList[i]
            self.win:setCursorPos(1, i + 2)
            self.win:setBackgroundColour(bg)
            self.win:write(
                e[1]:sub(1, e[2]-1)
            )
            self.win:setBackgroundColour(self.highlightCol)
            self.win:write(
                e[1]:sub(e[2],e[3])
            )
            self.win:setBackgroundColour(bg)
            self.win:write(
                e[1]:sub(e[3]+1,-1)
            )
            self.win:setBackgroundColour(self.bgCol)
        end

        if listLenOverflow > 0 then
            self.win:setCursorPos(1, windowH)
            self.win:write(
                CCS.ensure_width(
                    string.format(" (%g more entries) ", listLenOverflow),
                    windowW
                )
            )
        end
    else
        self.win:setCursorPos(1, 3)
        self.win:write(self.listOverride)
    end
end

function SearchBox:getSelected()
    local searchedList = self:filterSearchList(self.searchTerm)
    if self.selectedEntry then
        return searchedList[self.selectedEntry]
    else
        return nil
    end
end

function SearchBox:moveSelectedDown()
    local added = self.selectedEntry + 1
    if added > self.currentListLen then
        added = 1
    end
    self.selectedEntry = added
end

function SearchBox:moveSelectedUp()
    local subbed = self.selectedEntry - 1
    if subbed == 0 then
        subbed = self.currentListLen
    end
    self.selectedEntry = subbed
end

function SearchBox:rectifySelectedPos()
    -- set selected index to nil if there are no items listed
    if self.currentListLen == 0 then
        self.selectedEntry = nil
        return -- next one will break if we keep going
    end

    -- set selected index to 1 if it was previously nil but there are now items
    if self.selectedEntry == nil and self.currentListLen ~= 0 then
        self.selectedEntry = 1
    end

    -- move the selection back within bounds if a new search term has shortened the list
    if self.selectedEntry > self.currentListLen then
        self.selectedEntry = self.currentListLen
    end
end

function SearchBox:addToSearchTerm(addition)
    self.searchTerm = self.searchTerm .. addition
end

function SearchBox:removeFromSearchTerm(num)
    local new = string.sub(self.searchTerm, 1, -1-num)
    self.searchTerm = new
end

function SearchBox:setSearchTerm(str)
    self.searchTerm = str
end

function SearchBox:setListOverride(str)
    self.listOverride = str
end

function SearchBox:clearListOverride()
    self.listOverride = nil
end

function SearchBox:filterSearchList(pattern)
    local arrOut = {} -- in format {string, startindex, endindex}
    for k, v in pairs(self.searchList) do
        startindex, endindex = v:find(pattern)
        if startindex ~= nil then
            arrOut[#arrOut+1] = {v, startindex, endindex}
        end
    end 
    return arrOut
end

function SearchBox:getCurrentSearchListLen()
    self.currentListLen = math.min(
        #self:filterSearchList(self.searchTerm),
        self.h - 5
    )
end

function SearchBox:setSearchList(list)
    self.searchList = list

    self:getCurrentSearchListLen()
end

local SearchBoxMetatable = {
    __index = SearchBox
}

function new(parent, x, y, w, h, bgCol, fgCol, borderCol, highlightCol, selectedCol, searchTermCol)

    local window = AW.new(parent, x, y, w, h, bgCol, fgCol, borderCol)
    
    local sb = setmetatable(
        {
            win = window,
            searchTerm = "",
            searchList = {},
            listOverride = nil,
            currentListLen = nil,
            selectedEntry = 1,
            x = x,
            y = y,
            w = w,
            h = h,
            bgCol = bgCol,
            fgCol = fgCol,
            borderCol = borderCol,
            highlightCol = highlightCol,
            selectedCol = selectedCol,
            searchTermCol = searchTermCol,
        },
        SearchBoxMetatable
    )

    return sb
end

return {new = new}