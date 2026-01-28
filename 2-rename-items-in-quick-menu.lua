local Dispatcher = require("dispatcher")

-- This patch allows you to change the titles of actions shown in quick menu.
-- It can help to make menu look more neat.
-- Edit the tables below to set your own replacements.


-- Edit this table to be able to change specific titles completely.

local renameTable = {
    ["Поиск по метаданным Calibre"] = "Поиск",
    ["Открыть предыдущий документ"] = "> Предыдущая книга"
}

-- Edit this table to be able to replace some text within the title.
-- You can use regex patterns.
-- Add the ^ at the beginning to mark the start of the title.
-- Add the $ at the end to mark the end of the title.

local replacePartsTable = {
    ["^Профиль:"] = "@",
    ["^Открыть"] = ">",
    [".pdf$"] = "",
    ["Show collection:"] = "#"
}






local getDisplayList_orig = Dispatcher.getDisplayList

function Dispatcher:getDisplayList(settings, for_sorting)
    local item_table = getDisplayList_orig(self, settings, for_sorting)

    for k, item in pairs(item_table) do
        local text_changed = false

        for i, v in pairs(renameTable) do
            if item.text == i then
                item.text = v
                text_changed = true
                break
            end
        end

        if text_changed == false then
            for i, v in pairs(replacePartsTable) do
                item.text = string.gsub(item.text, i, v)
            end
        end
    end
    return item_table
end