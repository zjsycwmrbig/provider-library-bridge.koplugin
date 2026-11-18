local downloaded_path =
    "/koreader/suwayomi/source/manga/第02话 [id-2].cbz"
local missing_path =
    "/koreader/suwayomi/source/manga/第03话 [id-3].cbz"
local folder = "/koreader/suwayomi/source/manga"

local data = {
    credentials = { server_url = "http://suwayomi.test" },
    library_cache = {
        version = 1,
        endpoint_scope = "http://suwayomi.test",
        manga = {
            {
                id = 10,
                title = "书目一",
                author = "作者甲",
                unread_count = 3,
                in_library = true,
            },
            {
                id = 20,
                title = "书目二",
                author = "作者乙",
                unread_count = 2,
                in_library = true,
            },
        },
    },
    chapter_cache = {
        endpoint_scope = "http://suwayomi.test",
        mangas = {
            ["10"] = {
                manga = {
                    id = 10,
                    title = "书目一",
                    author = "作者甲",
                    endpoint_scope = "http://suwayomi.test",
                    unread_count = 3,
                },
                chapters = {
                    { id = 1, name = "第01话", is_read = true, source_order = 1 },
                    { id = 2, name = "第02话", is_read = false, source_order = 2 },
                    { id = 3, name = "第03话", is_read = false, source_order = 3 },
                    { id = 4, name = "第04话", is_read = false, source_order = 4 },
                    { id = 5, name = "第05话", is_read = false, source_order = 5 },
                },
            },
            ["20"] = {
                manga = {
                    id = 20,
                    title = "书目二",
                    author = "作者乙",
                    endpoint_scope = "http://suwayomi.test",
                    unread_count = 2,
                },
                chapters = {
                    { id = 6, name = "第01话", is_read = true, source_order = 1 },
                    { id = 7, name = "第02话", is_read = false, source_order = 2 },
                },
            },
        },
    },
    chapter_ledger = {
        ["10:2"] = {
            manga_id = 10,
            manga_title = "书目一",
            chapter_id = 2,
            chapter_name = "第02话",
            path = downloaded_path,
            read = false,
        },
        ["10:3"] = {
            manga_id = 10,
            manga_title = "书目一",
            chapter_id = 3,
            chapter_name = "第03话",
            path = missing_path,
            read = false,
        },
    },
    reader_return_contexts = {
        [downloaded_path] = {
            manga_id = 10,
            manga_title = "书目一",
            chapter_id = 2,
            chapter_name = "第02话",
            source_order = 2,
            path = downloaded_path,
        },
    },
}

package.preload["datastorage"] = function()
    return {
        getSettingsDir = function() return "/settings" end,
    }
end

package.preload["provider_library.util"] = function()
    return {
        load_lua = function(path)
            if path == "/settings/suwayomi.lua" then return data end
        end,
        trim = function(value)
            return (tostring(value or ""):match("^%s*(.-)%s*$"))
        end,
        file_exists = function(path) return path == downloaded_path end,
        directory_size = function(path)
            return path == folder and 4096 or 0
        end,
        progress_percent = function(value)
            value = tonumber(value)
            if not value then return nil end
            if value <= 1 then value = value * 100 end
            return math.max(0, math.min(100, value))
        end,
        ensure_dir = function() return true end,
        safe_filename = function(value) return tostring(value) end,
    }
end

package.path = "./?.lua;" .. package.path
local Provider = require("provider_library.providers.suwayomi")

local opened, opened_options
local plugin = {
    showChaptersForManga = function(_, manga, options)
        opened = manga
        opened_options = options
        return true
    end,
}

local known = Provider:scan(plugin, {
    scope = "known_shelf",
    settings = { data_dir = "/bridge-data" },
})
assert(#known == 2)
assert(known[1].book_id == "10")
assert(known[1].cached_count == 1)
assert(known[1].total_count == 5)
assert(known[1].progress_percent == 40)
assert(known[1].last_read_title == "第02话")
assert(known[1].cache_path == folder)
assert(known[1].cache_bytes == 4096)
assert(known[1].book.cache_dir == folder)
assert(known[1].first_unread_chapter_id == 2)
assert(tostring(known[1].book.first_unread_chapter.id) == "2")
assert(tostring(known[1].book.id) == "10")
assert(known[1].book.endpoint_scope == "http://suwayomi.test")

assert(known[2].book_id == "20")
assert(known[2].cached_count == 0)
assert(known[2].total_count == 2)
assert(known[2].progress_percent == 0)
assert(known[2].cache_path == nil)

local cached = Provider:scan(plugin, {
    scope = "cached_only",
    settings = { data_dir = "/bridge-data" },
})
assert(#cached == 1)
assert(cached[1].book_id == "10")

local stale_book = {
    id = 10,
    book_id = "10",
    endpoint_scope = "http://suwayomi.test",
    cache_dir = folder,
}
local prepared = Provider:prepare(plugin, stale_book)
assert(tostring(prepared.first_unread_chapter.id) == "2")
assert(prepared.progress == 0.4)

assert(Provider:open(plugin, prepared))
assert(tostring(opened.id) == "10")
assert(tostring(opened_options.return_context.chapter_id) == "2")
assert(opened_options.return_context.chapter_name == "第02话")

data.library_cache.manga[1].first_unread_chapter = {
    id = 4,
    name = "第04话",
}
local cache_prepared = Provider:prepare(plugin, stale_book)
assert(tostring(cache_prepared.first_unread_chapter.id) == "2")

local chapter_listing = data.chapter_cache.mangas["10"]
data.chapter_cache.mangas["10"] = nil
local explicit_only = Provider:prepare(plugin, stale_book)
assert(tostring(explicit_only.first_unread_chapter.id) == "4")
data.chapter_cache.mangas["10"] = chapter_listing

data.library_cache.manga[2].unread_count = 0
for _, chapter in ipairs(data.chapter_cache.mangas["20"].chapters) do
    chapter.is_read = true
end
local all_read = Provider:prepare(plugin, {
    id = 20,
    book_id = "20",
    endpoint_scope = "http://suwayomi.test",
})
assert(all_read.first_unread_chapter == nil)
opened_options = nil
assert(Provider:open(plugin, all_read))
assert(opened_options == nil)

assert(Provider:display_title("Ura Baito: Toubou Kinshi")
    == "Ura Baito: Toubou Kinshi")
assert(Provider:display_title("灰色兼职：逃亡禁止") == "灰色兼职：逃亡禁止")

local removed_manga = data.library_cache.manga[1]
table.remove(data.library_cache.manga, 1)
data.chapter_cache.mangas["10"].manga.in_library = true
local after_removal, snapshot = Provider:scan(plugin, { scope = "known_shelf" })
assert(#after_removal == 1 and after_removal[1].book_id == "20")
assert(snapshot.library_members["10"] == nil)
assert(snapshot.library_members["20"] == true)
assert(#Provider:scan(plugin, { scope = "cached_only" }) == 0)
data.library_cache.manga = {}
local empty, empty_snapshot = Provider:scan(plugin)
assert(#empty == 0 and next(empty_snapshot.library_members) == nil)
data.library_cache.manga = { removed_manga }
data.chapter_cache.endpoint_scope = "http://foreign.test"
local foreign_chapters = Provider:scan(plugin)
assert(#foreign_chapters == 1 and foreign_chapters[1].total_count == 0)
data.library_cache.endpoint_scope = "http://foreign.test"
assert(not pcall(Provider.scan, Provider, plugin))
data.library_cache = nil
assert(not pcall(Provider.scan, Provider, plugin))
data.library_cache = { version = 1, endpoint_scope = "http://suwayomi.test", manga = { bad = {} } }
assert(not pcall(Provider.scan, Provider, plugin))

print("suwayomi_provider_spec: ok")
