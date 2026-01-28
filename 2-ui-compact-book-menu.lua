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
local FileSearcher = require("apps/filemanager/filemanagerfilesearcher")


function genStatusButtonsRow(doc_settings_or_file, caller_callback)
    local file, summary, status
    if type(doc_settings_or_file) == "table" then
        file = doc_settings_or_file:readSetting("doc_path")
        summary = doc_settings_or_file:readSetting("summary") or {}
        status = summary.status
    else
        file = doc_settings_or_file
        summary = {}
        status = BookList.getBookStatus(file)
    end

    local function genStatusButton(to_status)
        local icon = "book.closed"
        if to_status == "reading" then 
            icon = "book.opened"
        elseif to_status == "abandoned" then 
            icon = "pause"
        elseif to_status == "complete" then
            icon = "check"
        end
        return {
            icon = icon,
            width = 150,
            enabled = status ~= to_status,
            callback = function()
                summary.status = to_status
                filemanagerutil.saveSummary(doc_settings_or_file, summary)
                BookList.setBookInfoCacheProperty(file, "status", to_status)
                caller_callback()
            end,
        }
    end
    return {
        genStatusButton("new"),
        genStatusButton("reading"),
        genStatusButton("abandoned"),
        genStatusButton("complete"),
    }
end



local function genStarGroup(file, doc_settings_or_file, caller_callback)
    local summary
    if doc_settings_or_file.readSetting ~= nil then
        summary = doc_settings_or_file:readSetting("summary")
        if summary == nil then summary = { rating = 0 } end
    else
        summary = { rating = 0 }
    end
    local rating = summary.rating or 0
    
    local function starCallback(star_num) 
        if summary.rating == 1 and star_num == 1 then
            summary.rating = 0
        else
            summary.rating = star_num
        end
        filemanagerutil.saveSummary(doc_settings_or_file, summary)
        BookList.setBookInfoCacheProperty(file, "rating", summary.rating)
        caller_callback()
    end

    local empty_star = Button:new{
        icon = "star.empty",
        bordersize = 0,
        radius = 0,
        margin = 0,
        width = 120,
        icon_width = Screen:scaleBySize(30)
    }

    local row = {}

    for i = 1, rating do
        local star = empty_star:new{
            icon = "star.full",
            callback = function() 
                starCallback(i)
            end
        }
        table.insert(row, star)
    end

    for i = rating + 1, 5 do
        local star = empty_star:new{ 
            callback = function() 
                starCallback(i)
            end 
        }
        table.insert(row, star)
    end

    return row
end




function genAddToCollectionButton(file_manager_collections, file_or_files, caller_pre_callback, caller_post_callback)
    local is_single_file = type(file_or_files) == "string"
    return {
        text = _("Collections"),
        callback = function()
            if caller_pre_callback then
                caller_pre_callback()
            end
            local caller_callback = function(selected_collections)
                for name in pairs(selected_collections) do
                    file_manager_collections.updated_collections[name] = true
                end
                if is_single_file then
                    ReadCollection:addRemoveItemMultiple(file_or_files, selected_collections)
                else -- selected files
                    ReadCollection:addItemsMultiple(file_or_files, selected_collections)
                end
                if caller_post_callback then
                    caller_post_callback()
                end
            end
            -- Для быстроты добавления книг в подборку, выключаем диалог подтверждения. 
            -- При этом мы не сможем создать новую подборку из данного окна, так что придётся их создавать отдельно.
            -- Или потом написать патч, чтобы добавить другой способ
            -- Может быть, на долгое нажатие на кнопку.
            local ignore_dialog = true
            file_manager_collections:onShowCollList(is_single_file and file_or_files or {}, caller_callback, ignore_dialog)
            
        end,
    }
end













function FileManagerHistory:onMenuHold(item)
    local file = item.file
    self.file_dialog = nil
    local book_props = self.ui.coverbrowser and self.ui.coverbrowser:getBookInfo(file)

    local function close_dialog_callback()
        UIManager:close(self.file_dialog)
        UIManager:close(self.more_dialog)
    end
    local function close_dialog_menu_callback()
        UIManager:close(self.file_dialog)
        UIManager:close(self.more_dialog)
        self.close_callback()
    end
    local function close_dialog_update_callback()
        UIManager:close(self.file_dialog)
        UIManager:close(self.more_dialog)
        if self._manager.filter ~= "all" or self._manager.is_frozen then
            self._manager:fetchStatuses(false)
        else
            self._manager.statuses_fetched = false
        end
        self._manager:updateItemTable()
        self._manager.files_updated = true
    end
    local function update_callback()
        self._manager:updateItemTable()
    end
    local function update_dialog_refresh_callback()
        UIManager:close(self.file_dialog)
        self:onMenuHold(item)
        self._manager:updateItemTable()
    end


    local is_currently_opened = file == (self.ui.document and self.ui.document.file)

    local buttons = {}
    local more_buttons = {}

    local doc_settings_or_file
    if is_currently_opened then
        doc_settings_or_file = self.ui.doc_settings
        if not book_props then
            book_props = self.ui.doc_props
            book_props.has_cover = true
        end
    else
        if BookList.hasBookBeenOpened(file) then
            doc_settings_or_file = BookList.getDocSettings(file)
            if not book_props then
                local props = doc_settings_or_file:readSetting("doc_props")
                book_props = self.ui.bookinfo.extendProps(props, file)
                book_props.has_cover = true
            end
        else
            doc_settings_or_file = file
        end
    end




    


    



    if not item.dim then
        table.insert(buttons, genStatusButtonsRow(doc_settings_or_file, update_dialog_refresh_callback))
        table.insert(buttons, genStarGroup(file, doc_settings_or_file, update_dialog_refresh_callback))
    end

    table.insert(buttons, {genAddToCollectionButton(self._manager.ui.collections, file, close_dialog_callback, refresh_callback)})
    table.insert(buttons, {filemanagerutil.genBookCoverButton(file, book_props, close_dialog_callback, item.dim)})
    table.insert(buttons, {filemanagerutil.genBookDescriptionButton(file, book_props, close_dialog_callback, item.dim)})

    table.insert(buttons, {
        {
            text = _("Remove from history"),
            callback = function()
                UIManager:close(self.file_dialog)
                -- The item's idx field is tied to the current *view*, so we can only pass it as-is when there's no filtering *at all* involved.
                local index = item.idx
                if self._manager.search_string or self._manager.selected_collections or self._manager.filter ~= "all" then
                    index = nil
                end
                require("readhistory"):removeItem(item, index)
                self._manager:updateItemTable()
            end,
        }
    })

    table.insert(buttons, {{
        text = _("..."),
        callback = function()
            UIManager:close(self.file_dialog)
            UIManager:show(self.more_dialog)
        end,
    }})



    local resetSettingsButton = filemanagerutil.genResetSettingsButton(doc_settings_or_file, close_dialog_refresh_callback)
    local reset_callback_orig = resetSettingsButton.callback
    resetSettingsButton.callback = function()
        reset_callback_orig()
        UIManager:close(self.more_dialog)
    end

    table.insert(more_buttons, {
        filemanagerutil.genResetSettingsButton(doc_settings_or_file, close_dialog_update_callback, is_currently_opened),
        {
            text = _("Delete"),
            enabled = not (item.dim or is_currently_opened),
            callback = function()
                local FileManager = require("apps/filemanager/filemanager")
                FileManager:showDeleteFileDialog(file, close_dialog_update_callback)
            end,
        }
    })
    
    table.insert(more_buttons, {
        filemanagerutil.genShowFolderButton(file, close_dialog_menu_callback, item.dim),
        filemanagerutil.genBookInformationButton(doc_settings_or_file, book_props, close_dialog_callback, item.dim),
    })


    
    

    if self._manager.file_dialog_added_buttons ~= nil then
        for _, row_func in ipairs(self._manager.file_dialog_added_buttons) do
            local row = row_func(file, true, book_props)
            if row ~= nil then
                for i, button in pairs(row) do
                    local callback_orig = button.callback
                    button.callback = function()
                        callback_orig()
                        UIManager:close(self.more_dialog)
                    end
                end
                table.insert(more_buttons, row)
            end
        end
    end

    self.file_dialog = ButtonDialog:new{
        title = book_props.title or BD.filename(item.text),
        title_align = "center",
        buttons = buttons,
        shrink_unneeded_width = true,
        shrink_min_width = 600,
    }
    UIManager:show(self.file_dialog)


    self.more_dialog = ButtonDialog:new{
        title = book_props.title or BD.filename(item.text),
        title_align = "center",
        buttons = more_buttons,
        shrink_unneeded_width = true,
        shrink_min_width = 800,
    }


    


    
    return true
end





















function FileManagerCollection:onMenuHold(item)
    if self._manager.selected_files then
        self._manager:showSelectModeDialog()
        return true
    end

    local file = item.file
    self.file_dialog = nil
    local book_props = self.ui.coverbrowser and self.ui.coverbrowser:getBookInfo(file)

    local function close_dialog_callback()
        UIManager:close(self.file_dialog)
        UIManager:close(self.more_dialog)
    end
    local function close_dialog_menu_callback()
        UIManager:close(self.file_dialog)
        UIManager:close(self.more_dialog)
        self.close_callback()
    end
    local function close_dialog_update_callback()
        UIManager:close(self.file_dialog)
        UIManager:close(self.more_dialog)
        self._manager:updateItemTable()
        self._manager.files_updated = true
    end

    local function update_dialog_refresh_callback()
        UIManager:close(self.file_dialog)
        self:onMenuHold(item)
        self._manager:updateItemTable()
    end

    local is_currently_opened = file == (self.ui.document and self.ui.document.file)

    local buttons = {}
    local more_buttons = {}


    local doc_settings_or_file
    if is_currently_opened then
        doc_settings_or_file = self.ui.doc_settings
        if not book_props then
            book_props = self.ui.doc_props
            book_props.has_cover = true
        end
    else
        if BookList.hasBookBeenOpened(file) then
            doc_settings_or_file = BookList.getDocSettings(file)
            if not book_props then
                local props = doc_settings_or_file:readSetting("doc_props")
                book_props = self.ui.bookinfo.extendProps(props, file)
                book_props.has_cover = true
            end
        else
            doc_settings_or_file = file
        end
    end




    
    
    



    table.insert(buttons, genStatusButtonsRow(doc_settings_or_file, update_dialog_refresh_callback))
    table.insert(buttons, genStarGroup(file, doc_settings_or_file, update_dialog_refresh_callback))
    
    
    --table.insert(buttons, {self._manager:genAddToCollectionButton(file, close_dialog_callback, close_dialog_update_callback)})
    table.insert(buttons, {genAddToCollectionButton(self._manager, file, close_dialog_callback, close_dialog_update_callback)})


    table.insert(buttons, {
        filemanagerutil.genBookCoverButton(file, book_props, close_dialog_callback),
    })

    table.insert(buttons, {
        filemanagerutil.genBookDescriptionButton(file, book_props, close_dialog_callback),
    })

    table.insert(buttons, {
        {
            text = _("Remove from collection"),
            callback = function()
                self._manager.updated_collections[self.path] = true
                ReadCollection:removeItem(file, self.path, true)
                close_dialog_update_callback()
            end,
        },
    })


    table.insert(buttons, {{
        text = _("..."),
        callback = function()
            UIManager:close(self.file_dialog)
            UIManager:show(self.more_dialog)
        end,
    }})






    local resetSettingsButton = filemanagerutil.genResetSettingsButton(doc_settings_or_file, close_dialog_refresh_callback)
    local reset_callback_orig = resetSettingsButton.callback
    resetSettingsButton.callback = function()
        reset_callback_orig()
        UIManager:close(self.more_dialog)
    end


    table.insert(more_buttons, {
        filemanagerutil.genResetSettingsButton(doc_settings_or_file, close_dialog_update_callback, is_currently_opened),
        {
            text = _("Delete"),
            enabled = not is_currently_opened,
            callback = function()
                local FileManager = require("apps/filemanager/filemanager")
                FileManager:showDeleteFileDialog(file, close_dialog_update_callback)
            end,
        }
    })



    if Device:canExecuteScript(file) then

        local executeScriptButton = filemanagerutil.genExecuteScriptButton(file, close_dialog_callback)
        local script_callback_orig = executeScriptButton.callback
        executeScriptButton.callback = function()
            script_callback_orig()
            UIManager:close(self.more_dialog)
        end
        table.insert(more_buttons, {
            filemanagerutil.genExecuteScriptButton(file, close_dialog_menu_callback)
        })
    end

    
    table.insert(more_buttons, {
        filemanagerutil.genShowFolderButton(file, close_dialog_menu_callback),
        filemanagerutil.genBookInformationButton(doc_settings_or_file, book_props, close_dialog_callback),
    })
    

    if self._manager.file_dialog_added_buttons ~= nil then
        for _, row_func in ipairs(self._manager.file_dialog_added_buttons) do
            local row = row_func(file, true, book_props)
            if row ~= nil then
                for i, button in pairs(row) do
                    local callback_orig = button.callback
                    button.callback = function()
                        callback_orig()
                        UIManager:close(self.more_dialog)
                    end
                end
                table.insert(more_buttons, row)
            end
        end
    end

    self.file_dialog = ButtonDialog:new{
        title = book_props.title or BD.filename(item.text),
        title_align = "center",
        buttons = buttons,
        shrink_unneeded_width = true,
        shrink_min_width = 600,
    }
    UIManager:show(self.file_dialog)


    self.more_dialog = ButtonDialog:new{
        title = book_props.title or BD.filename(item.text),
        title_align = "center",
        buttons = more_buttons,
        shrink_unneeded_width = true,
        shrink_min_width = 800,
    }



    return true
end





















function FileSearcher:onMenuHold(item)
    if self._manager.selected_files or lfs.attributes(item.path) == nil then return true end
    local file = item.path
    local is_file = item.is_file or false
    self.file_dialog = nil

    local function close_dialog_callback()
        UIManager:close(self.file_dialog)
    end
    local function close_dialog_menu_callback()
        UIManager:close(self.file_dialog)
        self.close_callback()
    end
    local function close_dialog_update_callback()
        UIManager:close(self.file_dialog)
        self._manager:updateItemTable()
        self._manager.files_updated = true
    end
    local function close_menu_refresh_callback()
        self._manager.files_updated = true
        self.close_callback()
    end

    local function update_dialog_refresh_callback()
        UIManager:close(self.file_dialog)
        self:onMenuHold(item)
        self._manager:updateItemTable()
    end

    local buttons = {}
    local more_buttons = {}

    local book_props, is_currently_opened
    if is_file then
        local has_provider = DocumentRegistry:hasProvider(file)
        local been_opened = BookList.hasBookBeenOpened(file)
        local doc_settings_or_file = file
        if has_provider or been_opened then
            book_props = self.ui.coverbrowser and self.ui.coverbrowser:getBookInfo(file)
            is_currently_opened = file == (self.ui.document and self.ui.document.file)
            if is_currently_opened then
                doc_settings_or_file = self.ui.doc_settings
                if not book_props then
                    book_props = self.ui.doc_props
                    book_props.has_cover = true
                end
            elseif been_opened then
                doc_settings_or_file = BookList.getDocSettings(file)
                if not book_props then
                    local props = doc_settings_or_file:readSetting("doc_props")
                    book_props = self.ui.bookinfo.extendProps(props, file)
                    book_props.has_cover = true
                end
            end
            table.insert(buttons, genStatusButtonsRow(doc_settings_or_file, update_dialog_refresh_callback))
            table.insert(buttons, genStarGroup(file, doc_settings_or_file, update_dialog_refresh_callback))
            


            table.insert(buttons, {
                filemanagerutil.genResetSettingsButton(doc_settings_or_file, close_dialog_update_callback, is_currently_opened),
                self._manager.ui.collections:genAddToCollectionButton(file, close_dialog_callback, close_dialog_update_callback),
            })
        end
        if Device:canExecuteScript(file) then
            table.insert(buttons, {
                filemanagerutil.genExecuteScriptButton(file, close_dialog_menu_callback)
            })
        end
        if FileManagerConverter:isSupported(file) then
            table.insert(buttons, {
                FileManagerConverter:genConvertButton(file, close_dialog_callback, close_menu_refresh_callback)
            })
        end
        table.insert(buttons, {
            {
                text = _("Delete"),
                enabled = not is_currently_opened,
                callback = function()
                    local function post_delete_callback()
                        table.remove(FileSearcher.search_results, item.idx)
                        table.remove(self.item_table, item.idx)
                        close_dialog_update_callback()
                    end
                    local FileManager = require("apps/filemanager/filemanager")
                    FileManager:showDeleteFileDialog(file, post_delete_callback)
                end,
            },
            {
                text = _("Open with…"),
                callback = function()
                    close_dialog_callback()
                    local FileManager = require("apps/filemanager/filemanager")
                    FileManager.showOpenWithDialog(self.ui, file)
                end,
            },
        })
        table.insert(buttons, {
            filemanagerutil.genShowFolderButton(file, close_dialog_menu_callback),
            filemanagerutil.genBookInformationButton(doc_settings_or_file, book_props, close_dialog_callback),
        })
        if has_provider then
            table.insert(buttons, {
                filemanagerutil.genBookCoverButton(file, book_props, close_dialog_callback),
                filemanagerutil.genBookDescriptionButton(file, book_props, close_dialog_callback),
            })
        end
    else -- folder
        table.insert(buttons, {
            filemanagerutil.genShowFolderButton(file, close_dialog_menu_callback),
        })
    end

    if self._manager.file_dialog_added_buttons ~= nil then
        for _, row_func in ipairs(self._manager.file_dialog_added_buttons) do
            local row = row_func(file, true, book_props)
            if row ~= nil then
                table.insert(buttons, row)
            end
        end
    end

    self.file_dialog = ButtonDialog:new{
        title = is_file and BD.filename(file) or BD.directory(file),
        title_align = "center",
        buttons = buttons,
    }
    UIManager:show(self.file_dialog)
    return true
end