local DocSettings = require("docsettings")
local logger = require("logger")

local History = require("provider_library.history")
local Placeholder = require("provider_library.placeholder")
local U = require("provider_library.util")

local Sync = {}

local LEGACY_DIRECTORIES = {
    "/mnt/us/Books/在线书库/番茄小说",
    "/mnt/us/Books/在线书库/微信读书",
    "/mnt/us/Books/在线书库",
}

local function remove_empty_legacy_directories()
    local lfs = require("libs/libkoreader-lfs")
    for _, directory in ipairs(LEGACY_DIRECTORIES) do
        if lfs.attributes(directory, "mode") == "directory" then
            pcall(lfs.rmdir, directory)
        end
    end
end

local function provider_plugin(ui, plugin_loader, provider)
    if ui and ui[provider.plugin_name] then
        return ui[provider.plugin_name]
    end
    if plugin_loader and plugin_loader.getPluginInstance then
        return plugin_loader:getPluginInstance(provider.plugin_name)
    end
end

function Sync.run(context)
    local report = {
        created = 0,
        updated = 0,
        unchanged = 0,
        failed = 0,
        started_at = os.time(),
    }

    local scope = context.settings:get("sync_scope", "known_shelf")
    if scope ~= "cached_only" then
        scope = "known_shelf"
    end
    local placeholder_index = {}
    local index_ok, built_index = pcall(Placeholder.build_index, context.settings)
    if index_ok and type(built_index) == "table" then
        placeholder_index = built_index
    else
        logger.warn(
            "provider-library-bridge: placeholder index failed",
            tostring(built_index)
        )
    end

    for _, provider in ipairs(context.providers or {}) do
        local plugin = provider_plugin(
            context.ui, context.plugin_loader, provider
        )
        if plugin then
            local ok, records = pcall(provider.scan, provider, plugin, {
                scope = scope,
                allow_network = context.allow_network == true,
                settings = context.settings,
            })
            if not ok then
                logger.warn(
                    "provider-library-bridge: scan failed",
                    provider.id, tostring(records)
                )
                report.failed = report.failed + 1
            elseif type(records) == "table" then
                for _, record in ipairs(records) do
                    record.provider_id = provider.id
                    local synced, err = Placeholder.upsert(
                        provider,
                        record,
                        context.settings,
                        context.allow_network,
                        context.plugin_path,
                        placeholder_index
                    )
                    if synced == "created" then
                        report.created = report.created + 1
                    elseif synced == "updated" then
                        report.updated = report.updated + 1
                    elseif synced == "unchanged" then
                        report.unchanged = report.unchanged + 1
                    else
                        logger.warn(
                            "provider-library-bridge: placeholder failed",
                            provider.id, tostring(record.book_id), tostring(err)
                        )
                        report.failed = report.failed + 1
                    end
                end
            end
        end
    end

    context.settings:flush()
    History.flush()
    local history_ok, history_error = pcall(History.reconcile)
    if not history_ok then
        logger.warn(
            "provider-library-bridge: history reconcile failed",
            tostring(history_error)
        )
    end
    remove_empty_legacy_directories()
    report.finished_at = os.time()
    report.scope = scope
    return report
end

function Sync.clear_placeholders(providers, settings)
    local removed = 0
    local failed = 0
    local placeholders = settings:all_placeholders()
    local known_providers = {}
    for _, provider in ipairs(providers or {}) do
        known_providers[provider.id] = true
    end

    for provider_id, books in pairs(placeholders) do
        for book_id, entry in pairs(books) do
            local path = entry.path
            if path and U.file_exists(path) then
                local owned = Placeholder.is_owned(path, provider_id, book_id)
                if owned then
                    Placeholder.remove(path, true)
                    removed = removed + 1
                elseif known_providers[provider_id] then
                    failed = failed + 1
                end
            end
            settings:remove_placeholder(provider_id, book_id)
        end
    end
    settings:flush()
    History.flush()
    remove_empty_legacy_directories()
    return removed, failed
end

return Sync
