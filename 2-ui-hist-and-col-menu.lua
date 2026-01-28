local BD = require("ui/bidi")
local BookList = require("ui/widget/booklist")
local ButtonDialog = require("ui/widget/buttondialog")
local CheckButton = require("ui/widget/checkbutton")
local ConfirmBox = require("ui/widget/confirmbox")
local InputDialog = require("ui/widget/inputdialog")
local ReadCollection = require("readcollection")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Utf8Proc = require("ffi/utf8proc")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template
local FileManagerHistory = require("apps/filemanager/filemanagerhistory")
local FileManagerCollection = require("apps/filemanager/filemanagercollection")
local FileManager = require("apps/filemanager/filemanager")
local Button = require("ui/widget/button")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local Geom = require("ui/geometry")
local RightContainer = require("ui/widget/container/rightcontainer")
local TextWidget = require("ui/widget/textwidget")
local Device = require("device")
local Screen = Device.screen
local TitleBar = require("ui/widget/titlebar")





function FileManagerHistory:showHistDialog()
    if not self.statuses_fetched then
        self:fetchStatuses(true)
    end

    local hist_dialog
    local buttons = {}
    local function genFilterButton(filter)

        local button_text = T(_("%1 (%2)"), BookList.getBookStatusString(filter), self.count[filter])
        if self.filter == filter then
            button_text = "◉ " .. button_text
        else
            button_text = "○ " .. button_text
        end
        
        return {
            text = button_text,
            menu_style = true,
            callback = function()
                UIManager:close(hist_dialog)
                self.filter = filter
                if filter == "all" then -- reset all filters
                    self.search_string = nil
                    self.selected_collections = nil
                end
                self:updateItemTable()
            end,
        }
    end
    table.insert(buttons, {
        genFilterButton("all"),

    })
    table.insert(buttons, {
        genFilterButton("new"),
    })
    
    table.insert(buttons, {
        genFilterButton("reading"),
    })
    table.insert(buttons, {
        genFilterButton("abandoned"),
    })
    table.insert(buttons, {
        genFilterButton("complete"),
    })
    table.insert(buttons, {
        genFilterButton("deleted"),
    })

    local icon_row = {}

    table.insert(icon_row, {
        --text = _("Filter by collections"),
        icon = "books",
        callback = function()
            UIManager:close(hist_dialog)
            local caller_callback = function(selected_collections)
                self.selected_collections = selected_collections
                self:updateItemTable()
            end
            self.ui.collections:onShowCollList(self.selected_collections or {}, caller_callback, true) -- no dialog to apply
        end,
    })


    table.insert(icon_row, 
        {
            --text = _("Search in filename and book metadata"),
            icon = "search2",
            callback = function()
                UIManager:close(hist_dialog)
                self:onSearchHistory()
            end,
        }
    )
    if self.count.deleted > 0 then

        table.insert(icon_row, 
            {
                --text = _("Clear history of deleted files"),
                icon = "clear",
                callback = function()
                    local confirmbox = ConfirmBox:new{
                        text = _("Clear history of deleted files?"),
                        ok_text = _("Clear"),
                        ok_callback = function()
                            UIManager:close(hist_dialog)
                            require("readhistory"):clearMissing()
                            self:updateItemTable()
                        end,
                    }
                    UIManager:show(confirmbox)
                end,
            }
        )
    end


    table.insert(buttons, icon_row)
    hist_dialog = ButtonDialog:new{
        buttons = buttons,
        shrink_unneeded_width = true,
        anchor = function()
            local dimen = Geom:new {
                y = 120,
                x = 120
            }

            return dimen
        end,
    }
    UIManager:show(hist_dialog)
end
















function FileManagerCollection:showCollDialog()
    local collection_name = self.booklist_menu.path
    local coll_not_empty = #self.booklist_menu.item_table > 0
    local coll_dialog
    local function genFilterByStatusButton(button_status)
        local icon = "book.closed"
        if button_status == "reading" then
            icon = "book.opened"
        elseif button_status == "abandoned" then
            icon = "pause"
        elseif button_status == "complete" then
            icon = "check"
        end
        return {
            --text = BookList.getBookStatusString(button_status),
            icon = icon,
            enabled = coll_not_empty,
            callback = function()
                UIManager:close(coll_dialog)
                util.tableSetValue(self, button_status, "match_table", "status")
                self:updateItemTable()
            end,
        }
    end
    local function genFilterByMetadataButton(button_icon, button_prop)
        return {
            --text = button_text,
            icon = button_icon,
            enabled = coll_not_empty,
            callback = function()
                UIManager:close(coll_dialog)
                local prop_values = {}
                for idx, item in ipairs(self.booklist_menu.item_table) do
                    local doc_prop = self.ui.bookinfo:getDocProps(item.file, nil, true)[button_prop]
                    if doc_prop == nil then
                        doc_prop = { self.empty_prop }
                    elseif button_prop == "series" then
                        doc_prop = { doc_prop }
                    elseif button_prop == "language" then
                        doc_prop = { doc_prop:lower() }
                    else -- "authors", "keywords"
                        doc_prop = util.splitToArray(doc_prop, "\n")
                    end
                    for _, prop in ipairs(doc_prop) do
                        prop_values[prop] = prop_values[prop] or {}
                        table.insert(prop_values[prop], idx)
                    end
                end
                self:showPropValueList(button_prop, prop_values)
            end,
        }
    end
    local buttons = {
        {{
            text = _("Collections"),
            callback = function()
                UIManager:close(coll_dialog)
                self.booklist_menu.close_callback()
                self:onShowCollList()
            end,
        }},

        {
            genFilterByStatusButton("new"),
            genFilterByStatusButton("reading"),
            genFilterByStatusButton("abandoned"),
            genFilterByStatusButton("complete"),
        },
        {
            genFilterByMetadataButton("user", "authors"),
            genFilterByMetadataButton("list", "series"),
            genFilterByMetadataButton("language", "language"),
            genFilterByMetadataButton("tag", "keywords"),
        },
        {{
            text = _("Reset all filters"),
            enabled = self.match_table ~= nil,
            callback = function()
                UIManager:close(coll_dialog)
                self.match_table = nil
                self:updateItemTable()
            end,
        }},

        {
            {
                --text = _("Select"),
                icon = "select",
                enabled = coll_not_empty,
                callback = function()
                    UIManager:close(coll_dialog)
                    self:toggleSelectMode()
                end,
            },
            {
                --text = _("Search"),
                icon = "search2",
                enabled = coll_not_empty,
                callback = function()
                    UIManager:close(coll_dialog)
                    self:onShowCollectionsSearchDialog(nil, collection_name)
                end,
            },
            {
                --text = _("Arrange books in collection"),
                icon = "sort",
                enabled = coll_not_empty and self.match_table == nil,
                callback = function()
                    UIManager:close(coll_dialog)
                    self:showArrangeBooksDialog()
                end,
            },
            {
                icon = "add", 
                callback = function()
                    UIManager:show(self.more_dialog)
                end,
            }
        },
        
    }


    local more_buttons = {
        {{
            text = _("Add all books from a folder"),
            callback = function()
                UIManager:close(coll_dialog)
                self:addBooksFromFolder(false)
            end,
        }},
        {{
            text = _("Add all books from a folder and its subfolders"),
            callback = function()
                UIManager:close(coll_dialog)
                self:addBooksFromFolder(true)
            end,
        }},
        {{
            text = _("Add a book to collection"),
            callback = function()
                UIManager:close(coll_dialog)
                local PathChooser = require("ui/widget/pathchooser")
                local path_chooser = PathChooser:new{
                    path = G_reader_settings:readSetting("home_dir"),
                    select_directory = false,
                    onConfirm = function(file)
                        if not ReadCollection:isFileInCollection(file, collection_name) then
                            self.updated_collections[collection_name] = true
                            ReadCollection:addItem(file, collection_name)
                            self:updateItemTable(nil, file) -- show added item
                            self.files_updated = self.show_mark
                        end
                    end,
                }
                UIManager:show(path_chooser)
            end,
        }},
    }



    if self.ui.document then
        local file = self.ui.document.file
        local is_in_collection = ReadCollection:isFileInCollection(file, collection_name)
        table.insert(buttons, {{
            text_func = function()
                return is_in_collection and _("Remove current book from collection") or _("Add current book to collection")
            end,
            callback = function()
                UIManager:close(coll_dialog)
                self.updated_collections[collection_name] = true
                if is_in_collection then
                    ReadCollection:removeItem(file, collection_name, true)
                    file = nil
                else
                    ReadCollection:addItem(file, collection_name)
                end
                self:updateItemTable(nil, file)
                self.files_updated = self.show_mark
            end,
        }})
    end
    coll_dialog = ButtonDialog:new{
        buttons = buttons,
        shrink_unneeded_width = true
    }
    UIManager:show(coll_dialog)

    
    self.more_dialog = ButtonDialog:new{
        buttons = more_buttons,
        shrink_unneeded_width = true,
        shrink_min_width = 900
    }
end



