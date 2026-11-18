local captured_html
local captured_cover_svg
local written_settings = {}

package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function(path, field)
            if path == "/tmp/generic.svg" then
                return field == "mode" and "file" or { mode = "file", size = 10 }
            end
        end,
        dir = function()
            return function()
                return nil
            end
        end,
        mkdir = function()
            return true
        end,
    }
end

package.preload["util"] = function()
    return {
        fixUtf8 = function(value)
            return value
        end,
        splitToChars = function(value)
            local chars = {}
            for character in tostring(value):gmatch(
                "[%z\1-\127\194-\244][\128-\191]*"
            ) do
                chars[#chars + 1] = character
            end
            return chars
        end,
        writeToFile = function(content, path, flush, lua_dofile_ready)
            assert(flush and not lua_dofile_ready, "HTML and images must be raw bytes")
            if path:match("%.html$") then
                captured_html = content
            elseif path == "/tmp/generic.svg" then
                captured_cover_svg = content
            end
            return true
        end,
    }
end

package.preload["docsettings"] = function()
    local DocSettings = {}
    function DocSettings:open(path)
        return {
            readSetting = function(_, key)
                return written_settings[path] and written_settings[path][key]
            end,
            saveSetting = function(_, key, value)
                written_settings[path] = written_settings[path] or {}
                written_settings[path][key] = value
            end,
            flush = function()
                return true
            end,
        }
    end
    function DocSettings:findCustomCoverFile()
        return nil
    end
    function DocSettings.flushCustomCover(_, path, cover)
        written_settings.cover = { path = path, cover = cover }
        return true
    end
    return DocSettings
end

package.preload["ui/event"] = function()
    return {
        new = function(_, value)
            return value
        end,
    }
end

package.preload["ui/uimanager"] = function()
    return {
        broadcastEvent = function() end,
    }
end

package.preload["ltn12"] = function()
    return {}
end

package.preload["logger"] = function()
    return {
        warn = function() end,
    }
end

package.preload["provider_library.generic_cover"] = function()
    return {
        generate = function()
            captured_cover_svg = "<svg/>"
            return "/tmp/generic.svg", nil, "eclipse"
        end,
    }
end

package.path = "./?.lua;" .. package.path

local Placeholder = require("provider_library.placeholder")
local settings = {
    data_dir = "/tmp/provider-library-test",
    values = {},
    get = function(self, key, default)
        return self.values[key] or default
    end,
    get_placeholder = function()
        return nil
    end,
    set_placeholder = function(self, provider_id, book_id, value)
        self.values.placeholder = { provider_id, book_id, value }
    end,
}
local provider = {
    id = "fanqie",
    label = "番茄小说",
    tag = "番茄",
}
local record = {
    provider_id = provider.id,
    book_id = "7011072854741486628",
    title = "《黑死馆杀人事件》",
    author = "[日] 小栗虫太郎",
    cached_count = 17,
    total_count = 19,
    progress_percent = 42.5,
    progress_source = "cloud",
    last_read_title = "惨剧（一）",
    read_timestamp = 1760000000,
    cache_bytes = 11 * 1024 * 1024,
    book = {
        book_id = "7011072854741486628",
        title = "黑死馆杀人事件",
    },
}

local result, err = Placeholder.upsert(
    provider, record, settings, false, "."
)
assert(result == "created", err)
assert(captured_html:match("黑死馆杀人事件"))
assert(captured_html:match("42.5%%"))
assert(captured_html:match("惨剧 一") or captured_html:match("惨剧（一）"))
assert(captured_html:match("17 / 19"))
assert(captured_html:match("11.0 MB"))
assert(captured_cover_svg == "<svg/>")
assert(written_settings.cover.cover == "/tmp/generic.svg")
local placeholder_path =
    "/mnt/us/Books/黑死馆杀人事件 [7011072854741486628].html"
assert(written_settings[placeholder_path].percent_finished == 0.425)
assert(written_settings[placeholder_path].summary.status == "reading")

local marker = written_settings[placeholder_path].provider_library_placeholder
assert(marker.tag == "番茄")
assert(marker.cover_kind == "generic")
assert(marker.cover_variant == "eclipse")
assert(marker.marker_schema == 3)
assert(marker.progress_source == "cloud")

-- A provider may lose its local cover while the bridge still has a valid cache.
local original_open = io.open
local cached_cover = settings.data_dir .. "/covers/fanqie-" .. record.book_id .. ".jpg"
io.open = function(path, mode)
    if path == cached_cover then
        return { read = function() return "\255\216\255cached-image" end,
            close = function() end }
    end
    return original_open(path, mode)
end
local lfs = require("libs/libkoreader-lfs")
local original_attributes = lfs.attributes
lfs.attributes = function(path, field)
    if path == cached_cover then
        return field == "mode" and "file" or { mode = "file", size = 16 }
    end
    return original_attributes(path, field)
end
result, err = Placeholder.upsert(provider, record, settings, false, ".")
assert(result == "created", err)
assert(written_settings.cover.cover == cached_cover)
assert(marker ~= written_settings[placeholder_path].provider_library_placeholder)
assert(written_settings[placeholder_path].provider_library_placeholder.cover_kind == "official")
io.open = original_open
lfs.attributes = original_attributes

-- A failed unlink must preserve sidecars and history for a later retry.
local original_remove = os.remove
lfs.attributes = function(path, field)
    if path == placeholder_path then
        return field == "mode" and "file" or { mode = "file" }
    end
    return original_attributes(path, field)
end
os.remove = function() return nil, "permission denied" end
local removed, remove_error = Placeholder.remove(placeholder_path, true)
assert(removed == false and remove_error == "permission denied")
assert(written_settings[placeholder_path].provider_library_placeholder)
os.remove = original_remove
lfs.attributes = original_attributes

print("placeholder_spec: ok")
