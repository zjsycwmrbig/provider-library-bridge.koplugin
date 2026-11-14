local lfs = require("libs/libkoreader-lfs")

local History = {}

local SETTINGS_KEY = "provider_library_bridge_history_map"

local function normalize(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    return path:gsub("/+$", "")
end

local function settings_store()
    if G_reader_settings
        and type(G_reader_settings.readSetting) == "function"
        and type(G_reader_settings.saveSetting) == "function" then
        return G_reader_settings
    end
end

local function read_map()
    local store = settings_store()
    if not store then
        return {}
    end
    local map = store:readSetting(SETTINGS_KEY, {})
    return type(map) == "table" and map or {}
end

local function write_map(store, map)
    if not store then
        return
    end
    store:saveSetting(SETTINGS_KEY, map)
end

local function path_matches(path, prefix)
    return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
end

function History.canonical_for(path)
    path = normalize(path)
    if not path then
        return nil
    end
    local best_source
    local canonical
    for source, target in pairs(read_map()) do
        source = normalize(source)
        target = normalize(target)
        if source and target and path_matches(path, source)
            and (not best_source or #source > #best_source) then
            best_source = source
            canonical = target
        end
    end
    if canonical and lfs.attributes(canonical, "mode") == "file" then
        return canonical
    end
end

function History.register(placeholder_path, sources)
    placeholder_path = normalize(placeholder_path)
    local store = settings_store()
    if not (store and placeholder_path) then
        return
    end
    local map = read_map()
    local changed = false
    for source, target in pairs(map) do
        if target == placeholder_path then
            map[source] = nil
            changed = true
        end
    end
    for _, source in ipairs(sources or {}) do
        source = normalize(source)
        if source and source ~= placeholder_path
            and map[source] ~= placeholder_path then
            map[source] = placeholder_path
            changed = true
        end
    end
    if changed then
        write_map(store, map)
    end
end

function History.unregister(placeholder_path)
    placeholder_path = normalize(placeholder_path)
    local store = settings_store()
    if not (store and placeholder_path) then
        return
    end
    local map = read_map()
    local changed = false
    for source, target in pairs(map) do
        if target == placeholder_path then
            map[source] = nil
            changed = true
        end
    end
    if changed then
        write_map(store, map)
    end
end

function History.flush()
    local store = settings_store()
    if store and type(store.flush) == "function" then
        store:flush()
    end
end

function History.remove_canonical(path)
    path = normalize(path)
    local ok, ReadHistory = pcall(require, "readhistory")
    if not (path and ok and ReadHistory and type(ReadHistory.hist) == "table") then
        return
    end
    local changed = false
    for index = #ReadHistory.hist, 1, -1 do
        local item = ReadHistory.hist[index]
        if item and normalize(item.file) == path
            and type(ReadHistory.removeItem) == "function" then
            ReadHistory:removeItem(item, index, true)
            changed = true
        end
    end
    if changed and type(ReadHistory._flush) == "function" then
        ReadHistory:_flush()
    end
end

function History.install()
    local ok, ReadHistory = pcall(require, "readhistory")
    if not (ok and ReadHistory and type(ReadHistory.addItem) == "function") then
        return false
    end
    if ReadHistory._provider_library_bridge_original_add_item then
        return true
    end
    local original_add_item = ReadHistory.addItem
    ReadHistory._provider_library_bridge_original_add_item = original_add_item
    ReadHistory.addItem = function(self, path, timestamp, no_flush)
        local canonical = History.canonical_for(path)
        return original_add_item(self, canonical or path, timestamp, no_flush)
    end
    return true
end

function History.reconcile()
    local ok, ReadHistory = pcall(require, "readhistory")
    if not (ok and ReadHistory and type(ReadHistory.hist) == "table") then
        return
    end

    local canonical_paths = {}
    for _, target in pairs(read_map()) do
        target = normalize(target)
        if target then
            canonical_paths[target] = true
        end
    end

    local latest = {}
    local changed = false
    for index = #ReadHistory.hist, 1, -1 do
        local item = ReadHistory.hist[index]
        local path = item and item.file
        local canonical = History.canonical_for(path)
        if canonical and normalize(path) ~= canonical then
            latest[canonical] = math.max(latest[canonical] or 0, tonumber(item.time) or 0)
            if type(ReadHistory.removeItem) == "function" then
                ReadHistory:removeItem(item, index, true)
                changed = true
            end
        elseif path and canonical_paths[normalize(path)] then
            local normalized = normalize(path)
            latest[normalized] = math.max(latest[normalized] or 0, tonumber(item.time) or 0)
        end
    end

    for canonical, timestamp in pairs(latest) do
        if lfs.attributes(canonical, "mode") == "file" then
            if ReadHistory:addItem(canonical, timestamp > 0 and timestamp or nil, true) then
                changed = true
            end
        end
    end
    if changed and type(ReadHistory._flush) == "function" then
        ReadHistory:_flush()
    end
    History.flush()
end

return History
