local FileManagerHistory = require("apps/filemanager/filemanagerhistory")
local FileManagerCollection = require("apps/filemanager/filemanagercollection")
local BookList = require("ui/widget/booklist")


-- Save current document data when opening history widget from the reader view
-- It will help us to show correct progress for the opened book

local function saveCurrentBookData(ui)
    if ui.document then 
        local current_page = ui:getCurrentPage()
        local total_pages = ui.document.info.number_of_pages
        local percent
        if current_page > 0 and total_pages > 0 then
            percent = current_page / total_pages
        end
        
        local summary = ui.doc_settings:readSetting("summary")
        if summary == nil then summary = {} end
        if summary.status == nil or summary.status == "new" then
            summary.status = "reading"
        end

        ui.doc_settings:saveSetting("percent_finished", percent)
        ui.doc_settings:saveSetting("summary", summary)

        file = ui.document.file
        BookList.setBookInfoCache(file, ui.doc_settings)
    end
end



local onShowHist_orig = FileManagerHistory.onShowHist
function FileManagerHistory:onShowHist(collection_name)    
    saveCurrentBookData(self.ui)
    return onShowHist_orig(self, collection_name)
end


local onShowColl_orig = FileManagerCollection.onShowColl
function FileManagerCollection:onShowColl(collection_name)    
    saveCurrentBookData(self.ui)
    return onShowColl_orig(self, collection_name)
end

