-- Creates an action for every collection to be able to access them without opening the collections list.
 


local FileManagerCollection = require("apps/filemanager/filemanagercollection")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local ReadCollection = require("readcollection")


local function registerCollectionActions()
    local collections = ReadCollection.coll
    for collection in pairs(collections) do
        -- An action for favorites already exists
        if collection ~= "favorites" then
            local name = collection
            local title = "Show collection: " .. name
            local action = "show-collection-" .. name
            Dispatcher:registerAction(action, {category="none", event="ShowColl", title=title, general=true, arg=name})
        end
    end
end

-- Register actions on init
local init_orig = FileManagerCollection.init
function FileManagerCollection:init()
    init_orig(self)
    registerCollectionActions()
end

-- Update actions when collections updated
local updateCollListItemTable_orig = FileManagerCollection.updateCollListItemTable
function FileManagerCollection:updateCollListItemTable(do_init, item_number)
    updateCollListItemTable_orig(self, do_init, item_number)
    registerCollectionActions()
end