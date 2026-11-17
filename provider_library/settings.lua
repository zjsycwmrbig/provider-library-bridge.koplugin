local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local Settings = {}
Settings.__index = Settings

local DEFAULTS = {
    version = 1,
    target_root = "/mnt/us/Books",
    sync_scope = "known_shelf",
    disabled_providers = {},
    auto_sync_enabled = false,
    auto_sync_interval_minutes = 1440,
    last_auto_attempt = 0,
    last_sync = 0,
    last_status = "",
    placeholders = {},
}

local function deepcopy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, item in pairs(value) do
        result[key] = deepcopy(item)
    end
    return result
end

function Settings:new()
    local store = LuaSettings:open(
        DataStorage:getSettingsDir() .. "/provider_library_bridge.lua"
    )
    if store:readSetting("target_root") == "/mnt/us/Books/在线书库" then
        store:saveSetting("target_root", "/mnt/us/Books")
        store:flush()
    end
    return setmetatable({
        store = store,
        data_dir = DataStorage:getFullDataDir() .. "/provider-library-bridge",
    }, self)
end

function Settings:get(key, default)
    if default == nil then
        default = DEFAULTS[key]
    end
    return self.store:readSetting(key, deepcopy(default))
end

function Settings:set(key, value)
    self.store:saveSetting(key, value)
end

function Settings:flush()
    self.store:flush()
end

function Settings:get_placeholder(provider_id, book_id)
    local placeholders = self:get("placeholders", {})
    local provider_items = placeholders[provider_id]
    return provider_items and provider_items[tostring(book_id)] or nil
end

function Settings:set_placeholder(provider_id, book_id, value)
    local placeholders = self:get("placeholders", {})
    placeholders[provider_id] = placeholders[provider_id] or {}
    placeholders[provider_id][tostring(book_id)] = value
    self:set("placeholders", placeholders)
end

function Settings:remove_placeholder(provider_id, book_id)
    local placeholders = self:get("placeholders", {})
    local provider_items = placeholders[provider_id]
    if not provider_items then
        return
    end
    provider_items[tostring(book_id)] = nil
    if next(provider_items) == nil then
        placeholders[provider_id] = nil
    end
    self:set("placeholders", placeholders)
end

function Settings:all_placeholders()
    return self:get("placeholders", {})
end

function Settings:is_provider_enabled(provider_id)
    local disabled = self:get("disabled_providers", {})
    return type(disabled) ~= "table" or disabled[provider_id] ~= true
end

function Settings:set_provider_enabled(provider_id, enabled)
    local disabled = self:get("disabled_providers", {})
    if type(disabled) ~= "table" then
        disabled = {}
    end
    if enabled then
        disabled[provider_id] = nil
    else
        disabled[provider_id] = true
    end
    self:set("disabled_providers", disabled)
end

return Settings
