local BlitBuffer = require("ffi/blitbuffer")
local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local _ = require("gettext")
local C_ = _.pgettext
local UIManager = require("ui/uimanager")
local util = require("util")
local Event = require("ui/event")
local Notification = require("ui/widget/notification")
local logger = require("logger")
local Device = require("device")
local ffiUtil = require("ffi/util")
local ButtonDialog = require("ui/widget/buttondialog")
local BD = require("ui/bidi")
local Screen = require("device").screen


BlitBuffer_orig_highlight_colors = BlitBuffer.HIGHLIGHT_COLORS
BlitBuffer.HIGHLIGHT_COLORS = {

    ["red"]    = "#ffb8be",  
    ["yellow"] = "#ffe38f",  
    ["green"]  = "#c2ff99", 
    ["cyan"]   = "#94d1c9",  
    ["blue"]   = "#c5c2ff",  
    ["purple"] = "#ebaafd",  

    ["red_dark"] = "#bb0010",
    ["yellow_dark"] = "#dba400",  
    ["green_dark"]  = "#3f9e00",   
    ["cyan_dark"]   = "#00818f",   
    ["blue_dark"]   = "#0d00ca",   
    ["purple_dark"] = "#a000cc",  
}





-- Store the original function to call it later if needed
local orig_init = ReaderHighlight.init

function ReaderHighlight:init()

    orig_init(self)

    self._highlight_buttons = {
        ["01_highlight"] = function(this) 			-- ["name for button"]=buttons get selected based on numerical order. If you change one, renumber all buttons
            return {
                icon = "circle.filled.red",
                enabled = this.hold_pos ~= nil,
                
                callback = function()
                    this:saveHighlightFormatted(true,"lighten","red")		-- the stuff it does
                    this:onClose()
                end,
				hold_callback = function()
                    this:saveHighlightFormatted(true,"underscore","red_dark")		-- long-press to underline
                    this:onClose()
                end,
            }
        end,
        ["02_highlight"] = function(this) 			-- ["name for button"]=buttons get selected based on numerical order. If you change one, renumber all buttons
            return {
                icon = "circle.filled.yellow",
                enabled = this.hold_pos ~= nil,
                callback = function()
                    this:saveHighlightFormatted(true,"lighten","yellow")		-- the stuff it does
                    this:onClose()
                end,
				hold_callback = function()
                    this:saveHighlightFormatted(true,"underscore","yellow_dark")		-- long-press to underline
                    this:onClose()
                end,
            }
        end,
        ["03_highlight"] = function(this) 			-- ["name for button"]=buttons get selected based on numerical order. If you change one, renumber all buttons
            return {
                icon = "circle.filled.green",
                enabled = this.hold_pos ~= nil,
                callback = function()
                    this:saveHighlightFormatted(true,"lighten","green")		-- the stuff it does
                    this:onClose()
                end,
				hold_callback = function()
                    this:saveHighlightFormatted(true,"underscore","green_dark")		-- long-press to underline
                    this:onClose()
                end,
            }
        end,
        ["04_highlight"] = function(this) 			-- ["name for button"]=buttons get selected based on numerical order. If you change one, renumber all buttons
            return {
                icon = "circle.filled.cyan",
                enabled = this.hold_pos ~= nil,
                callback = function()
                    this:saveHighlightFormatted(true,"lighten","cyan")		-- the stuff it does
                    this:onClose()
                end,
				hold_callback = function()
                    this:saveHighlightFormatted(true,"underscore","cyan_dark")		-- long-press to underline
                    this:onClose()
                end,
            }
        end,
        ["05_highlight"] = function(this) 			-- ["name for button"]=buttons get selected based on numerical order. If you change one, renumber all buttons
            return {
                icon = "circle.filled.blue",
                enabled = this.hold_pos ~= nil,
                callback = function()
                    this:saveHighlightFormatted(true,"lighten","blue")		-- the stuff it does
                    this:onClose()
                end,
				hold_callback = function()
                    this:saveHighlightFormatted(true,"underscore","blue_dark")		-- long-press to underline
                    this:onClose()
                end,
            }
        end,
        ["06_highlight"] = function(this) 			-- ["name for button"]=buttons get selected based on numerical order. If you change one, renumber all buttons
            return {
                icon = "circle.filled.purple",
                enabled = this.hold_pos ~= nil,
                callback = function()
                    this:saveHighlightFormatted(true,"lighten","purple")		-- the stuff it does
                    this:onClose()
                end,
				hold_callback = function()
                    this:saveHighlightFormatted(true,"underscore","purple_dark")		-- long-press to underline
                    this:onClose()
                end,
            }
        end,

        ["08_copy"] = function(this)
            return {
                icon = "copy",
                enabled = Device:hasClipboard(),
                callback = function()
                    Device.input.setClipboardText(util.cleanupSelectedText(this.selected_text.text))
                    this:onClose(true)
                    UIManager:show(Notification:new{
                        text = _("Selection copied to clipboard."),
                    })
                    UIManager:scheduleIn(G_defaults:readSetting("DELAY_CLEAR_HIGHLIGHT_S"), function()
                        this:clear()
                    end)
                end,
            }
        end,
        ["09_add_note"] = function(this)
            return {
                icon = "edit2",
                enabled = this.hold_pos ~= nil,
                callback = function()
                    this:addNote()
                    this:onClose()
                end,
            }
        end,
        -- then information lookup functions, putting on the left those that
        -- depend on an internet connection.

        ["10_dictionary"] = function(this, index)
            return {
                icon = "language",
                callback = function()
                    this:lookupDict(index)
                    this:onClose(true) -- keep highlight for dictionary lookup
                end,
            }
        end,

        -- buttons 08-11 are conditional ones, so the number of buttons can be even or odd
        -- let the Search button be the last, occasionally narrow or wide, less confusing
        ["12_search"] = function(this)
            return {
                icon = "search2",
                callback = function()
                    this:onHighlightSearch()
                    -- We don't call this:onClose(), crengine will highlight
                    -- search matches on the current page, and self:clear()
                    -- would redraw and remove crengine native highlights
                end,
            }
        end,
    }


    -- Android devices
    if Device:canShareText() then
        local action = _("Share Text")
        self:addToHighlightDialog("13_share_text", function(this)
            return {
                icon = "share",
                callback = function()
                    local text = util.cleanupSelectedText(this.selected_text.text)
                    -- call self:onClose() before calling the android framework
                    this:onClose()
                    Device:doShareText(text, action)
                end,
            }
        end)
    end


    -- Links
    self:addToHighlightDialog("14_follow_link", function(this)
        return {
            icon = "outgoing",
            show_in_highlight_dialog_func = function()
                return this.selected_link ~= nil
            end,
            callback = function()
                local link = this.selected_link.link or this.selected_link
                this.ui.link:onGotoLink(link)
                this:onClose()
            end,
        }
    end)

    
end












function ReaderHighlight:onShowHighlightMenu(index)
    if not self.selected_text then
        return
    end

    local highlight_buttons = {{}}

    -- Здесь нам нужно только изменить количество колонок
    local columns = 6
    for idx, fn_button in ffiUtil.orderedPairs(self._highlight_buttons) do
        local button = fn_button(self, index)
        if not button.show_in_highlight_dialog_func or button.show_in_highlight_dialog_func() then
            if #highlight_buttons[#highlight_buttons] >= columns then
                table.insert(highlight_buttons, {})
            end
            table.insert(highlight_buttons[#highlight_buttons], button)
            logger.dbg("ReaderHighlight", idx..": line "..#highlight_buttons..", col "..#highlight_buttons[#highlight_buttons])
        end
    end

    self.highlight_dialog = ButtonDialog:new{
        buttons = highlight_buttons,
        shrink_unneeded_width = true,
        shrink_min_width = 900,
        anchor = function()
            return self:_getDialogAnchor(self.highlight_dialog, index)
        end,
        tap_close_callback = function()
            if self.hold_pos then
                self:clear()
            end
        end,
    }
    -- NOTE: Disable merging for this update,
    --       or the buggy Sage kernel may alpha-blend it into the page (with a bogus alpha value, to boot)...
    UIManager:show(self.highlight_dialog, "[ui]")
end





function ReaderHighlight:showHighlightDialog(index)
    local item = self.ui.annotation.annotations[index]
    local change_boundaries_enabled = not item.text_edited
    local start_prev, start_next, end_prev, end_next = "◁▒▒", "▷☓▒", "▒☓◁", "▒▒▷"
    if BD.mirroredUILayout() then
        -- BiDi will mirror the arrows, and this just works
        start_prev, start_next = start_next, start_prev
        end_prev, end_next = end_next, end_prev
    end
    local move_by_char = false
    local edit_highlight_dialog
    local buttons = {
        {
            {
                icon = "circle.filled.red",
                callback = function()
                    self:editHighlightColorFormatted(index, "lighten","red")
                    UIManager:close(edit_highlight_dialog)
                end,
				hold_callback = function()
                    self:editHighlightColorFormatted(index, "underscore","red_dark")
                    UIManager:close(edit_highlight_dialog)
                end,
            },
            {
                icon = "circle.filled.yellow",
                callback = function()
                    self:editHighlightColorFormatted(index, "lighten","yellow")
                    UIManager:close(edit_highlight_dialog)
                end,
				hold_callback = function()
                    self:editHighlightColorFormatted(index, "underscore","yellow_dark")
                    UIManager:close(edit_highlight_dialog)
                end,
            },
            {
                icon = "circle.filled.green",
                callback = function()
                    self:editHighlightColorFormatted(index, "lighten","green")
                    UIManager:close(edit_highlight_dialog)
                end,
				hold_callback = function()
                    self:editHighlightColorFormatted(index, "underscore","green_dark")
                    UIManager:close(edit_highlight_dialog)
                end,
            },
            {
                icon = "circle.filled.cyan",
                callback = function()
                    self:editHighlightColorFormatted(index, "lighten","cyan")
                    UIManager:close(edit_highlight_dialog)
                end,
				hold_callback = function()
                    self:editHighlightColorFormatted(index, "underscore","cyan_dark")
                    UIManager:close(edit_highlight_dialog)
                end,
            },
            {
                icon = "circle.filled.blue",
                callback = function()
                    self:editHighlightColorFormatted(index, "lighten","blue")
                    UIManager:close(edit_highlight_dialog)
                end,
				hold_callback = function()
                    self:editHighlightColorFormatted(index, "underscore","blue_dark")
                    UIManager:close(edit_highlight_dialog)
                end,
            },
            {
                icon = "circle.filled.purple",
                callback = function()
                    self:editHighlightColorFormatted(index, "lighten","purple")
                    UIManager:close(edit_highlight_dialog)
                end,
				hold_callback = function()
                    self:editHighlightColorFormatted(index, "underscore","purple_dark")
                    UIManager:close(edit_highlight_dialog)
                end,
            },
        },{
            {
                icon = "copy",
                enabled = Device:hasClipboard(),
                callback = function()
                    self.selected_text = util.tableDeepCopy(item)
                    Device.input.setClipboardText(util.cleanupSelectedText(self.selected_text.text))
                    UIManager:close(edit_highlight_dialog)
                    UIManager:show(Notification:new{
                        text = _("Selection copied to clipboard."),
                    })
                    UIManager:scheduleIn(G_defaults:readSetting("DELAY_CLEAR_HIGHLIGHT_S"), function()
                        self:clear()
                    end)
                end,
            },
            {
                icon = "edit2",
                callback = function()
                    self:editNote(index)
                    UIManager:close(edit_highlight_dialog)
                end,
            },
            {
                icon = "language",
                callback = function()
                    self.selected_text = util.tableDeepCopy(item)
                    self:lookupDict(index)
                    UIManager:close(edit_highlight_dialog)
                end,
            },
            {
                icon = "search2",
                callback = function()
                    self.selected_text = util.tableDeepCopy(item)
                    self:onHighlightSearch()
                end,
            },
            
            
            
        },
        {
            
            {
                icon = "trash",
                callback = function()
                    self:deleteHighlight(index)
                    UIManager:close(edit_highlight_dialog)
                end,
            },
            {
                icon = "texture",
                enabled = not (index and self.ui.annotation.annotations[index].text_edited),
                callback = function()
                    self:startSelection(index)
                    UIManager:close(edit_highlight_dialog)
                    if not Device:isTouchDevice() then
                        self:onStartHighlightIndicator()
                    end
                end,
            },
            {
                icon = "info2",
                callback = function()
                    self.ui.bookmark:showBookmarkDetails(index)
                    UIManager:close(edit_highlight_dialog)
                end,
            },
            
        },
        {
            {
                text = start_prev,
                enabled = change_boundaries_enabled,
                callback = function()
                    self:updateHighlight(index, 0, -1, move_by_char)
                end,
                hold_callback = function()
                    move_by_char = not move_by_char
                    self:updateHighlight(index, 0, -1, true)
                end,
            },
            {
                text = start_next,
                enabled = change_boundaries_enabled,
                callback = function()
                    self:updateHighlight(index, 0, 1, move_by_char)
                end,
                hold_callback = function()
                    move_by_char = not move_by_char
                    self:updateHighlight(index, 0, 1, true)
                end,
            },
            {
                text = end_prev,
                enabled = change_boundaries_enabled,
                callback = function()
                    self:updateHighlight(index, 1, -1, move_by_char)
                end,
                hold_callback = function()
                    move_by_char = not move_by_char
                    self:updateHighlight(index, 1, -1, true)
                end,
            },
            {
                text = end_next,
                enabled = change_boundaries_enabled,
                callback = function()
                    self:updateHighlight(index, 1, 1, move_by_char)
                end,
                hold_callback = function()
                    move_by_char = not move_by_char
                    self:updateHighlight(index, 1, 1, true)
                end,
            },
        },
    }


    if Device:canShareText() then
        local action = _("Share Text")
        table.insert(buttons[2], {
            icon = "share",
            callback = function()
                self.selected_text = util.tableDeepCopy(item)
                local text = util.cleanupSelectedText(self.selected_text.text)
                UIManager:close(edit_highlight_dialog)
                Device:doShareText(text, action)
            end,
        })
    end

    





    


    edit_highlight_dialog = ButtonDialog:new{
        name = "edit_highlight_dialog", -- for unit tests
        buttons = buttons,
        shrink_unneeded_width = true,
        shrink_min_width = 900,
        anchor = function()
            return self:_getDialogAnchor(edit_highlight_dialog, index)
        end,
    }
    UIManager:show(edit_highlight_dialog)
end










function ReaderHighlight:saveHighlightFormatted(extend_to_sentence,hlStyle,hlColor)
    logger.dbg("save highlight")
    if self.hold_pos and not self.selected_text then
        self:highlightFromHoldPos()
    end
    if self.selected_text and self.selected_text.pos0 and self.selected_text.pos1 then
        local pg_or_xp
        if self.ui.rolling then
            if extend_to_sentence then
                local extended_text = self.ui.document:extendXPointersToSentenceSegment(self.selected_text.pos0, self.selected_text.pos1)
                if extended_text then
                    self.selected_text = extended_text
                end
            end
            pg_or_xp = self.selected_text.pos0
        else
            pg_or_xp = self.selected_text.pos0.page
        end
        local item = {
            page = self.ui.paging and self.selected_text.pos0.page or self.selected_text.pos0,
            pos0 = self.selected_text.pos0,
            pos1 = self.selected_text.pos1,
            text = util.cleanupSelectedText(self.selected_text.text),
            drawer = hlStyle, -- choose drawer style (e.g. underline/lighten) instead of using self.view.highlight.saved_drawer
            color = hlColor, -- choose color instead of using self.view.highlight.saved_color
			chapter = table.concat(self.ui.toc:getFullTocTitleByPage(pg_or_xp), " ▸ "), --- comment this out to get original chapter name text
            --chapter = self.ui.toc:getTocTitleByPage(pg_or_xp), -- uncomment this to get original chapter name text
        }
        if self.ui.paging then
            item.pboxes = self.selected_text.pboxes
            item.ext = self.selected_text.ext
            self:writePdfAnnotation("save", item)
        end
        local index = self.ui.annotation:addItem(item)
        self.view.footer:maybeUpdateFooter()
        self.ui:handleEvent(Event:new("AnnotationsModified", { item, nb_highlights_added = 1, index_modified = index }))
        return index
    end
end





function ReaderHighlight:editHighlightColorFormatted(index, hlStyle, hlColor)
    local item = self.ui.annotation.annotations[index]
    self:writePdfAnnotation("delete", item)
    item.color = hlColor
    item.drawer = hlStyle
    if self.ui.paging then
        self:writePdfAnnotation("save", item)
        if item.note then
            self:writePdfAnnotation("content", item, item.note)
        end
    end
    UIManager:setDirty(self.dialog, "ui")
    self.ui:handleEvent(Event:new("AnnotationsModified", { item }))
end







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