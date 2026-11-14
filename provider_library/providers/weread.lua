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

local function known_shelf(plugin)
    local database = plugin and plugin.library_db
    if not (database and type(database.getShelf) == "function") then
        return nil
    end
    local ok, shelf = pcall(database.getShelf, database)
    if ok and type(shelf) == "table" then
        return shelf
    end
end

local function merge_books(shelf_book, stored_book)
    local book = {}
    for key, value in pairs(shelf_book or {}) do
        book[key] = value
    end
    for key, value in pairs(stored_book or {}) do
        book[key] = value
    end
    return book
end

local function build_record(provider, plugin, cache_root, book_id, shelf_book, stored_book, include_uncached)
    shelf_book = shelf_book or {}
    stored_book = stored_book or {}
    local directory = stored_book.cache_dir or (cache_root .. "/" .. book_id)
    local directory_exists = U.dir_exists(directory)
    local metadata = {}
    local reading_state = {}
    local catalog = {}
    if directory_exists then
        metadata = decode_json(directory .. "/metadata.json") or {}
        reading_state = decode_json(directory .. "/reading_state.json") or {}
        catalog = decode_json(directory .. "/catalog.json") or {}
    end
    local chapters = type(catalog.chapters) == "table" and catalog.chapters or {}

    local full_path = metadata.cached_full_book
        or metadata.cached_file
        or stored_book.cached_full_book
        or stored_book.cached_file
    if not U.file_exists(full_path) then
        full_path = nil
    end
    local cached_chapters = metadata.cached_chapters
        or stored_book.cached_chapters
    local chapter_count = count_table(cached_chapters)
    local cached_count = chapter_count
    if full_path then
        cached_count = math.max(1, #chapters, chapter_count)
    end
    if cached_count == 0 and not include_uncached then
        return
    end

    local title = U.trim(
        shelf_book.title
            or metadata.title
            or stored_book.title
            or ("微信读书 " .. book_id)
    )
    local author = U.trim(
        shelf_book.author
            or metadata.author
            or stored_book.author
            or ""
    )
    local cover_url = shelf_book.cover
        or metadata.cover
        or stored_book.cover
    local progress = tonumber(
        reading_state.progress
            or reading_state.percent
            or reading_state.bookProgress
            or shelf_book.progress
            or stored_book.progress
    )
    if progress and progress > 100 and progress <= 10000 then
        progress = progress / 100
    end
    local total_count = #chapters
    if total_count == 0 then
        total_count = tonumber(shelf_book.totalChapters)
            or tonumber(shelf_book.total_chapters)
            or cached_count
    end
    local book = merge_books(shelf_book, stored_book)
    book.book_id = book_id
    book.bookId = book_id
    book.title = title
    book.author = author
    book.cover = cover_url
    book.cache_dir = directory
    book.cached_count = cached_count
    book.cached_full_book = full_path
    book.cached_file = full_path
    book.cached_chapters = cached_chapters
    local local_cover = get_local_cover(plugin, book)
    return {
        provider_id = provider.id,
        book_id = book_id,
        title = title,
        author = author,
        description = shelf_book.intro
            or metadata.intro
            or stored_book.intro
            or "",
        cached_count = cached_count,
        total_count = total_count,
        progress_percent = U.progress_percent(progress),
        last_read_title = U.trim(
            reading_state.chapterTitle
                or reading_state.chapter_title
                or reading_state.title
                or shelf_book.chapterTitle
                or stored_book.chapterTitle
                or ""
        ),
        read_timestamp = tonumber(
            reading_state.readUpdateTime
                or reading_state.updateTime
                or shelf_book.readUpdateTime
                or stored_book.readUpdateTime
        ),
        cache_path = directory_exists and directory or nil,
        cache_bytes = directory_exists and U.directory_size(directory) or 0,
        cover_url = cover_url,
        cover_path = local_cover,
        book = book,
    }
end

function Provider:scan(plugin, options)
    if not (plugin and plugin.settings) then
        return {}
    end

    options = options or {}
    local include_uncached = options.scope ~= "cached_only"
    local stored_books = plugin.settings:get("books", {}) or {}
    local cache_root = plugin.settings.cache_dir
        or (plugin.settings.data_dir .. "/cache")
    local records = {}
    local seen = {}

    local function append(raw_id, shelf_book)
        local book_id = tostring(raw_id)
        if seen[book_id] then
            return
        end
        local record = build_record(
            self,
            plugin,
            cache_root,
            book_id,
            shelf_book,
            stored_books[raw_id] or stored_books[book_id],
            include_uncached
        )
        if record then
            seen[book_id] = true
            records[#records + 1] = record
        end
    end

    local shelf = known_shelf(plugin)
    local shelf_by_id = {}
    for _, shelf_book in ipairs(shelf or {}) do
        local book_id = shelf_book.book_id or shelf_book.bookId
        if book_id ~= nil then
            shelf_by_id[tostring(book_id)] = shelf_book
        end
    end

    if include_uncached then
        for _, shelf_book in ipairs(shelf or {}) do
            local book_id = shelf_book.book_id or shelf_book.bookId
            if book_id ~= nil then
                append(book_id, shelf_book)
            end
        end
    end

    for raw_id, stored_book in pairs(stored_books) do
        append(raw_id, shelf_by_id[tostring(raw_id)])
    end
    return records
end

function Provider:open(plugin, book)
    if not plugin then
        return false, "微信读书插件未启用"
    end
    local cached_count = tonumber(book and book.cached_count) or 0
    if cached_count == 0 and type(plugin.showBookRecord) == "function" then
        local ok, err = pcall(plugin.showBookRecord, plugin, book)
        if not ok then
            return false, err
        end
        return true
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
