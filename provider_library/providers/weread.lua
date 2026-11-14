local lfs = require("libs/libkoreader-lfs")

local U = require("provider_library.util")

local Provider = {
    id = "weread",
    label = "微信读书",
    tag = "微信读书",
    plugin_name = "weread",
    priority = 20,
}

local function decode_json(path)
    local ok_json, json = pcall(require, "json")
    if not ok_json or not json then
        return nil
    end
    local data = U.read_file(path)
    if not data then
        return nil
    end
    local ok, value = pcall(json.decode, data)
    if ok and type(value) == "table" then
        return value
    end
end

local function count_table(value)
    local count = 0
    if type(value) == "table" then
        for _ in pairs(value) do
            count = count + 1
        end
    end
    return count
end

local function get_local_cover(plugin, book)
    if plugin and plugin.getShelfCoverCache then
        local ok, cache = pcall(plugin.getShelfCoverCache, plugin)
        if ok and cache and cache.pathFor then
            local path = cache:pathFor(book)
            if path and U.file_exists(path) then
                return path
            end
        end
    end
end

function Provider:scan(plugin)
    if not (plugin and plugin.settings) then
        return {}
    end

    local stored_books = plugin.settings:get("books", {}) or {}
    local cache_root = plugin.settings.cache_dir
        or (plugin.settings.data_dir .. "/cache")
    local records = {}

    for raw_id, stored_book in pairs(stored_books) do
        local book_id = tostring(raw_id)
        local directory = stored_book.cache_dir or (cache_root .. "/" .. book_id)
        local metadata = decode_json(directory .. "/metadata.json") or {}
        local catalog = decode_json(directory .. "/catalog.json") or {}
        local chapters = type(catalog.chapters) == "table" and catalog.chapters or {}

        local full_path = metadata.cached_full_book or metadata.cached_file
        if not U.file_exists(full_path) then
            full_path = nil
        end
        local cached_count = full_path and #chapters or count_table(metadata.cached_chapters)
        if cached_count > 0 then
            local title = U.trim(metadata.title or ("微信读书 " .. book_id))
            local author = U.trim(metadata.author or "")
            local cover_url = metadata.cover
            local local_cover = get_local_cover(plugin, {
                book_id = book_id,
                cover = cover_url,
            })
            local book = {
                book_id = book_id,
                bookId = book_id,
                title = title,
                author = author,
                cover = cover_url,
                cached_full_book = full_path,
                cached_file = full_path,
                cached_chapters = metadata.cached_chapters,
            }
            records[#records + 1] = {
                provider_id = self.id,
                book_id = book_id,
                title = title,
                author = author,
                description = metadata.intro or "",
                cached_count = cached_count,
                total_count = #chapters > 0 and #chapters or cached_count,
                cover_url = cover_url,
                cover_path = local_cover,
                book = book,
            }
        end
    end
    return records
end

function Provider:open(plugin, book)
    if not plugin then
        return false, "微信读书插件未启用"
    end
    if type(plugin.openBookForReading) == "function" then
        local ok, err = pcall(plugin.openBookForReading, plugin, book)
        if not ok then
            return false, err
        end
        return true
    end
    if type(plugin.openFile) == "function" and book.cached_full_book then
        local ok, err = pcall(plugin.openFile, plugin, book.cached_full_book)
        if not ok then
            return false, err
        end
        return true
    end
    return false, "微信读书插件没有可用的打开接口"
end

return Provider
