local path = "/mnt/us/Books/示例书 [42].html"
local sidecar = {
    provider_library_placeholder = {
        version = 1,
        marker_schema = 3,
        provider_id = "fanqie",
        book_id = "42",
        progress_percent = 40,
    },
    percent_finished = 0.10,
}

local function read_value(values, key)
    return values[key]
end

package.preload["docsettings"] = function()
    local DocSettings = {}
    function DocSettings:open()
        return {
            readSetting = function(_, key) return read_value(sidecar, key) end,
            saveSetting = function(_, key, value) sidecar[key] = value end,
            flush = function() return true end,
        }
    end
    function DocSettings:findCustomCoverFile()
        return "/tmp/cover.jpg"
    end
    function DocSettings.flushCustomCover()
        return true
    end
    return DocSettings
end

package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function(requested, field)
            if requested == path then
                return field == "mode" and "file" or { mode = "file", size = 1 }
            end
        end,
        dir = function()
            local done = false
            return function()
                if done then return nil end
                done = true
                return "."
            end
        end,
        mkdir = function() return true end,
    }
end

package.preload["provider_library.history"] = function()
    return {
        register = function() end,
        unregister = function() end,
        move = function() end,
        remove_canonical = function() end,
    }
end
package.preload["provider_library.generic_cover"] = function()
    return {
        generate = function()
            return "/tmp/generic-cover.png", nil, "eclipse"
        end,
    }
end
package.preload["provider_library.util"] = function()
    return {
        trim = function(value) return tostring(value or "") end,
        clean_title = function(value) return tostring(value or "") end,
        display_title = function(_, value) return tostring(value or "") end,
        safe_filename = function(value) return tostring(value) end,
        signature = function() return "same-signature" end,
        progress_percent = function(value) return tonumber(value) end,
        format_time = function(_, fallback) return fallback end,
        format_bytes = function(value) return tostring(value) end,
        html_escape = function(value) return tostring(value or "") end,
        ensure_dir = function() return true end,
        dir_exists = function() return false end,
        file_exists = function(requested) return requested == path end,
    }
end
package.preload["ui/event"] = function()
    return { new = function(_, value) return value end }
end
package.preload["ui/uimanager"] = function()
    return { broadcastEvent = function() end }
end
package.preload["ltn12"] = function() return {} end
package.preload["logger"] = function()
    return { warn = function() end }
end
package.preload["util"] = function()
    return {
        writeToFile = function() return true end,
        splitToChars = function(value) return { value } end,
        fixUtf8 = function(value) return value end,
    }
end

package.path = "./?.lua;" .. package.path
local Placeholder = require("provider_library.placeholder")
local settings = {
    data_dir = "/tmp/provider-data",
    get = function(_, key, default)
        if key == "target_root" then return "/mnt/us/Books" end
        return default
    end,
    get_placeholder = function()
        return {
            path = path,
            signature = "same-signature\n0",
        }
    end,
    set_placeholder = function() end,
}

local result, err = Placeholder.upsert(
    { id = "fanqie", label = "番茄小说", tag = "番茄" },
    {
        provider_id = "fanqie",
        book_id = "42",
        title = "示例书",
        author = "作者",
        cached_count = 1,
        total_count = 10,
        progress_percent = 40,
        progress_source = "cloud",
        book = { book_id = "42" },
    },
    settings,
    false,
    ".",
    {}
)
assert(result == "updated", err)
assert(math.abs(sidecar.percent_finished - 0.40) < 0.000001)
assert(sidecar.provider_library_placeholder.progress_source == "cloud")

print("placeholder_progress_migration_spec: ok")
