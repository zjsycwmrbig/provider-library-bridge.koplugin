local values = {}

package.preload["datastorage"] = function()
    return {
        getSettingsDir = function() return "/settings" end,
        getFullDataDir = function() return "/data" end,
    }
end

package.preload["luasettings"] = function()
    return {
        open = function()
            return {
                readSetting = function(_, key, default)
                    if values[key] == nil then return default end
                    return values[key]
                end,
                saveSetting = function(_, key, value)
                    values[key] = value
                end,
                flush = function() return true end,
            }
        end,
    }
end

package.path = "./?.lua;" .. package.path
local Settings = require("provider_library.settings")
local settings = Settings:new()

assert(settings:get("sync_scope") == "known_shelf")
settings:set("sync_scope", "cached_only")
assert(settings:get("sync_scope") == "cached_only")
assert(settings:is_provider_enabled("fanqie"))
settings:set_provider_enabled("fanqie", false)
assert(not settings:is_provider_enabled("fanqie"))
assert(settings:is_provider_enabled("weread"))
settings:set_provider_enabled("fanqie", true)
assert(settings:is_provider_enabled("fanqie"))

print("settings_spec: ok")
