local scope = "known_shelf"
local captured_scope

package.preload["docsettings"] = function() return {} end
package.preload["logger"] = function()
    return {
        warn = function() end,
    }
end
package.preload["provider_library.placeholder"] = function()
    return {
        upsert = function() return "unchanged" end,
        build_index = function() return {} end,
    }
end
package.preload["provider_library.util"] = function()
    return {
        file_exists = function() return false end,
    }
end
package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function() return nil end,
    }
end

package.path = "./?.lua;" .. package.path
local Sync = require("provider_library.sync")

local provider = {
    id = "example",
    plugin_name = "example",
    scan = function(_, _, options)
        captured_scope = options.scope
        return {}
    end,
}
local settings = {
    get = function(_, key, default)
        if key == "sync_scope" then return scope end
        return default
    end,
    flush = function() end,
}
local context = {
    ui = { example = {} },
    providers = { provider },
    settings = settings,
    allow_network = false,
    plugin_path = ".",
}

local report = Sync.run(context)
assert(captured_scope == "known_shelf")
assert(report.scope == "known_shelf")

scope = "cached_only"
report = Sync.run(context)
assert(captured_scope == "cached_only")
assert(report.scope == "cached_only")

scope = "invalid"
report = Sync.run(context)
assert(captured_scope == "known_shelf")
assert(report.scope == "known_shelf")

print("sync_spec: ok")
