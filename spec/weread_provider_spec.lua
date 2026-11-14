local cache_root = "/cache/weread"
local shelf = {
    {
        bookId = "cached",
        title = "已缓存书",
        author = "作者甲",
        cover = "https://example.test/cached.jpg",
        progress = 42,
        readUpdateTime = 1760000000,
        chapterTitle = "已读章节",
    },
    {
        bookId = "uncached",
        title = "未缓存书架书",
        author = "作者乙",
        cover = "https://example.test/uncached.jpg",
        progress = 7,
    },
}
local stored_books = {
    cached = { cache_dir = cache_root .. "/cached" },
}

package.preload["libs/libkoreader-lfs"] = function()
    return {}
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
        file_exists = function(path)
            return path == cache_root .. "/cached/one.html"
        end,
        dir_exists = function(path)
            return path == cache_root .. "/cached"
        end,
        read_file = function(path)
            if path == cache_root .. "/cached/metadata.json" then
                return {
                    cached_chapters = { one = cache_root .. "/cached/one.html" },
                }
            elseif path == cache_root .. "/cached/reading_state.json" then
                return {}
            elseif path == cache_root .. "/cached/catalog.json" then
                return { chapters = { {}, {}, {}, {}, {} } }
            end
        end,
        directory_size = function()
            return 4096
        end,
    }
end

package.preload["json"] = function()
    return {
        decode = function(value) return value end,
    }
end

package.path = "./?.lua;" .. package.path
local Provider = require("provider_library.providers.weread")

local opened = {}
local plugin = {
    settings = {
        cache_dir = cache_root,
        data_dir = cache_root,
        get = function(_, key)
            if key == "books" then return stored_books end
        end,
    },
    library_db = {
        getShelf = function() return shelf end,
    },
    openBookForReading = function(_, book)
        opened[#opened + 1] = "read:" .. book.book_id
    end,
    showBookRecord = function(_, book)
        opened[#opened + 1] = "details:" .. book.book_id
    end,
}

local known = Provider:scan(plugin, { scope = "known_shelf" })
assert(#known == 2)
assert(known[1].book_id == "cached")
assert(known[1].cached_count == 1)
assert(known[1].total_count == 5)
assert(known[1].cache_bytes == 4096)
assert(known[1].progress_percent == 42)
assert(known[2].book_id == "uncached")
assert(known[2].cached_count == 0)
assert(known[2].cache_bytes == 0)
assert(known[2].book.cached_count == 0)
assert(#Provider:scan(plugin) == 2)

local cached = Provider:scan(plugin, { scope = "cached_only" })
assert(#cached == 1)
assert(cached[1].book_id == "cached")

assert(Provider:open(plugin, known[1].book))
assert(opened[1] == "read:cached")
assert(Provider:open(plugin, known[2].book))
assert(opened[2] == "details:uncached")

print("weread_provider_spec: ok")
