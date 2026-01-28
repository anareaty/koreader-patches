local InfoMessage = require("ui/widget/infomessage")
local ReaderMenu = require("apps/reader/modules/readermenu")
local ReaderConfig = require("apps/reader/modules/readerconfig")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local Device = require("device")
local Event = require("ui/event")
local Dispatcher = require("dispatcher")



local gestures_path = ffiUtil.joinPath(DataStorage:getSettingsDir(), "gestures.lua")






function onSwipeShowMenuPatched(self, ges)
    if self.activation_menu ~= "tap" and ges.direction == "south" then
        local gestures_data = LuaSettings:open(gestures_path)
        if not next(gestures_data.data) then
            -- No gestures settings, use default menu gesture
            self:onSwipeShowMenu(self, ges)
        else
            local action_list = gestures_data.data["gesture_reader"]["two_finger_swipe_south"]
            if action_list == nil then
                -- No gesture set, use default menu gesture
                self:onSwipeShowMenu(self, ges)
            else
                -- Use two finger south swipe instead
                local exec_props = { gesture = ges }
                if action_list.settings and action_list.settings.anchor_quickmenu then
                    exec_props.qm_anchor = ges.end_pos or ges.pos
                end
                Dispatcher:execute(action_list, exec_props)
                self.ui:handleEvent(Event:new("HandledAsSwipe"))
                return true
            end
        end
    end
end








function onSwipeShowConfigMenuPatched(self, ges)
    if ges.direction == "north" then
        local gestures_data = LuaSettings:open(gestures_path)
        if not next(gestures_data.data) then
            -- No gestures settings, use default menu gesture
            self:onSwipeShowConfigMenu(self, ges)
        else
            local action_list = gestures_data.data["gesture_reader"]["two_finger_swipe_north"]
            if action_list == nil then
                -- No gesture set, use default menu gesture
                self:onSwipeShowConfigMenu(self, ges)
            else
                -- Use two finger north swipe instead
                local exec_props = { gesture = ges }
                if action_list.settings and action_list.settings.anchor_quickmenu then
                    exec_props.qm_anchor = ges.end_pos or ges.pos
                end
                Dispatcher:execute(action_list, exec_props)
                self.ui:handleEvent(Event:new("HandledAsSwipe"))
                return true
            end
        end
    end
end






function onTapShowMenuPatched(self, ges)
    local gestures_data = LuaSettings:open(gestures_path)
    if not next(gestures_data.data) then
        -- No gestures settings, use default menu gesture
        self:onTapShowMenu(self, ges)
    else
        local action_list = gestures_data.data["gesture_reader"]["two_finger_swipe_east"]
        if action_list == nil then
            -- No gesture set, use default menu gesture
            self:onTapShowMenu(self, ges)
        else
            -- Use two finger north swipe instead
            local exec_props = { gesture = ges }
            if action_list.settings and action_list.settings.anchor_quickmenu then
                exec_props.qm_anchor = ges.end_pos or ges.pos
            end
            Dispatcher:execute(action_list, exec_props)
            return true
        end
    end
end







function onTapShowConfigMenuPatched(self, ges)
    local gestures_data = LuaSettings:open(gestures_path)
    if not next(gestures_data.data) then
        -- No gestures settings, use default menu gesture
        self:onTapShowConfigMenu(self)
    else
        local action_list = gestures_data.data["gesture_reader"]["two_finger_swipe_west"]
        if action_list == nil then
            -- No gesture set, use default menu gesture
            self:onTapShowConfigMenu(self)
        else
            -- Use two finger north swipe instead
            local exec_props = { gesture = ges }
            if action_list.settings and action_list.settings.anchor_quickmenu then
                exec_props.qm_anchor = ges.end_pos or ges.pos
            end
            Dispatcher:execute(action_list, exec_props)
            return true
        end
    end
end









-- Replacing menu swipe can potentially lock us out of using menu entirely if no any other methods of opening menu is set.
-- As a failsafe we must add another hardcoded method for menu opening
-- We are using two fingers hold instead


function onDowbleHoldShowMenu(self, ges)
    if G_reader_settings:nilOrTrue("show_bottom_menu") then
        self.ui:handleEvent(Event:new("ShowConfigMenu"))
    end
    self:onShowMenu(self:_getTabIndexFromLocation(ges))
    return true
end


 
ReaderMenu.onReaderReady = function(self)
    if not Device:isTouchDevice() then return end

    local DTAP_ZONE_MENU = G_defaults:readSetting("DTAP_ZONE_MENU")
    local DTAP_ZONE_MENU_EXT = G_defaults:readSetting("DTAP_ZONE_MENU_EXT")
    self.ui:registerTouchZones({
        {
            id = "readermenu_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x, ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w, ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = {},
            handler = function(ges) return onTapShowMenuPatched(self, ges) end,
        },
        {
            id = "readermenu_ext_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU_EXT.x, ratio_y = DTAP_ZONE_MENU_EXT.y,
                ratio_w = DTAP_ZONE_MENU_EXT.w, ratio_h = DTAP_ZONE_MENU_EXT.h,
            },
            overrides = {
                "readermenu_tap",
            },
            handler = function(ges) return onTapShowMenuPatched(self, ges) end,
        },
        {
            id = "readermenu_swipe",
            ges = "swipe",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x, ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w, ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = {},
            handler = function(ges) return onSwipeShowMenuPatched(self, ges) end,
        },
        {
            id = "readermenu_ext_swipe",
            ges = "swipe",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU_EXT.x, ratio_y = DTAP_ZONE_MENU_EXT.y,
                ratio_w = DTAP_ZONE_MENU_EXT.w, ratio_h = DTAP_ZONE_MENU_EXT.h,
            },
            overrides = {
                "readermenu_swipe",
            },
            handler = function(ges) return onSwipeShowMenuPatched(self, ges) end,
        },
        {
            id = "readermenu_pan",
            ges = "pan",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x, ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w, ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = {},
            handler = function(ges) return onSwipeShowMenuPatched(self, ges) end,
        },
        {
            id = "readermenu_ext_pan",
            ges = "pan",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU_EXT.x, ratio_y = DTAP_ZONE_MENU_EXT.y,
                ratio_w = DTAP_ZONE_MENU_EXT.w, ratio_h = DTAP_ZONE_MENU_EXT.h,
            },
            overrides = {
                "readermenu_pan",
            },
            handler = function(ges) return onSwipeShowMenuPatched(self, ges) end,
        },

        --[[
        {
            id = "readermenu_two_finger_hold",
            ges = "two_finger_hold",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x, ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w, ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = {},
            handler = function(ges) 
                return onDowbleHoldShowMenu(self, ges)
            end
        },
        ]]
    })
    
end


    



-- READER CONFIG MENU

-- We don't need failsafe for config menu, because the main menu can fix any problems

function ReaderConfig:initGesListener()
    if not Device:isTouchDevice() then return end

    local DTAP_ZONE_CONFIG = G_defaults:readSetting("DTAP_ZONE_CONFIG")
    local DTAP_ZONE_CONFIG_EXT = G_defaults:readSetting("DTAP_ZONE_CONFIG_EXT")
    self.ui:registerTouchZones({
        {
            id = "readerconfigmenu_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = DTAP_ZONE_CONFIG.x, ratio_y = DTAP_ZONE_CONFIG.y,
                ratio_w = DTAP_ZONE_CONFIG.w, ratio_h = DTAP_ZONE_CONFIG.h,
            },
            overrides = {},
            handler = function() return onTapShowConfigMenuPatched(self, ges) end,
        },
        {
            id = "readerconfigmenu_ext_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = DTAP_ZONE_CONFIG_EXT.x, ratio_y = DTAP_ZONE_CONFIG_EXT.y,
                ratio_w = DTAP_ZONE_CONFIG_EXT.w, ratio_h = DTAP_ZONE_CONFIG_EXT.h,
            },
            overrides = {
                "readerconfigmenu_tap",
            },
            handler = function() return onTapShowConfigMenuPatched(self, ges) end,
        },
        {
            id = "readerconfigmenu_swipe",
            ges = "swipe",
            screen_zone = {
                ratio_x = DTAP_ZONE_CONFIG.x, ratio_y = DTAP_ZONE_CONFIG.y,
                ratio_w = DTAP_ZONE_CONFIG.w, ratio_h = DTAP_ZONE_CONFIG.h,
            },
            overrides = {},
            handler = function(ges) return onSwipeShowConfigMenuPatched(self, ges) end,
        },
        {
            id = "readerconfigmenu_ext_swipe",
            ges = "swipe",
            screen_zone = {
                ratio_x = DTAP_ZONE_CONFIG_EXT.x, ratio_y = DTAP_ZONE_CONFIG_EXT.y,
                ratio_w = DTAP_ZONE_CONFIG_EXT.w, ratio_h = DTAP_ZONE_CONFIG_EXT.h,
            },
            overrides = {
                "readerconfigmenu_swipe",
            },
            handler = function(ges) return onSwipeShowConfigMenuPatched(self, ges) end,
        },
        {
            id = "readerconfigmenu_pan",
            ges = "pan",
            screen_zone = {
                ratio_x = DTAP_ZONE_CONFIG.x, ratio_y = DTAP_ZONE_CONFIG.y,
                ratio_w = DTAP_ZONE_CONFIG.w, ratio_h = DTAP_ZONE_CONFIG.h,
            },
            overrides = {},
            handler = function(ges) return onSwipeShowConfigMenuPatched(self, ges) end,
        },
        {
            id = "readerconfigmenu_ext_pan",
            ges = "pan",
            screen_zone = {
                ratio_x = DTAP_ZONE_CONFIG_EXT.x, ratio_y = DTAP_ZONE_CONFIG_EXT.y,
                ratio_w = DTAP_ZONE_CONFIG_EXT.w, ratio_h = DTAP_ZONE_CONFIG_EXT.h,
            },
            overrides = {
                "readerconfigmenu_pan",
            },
            handler = function(ges) return onSwipeShowConfigMenuPatched(self, ges) end,
        },
    })
end