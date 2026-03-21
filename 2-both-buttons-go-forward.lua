local Device = require("device")
local Dispatcher = require("dispatcher")
local FileManager = require("apps/filemanager/filemanager")
local framebuffer = require("ffi/framebuffer")
local ReaderUI = require("apps/reader/readerui")
local _ = require("gettext")



local function init_patch(app)
    Device:applyBothButtonsState()

    app.onToggleBothButtonsForward = function(self)
        if G_reader_settings:isTrue("both_buttons_forward") then
            G_reader_settings:saveSetting("both_buttons_forward", false)
            Device:applyBothButtonsState()
        else
            G_reader_settings:saveSetting("both_buttons_forward", true)
            Device:applyBothButtonsState()
        end
    end

    Dispatcher:registerAction(
        "toggle_both_buttons_forward",
        {
            category = "none",
            event = "ToggleBothButtonsForward",
            title = _("Toggle both buttons forward"),
            general = true
        }
    )
end


-- Apply button state in both reader and filemanager

local ReaderUI_init_orig = ReaderUI.init
function ReaderUI:init()
    ReaderUI_init_orig(self)
    init_patch(self)
end


local FileManager_init_orig = FileManager.init
function FileManager:init()
    FileManager_init_orig(self)
    init_patch(self)
end






function Device:setBothButtonsForvard()
    if self:hasKeys() and self.input and self.input.event_map then
        self.orig_event_map = {}

        -- Replace back buttons to forward buttons
        -- Only right page buttons are tested since they are the only buttons on KLC
        -- We save original event map to be able to restore it later

        for key, value in pairs(self.input.event_map) do
            if value == "LPgBack" then
                self.input.event_map[key] = "LPgFwd"
                self.orig_event_map[key] = "LPgBack"
            elseif value == "RPgBack" then
                self.input.event_map[key] = "RPgFwd"
                self.orig_event_map[key] = "RPgBack"
            end
        end

        -- Replace upside down rotation so both buttons don't go back instead

        self.input.rotation_map = {
            [framebuffer.DEVICE_ROTATED_UPRIGHT]           = {},
            [framebuffer.DEVICE_ROTATED_CLOCKWISE]         = { Up = "Right", Right = "Down", Down = "Left",  Left = "Up",},
            [framebuffer.DEVICE_ROTATED_UPSIDE_DOWN]       = { Up = "Down",  Right = "Left", Down = "Up",    Left = "Right",},
            [framebuffer.DEVICE_ROTATED_COUNTER_CLOCKWISE] = { Up = "Left",  Right = "Up",   Down = "Right", Left = "Down" },
        }
    end
end


function Device:setBothButtonsNormal()
    if self:hasKeys() and self.input and self.input.event_map then

        -- Restore event map from saved property or do nothing

        if self.orig_event_map then
            for key, value in pairs(self.orig_event_map) do
                if value == "LPgBack" then
                    self.input.event_map[key] = "LPgBack"
                elseif value == "RPgBack" then
                    self.input.event_map[key] = "RPgBack"
                end
            end
        end

        -- Restore original rotation map
        self.input.rotation_map = {
            [framebuffer.DEVICE_ROTATED_UPRIGHT]           = {},
            [framebuffer.DEVICE_ROTATED_CLOCKWISE]         = { Up = "Right", Right = "Down", Down = "Left",  Left = "Up",    LPgBack = "LPgFwd",  LPgFwd  = "LPgBack", RPgBack = "RPgFwd",  RPgFwd  = "RPgBack" },
            [framebuffer.DEVICE_ROTATED_UPSIDE_DOWN]       = { Up = "Down",  Right = "Left", Down = "Up",    Left = "Right", LPgFwd  = "LPgBack", LPgBack = "LPgFwd",  RPgFwd  = "RPgBack", RPgBack = "RPgFwd" },
            [framebuffer.DEVICE_ROTATED_COUNTER_CLOCKWISE] = { Up = "Left",  Right = "Up",   Down = "Right", Left = "Down" },
        }
        
    end
end


function Device:applyBothButtonsState()
    if G_reader_settings:isTrue("both_buttons_forward") then
        self:setBothButtonsForvard()
    else
        self:setBothButtonsNormal()
    end
end