local root = "/mnt/us/Books"
local folder = root .. "/已读"
local moved = folder .. "/示例书 [42].html"
local duplicate = root .. "/副本/示例书 [42].html"
local written_html
local written_path

local tree = {
    [root] = { "已读", "副本", "普通书.html" },
    [folder] = { "示例书 [42].html" },
    [root .. "/副本"] = { "示例书 [42].html" },
}
local markers = {
    [moved] = {
        version = 1,
        provider_id = "fanqie",
        book_id = "42",
        last_opened_at = 50,
    },
    [duplicate] = {
        version = 1,
        provider_id = "fanqie",
        book_id = "42",
        last_opened_at = 100,
    },
}
local existing_files = {
    [moved] = true,
    [duplicate] = true,
}

package.preload["libs/libkoreader-lfs"] = function()
    return {
        dir = function(path)
            local entries = tree[path] or {}
            local index = 0
            return function()
                index = index + 1
                return entries[index]
            end
        end,
        attributes = function(path, field)
            if tree[path] then
                return field == "mode" and "directory" or {
                    mode = "directory", modification = 1,
                }
            elseif existing_files[path] or path == root .. "/普通书.html" then
                return field == "mode" and "file" or {
                    mode = "file",
                    modification = path == duplicate and 90 or 60,
                }
            end
        end,
        mkdir = function() return true end,
    }
end

package.preload["docsettings"] = function()
    local DocSettings = {}
    function DocSettings:open(path)
        return {
            readSetting = function(_, key)
                if key == "provider_library_placeholder" then
                    return markers[path]
                end
            end,
            saveSetting = function() end,
            flush = function() end,
        }
    end
    function DocSettings:hasSidecarFile(path)
        return markers[path] ~= nil
    end
    function DocSettings:findCustomCoverFile()
        return nil
    end
    function DocSettings.flushCustomCover()
        return true
    end
    return DocSettings
end

package.preload["provider_library.util"] = function()
    return {
        dir_exists = function(path) return tree[path] ~= nil end,
        file_exists = function(path) return existing_files[path] == true end,
        ensure_dir = function() return true end,
        safe_filename = function(value) return tostring(value) end,
        signature = function(value) return tostring(value.progress_percent) end,
        display_title = function(_, value) return tostring(value) end,
        clean_title = function(value) return tostring(value or "无题") end,
        html_escape = function(value) return tostring(value or "") end,
        format_time = function(_, fallback) return fallback end,
        format_bytes = function(value) return tostring(value or 0) .. " B" end,
        progress_percent = function(value)
            value = tonumber(value)
            if value and value <= 1 then value = value * 100 end
            return value
        end,
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
        writeToFile = function(content, path)
            written_html = content
            written_path = path
            return true
        end,
    }
end

package.path = "./?.lua;" .. package.path
local Placeholder = require("provider_library.placeholder")
local settings = {
    data_dir = "/tmp/provider-library-data",
    values = {},
    get = function(self, key, default)
        if key == "target_root" then return root end
        return self.values[key] or default
    end,
    get_placeholder = function() return nil end,
    set_placeholder = function(self, provider_id, book_id, value)
        self.values.placeholder = { provider_id, book_id, value }
    end,
}

local index = Placeholder.build_index(settings)
assert(Placeholder.find_existing(index, "fanqie", "42") == duplicate)
assert(Placeholder.find_existing(index, "fanqie", "42", moved) == moved)
assert(Placeholder.find_existing(index, "fanqie", "missing") == nil)

local result, err = Placeholder.upsert(
    { id = "fanqie", label = "番茄小说", tag = "番茄" },
    {
        provider_id = "fanqie",
        book_id = "42",
        title = "示例书",
        author = "作者",
        cached_count = 1,
        total_count = 10,
        progress_percent = 42,
        book = { book_id = "42", cache_dir = "/cache/42" },
    },
    settings,
    false,
    ".",
    index
)
assert(result == "updated", err)
assert(written_path == duplicate)
assert(written_html:match("42.0%%"))
assert(settings.values.placeholder[3].path == duplicate)
assert(settings.values["/unused"] == nil)

local metadata = require("docsettings"):open(duplicate)
local _ = metadata

print("placeholder_index_spec: ok")
