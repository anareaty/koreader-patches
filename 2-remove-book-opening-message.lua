
local BD = require("ui/bidi")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local Device = require("device")
local Input = Device.input
local ReaderUI = require("apps/reader/readerui")
local DocSettings = require("docsettings")
local ffiUtil  = require("ffi/util")
local _ = require("gettext")
local T = ffiUtil.template
local logger = require("logger")


function ReaderUI:showReaderCoroutine(file, provider, seamless)

    --[[
    UIManager:show(InfoMessage:new{
        text = T(_("Opening file '%1'."), BD.filepath(filemanagerutil.abbreviate(file))),
        timeout = 0.0,
        invisible = seamless,
    })
    ]]
    
    -- doShowReader might block for a long time, so force repaint here
    UIManager:forceRePaint()
    UIManager:nextTick(function()
        logger.dbg("creating coroutine for showing reader")
        local co = coroutine.create(function()
            self:doShowReader(file, provider, seamless)
        end)
        local ok, err = coroutine.resume(co)
        if err ~= nil or ok == false then
            io.stderr:write('[!] doShowReader coroutine crashed:\n')
            io.stderr:write(debug.traceback(co, err, 1))
            -- Restore input if we crashed before ReaderUI has restored it
            Device:setIgnoreInput(false)
            Input:inhibitInputUntil(0.2)
            UIManager:show(InfoMessage:new{
                text = _("No reader engine for this file or invalid file.")
            })
            self:showFileManager(file)
        end
    end)
end