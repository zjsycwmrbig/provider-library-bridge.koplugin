local settings = {
    provider_library_placeholder = { progress_percent = 42 },
    percent_finished = 0.01,
}
local doc_settings = {
    readSetting = function(_, key) return settings[key] end,
    saveSetting = function(_, key, value) settings[key] = value end,
}

package.preload["ui/widget/filechooser"] = function()
    return {
        getMenuItemMandatory = function()
            return ""
        end,
    }
end
package.preload["docsettings"] = function() return {} end
package.preload["ffi/blitbuffer"] = function() return {} end
package.preload["device"] = function() return { screen = {} } end
package.preload["ui/font"] = function() return {} end
package.preload["ui/widget/textwidget"] = function() return {} end
package.preload["ui/uimanager"] = function()
    return {
        nextTick = function() end,
        scheduleIn = function() end,
    }
end
package.preload["provider_library.history"] = function()
    return { install = function() return true end }
end
package.preload["provider_library.util"] = function()
    return {
        progress_percent = function(value)
            value = tonumber(value)
            return value and math.max(0, math.min(100, value))
        end,
    }
end

local function reader_module()
    return {
        onSaveSettings = function(self)
            self.ui.doc_settings.percent_finished = 0.01
        end,
    }
end
local ReaderPaging = reader_module()
local ReaderRolling = reader_module()
package.preload["apps/reader/modules/readerpaging"] = function()
    return ReaderPaging
end
package.preload["apps/reader/modules/readerrolling"] = function()
    return ReaderRolling
end

package.path = "./?.lua;" .. package.path
local UIPatch = require("provider_library.ui_patch")
UIPatch.installProgressGuard()

local context = {
    ui = { doc_settings = doc_settings },
}
ReaderPaging.onSaveSettings(context)
assert(settings.percent_finished == 0.42)

settings.percent_finished = 0.01
ReaderRolling.onSaveSettings(context)
assert(settings.percent_finished == 0.42)

print("ui_patch_progress_spec: ok")
