-- Патч, чтобы увеличить толщину подчёркивания

local ReaderView = require("apps/reader/modules/readerview")
local Size = require("ui/size")
local Screen = require("device").screen

local ReaderView_drawHighlightRect = ReaderView.drawHighlightRect

ReaderView.drawHighlightRect = function(self, bb, _x, _y, rect, drawer, color, draw_note_mark)
    Size.line.thick = Screen:scaleBySize(3.0) -- new thickness
    ReaderView_drawHighlightRect(self, bb, _x, _y, rect, drawer, color, draw_note_mark)
    Size.line.thick = Screen:scaleBySize(1.5)
end