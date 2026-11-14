local cache_root = "/cache/fanqie"
local existing_directories = {
    [cache_root] = true,
    [cache_root .. "/cached"] = true,
}
local shelf = {
    {
        book_id = "cached",
        title = "已在书架并缓存",
        author = "作者甲",
        cover = "https://example.test/cached.jpg",
        total_chapters = 12,
        read_chapters = 3,
    },
    {
        book_id = "uncached",
        title = "只在已知书架",
        author = "作者乙",
        cover = "https://example.test/uncached.jpg",
        total_chapters = 20,
        progress = 0.25,
    },
}

package.preload["libs/libkoreader-lfs"] = function()
    return {
        dir = function(path)
            if path == cache_root then
                local entries = {
                    ".", "..", "covers", "shelf_cache.lua", "cached",
                }
                local index = 0
                return function()
                    index = index + 1
                    return entries[index]
                end
            elseif path == cache_root .. "/cached" then
                local entries = { "chapter_1.html", "chapter_2.html" }
                local index = 0
                return function()
                    index = index + 1
                    return entries[index]
                end
            end
        end,
    }
end

package.preload["provider_library.util"] = function()
    return {
        trim = function(value)
            return (tostring(value or ""):match("^%s*(.-)%s*$"))
        end,
        progress_percent = function(value)
            value = tonumber(value)
            if not value then return nil end
            if value <= 1 then value = value * 100 end
            return math.max(0, math.min(100, value))
        end,
        dir_exists = function(path)
            return existing_directories[path] == true
        end,
        file_exists = function(path)
            return path == cache_root .. "/covers/cached.jpg"
        end,
        load_lua = function(path)
            if path == cache_root .. "/shelf_cache.lua" then
                return shelf
            elseif path == cache_root .. "/cached/book_meta.lua" then
                return { author = "作者甲" }
            elseif path == cache_root .. "/cached/catalog_cache.lua" then
                return { {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {} }
            end
        end,
        directory_size = function()
            return 1234
        end,
    }
end

package.path = "./?.lua;" .. package.path
local Provider = require("provider_library.providers.fanqie")

local plugin = {
    settings = {
        get_download_dir = function()
            return cache_root
        end,
    },
}

local known = Provider:scan(plugin, { scope = "known_shelf" })
assert(#known == 2)
assert(known[1].book_id == "cached")
assert(known[1].cached_count == 2)
assert(known[1].total_count == 12)
assert(known[1].cache_bytes == 1234)
assert(known[2].book_id == "uncached")
assert(known[2].cached_count == 0)
assert(known[2].cache_bytes == 0)
assert(known[2].book.cached_count == 0)
assert(known[2].progress_percent == 25)
assert(#Provider:scan(plugin) == 2)

local cached = Provider:scan(plugin, { scope = "cached_only" })
assert(#cached == 1)
assert(cached[1].book_id == "cached")

plugin.client = {
    fetch_read_progress = function()
        return {
            data = {
                {
                    book_id = "cached",
                    item_id = "cloud-item",
                    read_progress = 4321,
                    read_timestamp = 1794648000,
                },
            },
        }
    end,
}
local cloud = Provider:scan(plugin, {
    scope = "cached_only",
    allow_network = true,
})
assert(#cloud == 1)
assert(cloud[1].progress_percent == 43.21)
assert(cloud[1].progress_source == "cloud")
assert(cloud[1].book.progress == 0.4321)
assert(cloud[1].book.item_id == "cloud-item")

local prepared = Provider:prepare(plugin, { book_id = "cached" })
assert(prepared.progress == 0.4321)
assert(prepared.read_timestamp == 1794648000)

print("fanqie_provider_spec: ok")
