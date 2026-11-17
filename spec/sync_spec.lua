local scope = "known_shelf"
local captured_scope
local captured_network
local provider_enabled = true
local scan_calls = 0

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
        scan_calls = scan_calls + 1
        captured_scope = options.scope
        captured_network = options.allow_network
        return {}
    end,
}
local settings = {
    get = function(_, key, default)
        if key == "sync_scope" then return scope end
        return default
    end,
    flush = function() end,
    is_provider_enabled = function(_, provider_id)
        return provider_id == "example" and provider_enabled
    end,
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
assert(captured_network == false)
assert(scan_calls == 1)

scope = "cached_only"
report = Sync.run(context)
assert(captured_scope == "cached_only")
assert(report.scope == "cached_only")

provider_enabled = false
report = Sync.run(context)
assert(scan_calls == 2)
assert(report.created == 0)

provider_enabled = true

scope = "invalid"
report = Sync.run(context)
assert(captured_scope == "known_shelf")
assert(report.scope == "known_shelf")

print("sync_spec: ok")
