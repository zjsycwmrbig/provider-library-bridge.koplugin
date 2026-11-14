local lfs = require("libs/libkoreader-lfs")

local U = require("provider_library.util")

local Provider = {
    id = "fanqie",
    label = "番茄小说",
    tag = "番茄",
    plugin_name = "fanqie",
    priority = 10,
}

local NON_BOOK_DIRS = {
    covers = true,
    store_covers = true,
    comment_images = true,
}

local function count_cached_chapters(directory)
    local count = 0
    local ok, iter, dir_obj = pcall(lfs.dir, directory)
    if not ok or type(iter) ~= "function" then
        return count
    end
    for entry in iter, dir_obj do
        if entry:match("^chapter_.+%.html$") then
            count = count + 1
        end
    end
    return count
end

local function load_shelf(cache_root)
    local shelf = U.load_lua(cache_root .. "/shelf_cache.lua") or {}
    local index = {}
    for _, book in ipairs(shelf) do
        local id = book.book_id or book.bookId
        if id ~= nil then
            index[tostring(id)] = book
        end
    end
    return shelf, index
end

local function first_existing_cover(cache_root, book_id)
    local cover_dir = cache_root .. "/covers"
    for _, extension in ipairs({ "jpg", "jpeg", "png", "webp" }) do
        local path = cover_dir .. "/" .. book_id .. "." .. extension
        if U.file_exists(path) then
            return path
        end
    end
end

local function merge_shelf_book(book, shelf_book)
    if type(shelf_book) ~= "table" then
        return book
    end
    for _, key in ipairs({
        "item_id",
        "latest_read_item_id",
        "last_chapter_item_id",
        "read_timestamp",
        "read_chapters",
        "total_chapters",
        "progress",
        "read_progress",
        "item_show_title",
        "last_chapter_title",
    }) do
        if shelf_book[key] ~= nil then
            book[key] = shelf_book[key]
        end
    end
    return book
end

local function cloud_progress_map(plugin)
    local client = plugin and plugin.client
    if not (client and type(client.fetch_read_progress) == "function") then
        return {}
    end
    local ok, result = pcall(client.fetch_read_progress, client)
    if not ok or type(result) ~= "table" or type(result.data) ~= "table" then
        return {}
    end
    local by_book = {}
    for _, item in ipairs(result.data) do
        local book_id = item.book_id or item.bookId
        if book_id ~= nil then
            by_book[tostring(book_id)] = item
        end
    end
    return by_book
end

local function merge_cloud_progress(plugin, book)
    local progress_map = cloud_progress_map(plugin)
    local book_id = tostring(book.book_id or book.bookId or "")
    local item = progress_map[book_id]
    if item then
        local item_id = item.item_id or item.itemId
        if item_id ~= nil and tostring(item_id) ~= "" then
            book.item_id = tostring(item_id)
            book.latest_read_item_id = tostring(item_id)
        end
        local read_progress = tonumber(item.read_progress)
        if read_progress and read_progress >= 0 and read_progress <= 10000 then
            book.read_progress = read_progress
            book.progress = read_progress / 10000
        end
        if item.read_timestamp ~= nil then
            book.read_timestamp = item.read_timestamp
        end
    end
    return book
end

function Provider:prepare(plugin, book)
    if not (plugin and plugin.settings and type(book) == "table") then
        return book
    end
    local book_id = tostring(book.book_id or book.bookId or "")
    if book_id == "" then
        return book
    end

    local cache_root = plugin.settings:get_download_dir()
    local _, shelf_book_by_id = load_shelf(cache_root)
    local shelf_book = shelf_book_by_id[book_id]
    merge_shelf_book(book, shelf_book)
    merge_cloud_progress(plugin, book)
    return book
end

local function progress_from_shelf(shelf_book)
    local progress = tonumber(shelf_book.progress)
    if not progress and tonumber(shelf_book.read_progress) then
        progress = tonumber(shelf_book.read_progress) / 10000
    end
    if not progress
        and tonumber(shelf_book.read_chapters)
        and tonumber(shelf_book.total_chapters)
        and tonumber(shelf_book.total_chapters) > 0 then
        progress = tonumber(shelf_book.read_chapters)
            / tonumber(shelf_book.total_chapters)
    end
    return progress
end

local function build_record(
    provider, cache_root, book_id, shelf_book, include_uncached, cloud_progress
)
    shelf_book = shelf_book or {}
    local directory = cache_root .. "/" .. tostring(book_id)
    local directory_exists = U.dir_exists(directory)
    local cached_count = directory_exists
        and count_cached_chapters(directory) or 0
    if cached_count == 0 and not include_uncached then
        return
    end

    local meta = {}
    local catalog = {}
    if directory_exists then
        meta = U.load_lua(directory .. "/book_meta.lua") or {}
        catalog = U.load_lua(directory .. "/catalog_cache.lua") or {}
    end
    local total_count = #catalog
    if total_count == 0 then
        total_count = tonumber(shelf_book.total_chapters) or cached_count
    end

    local title = U.trim(
        shelf_book.title
            or shelf_book.book_name
            or meta.title
            or ("番茄小说 " .. tostring(book_id))
    )
    local author = U.trim(
        shelf_book.author
            or shelf_book.author_name
            or meta.author
            or ""
    )
    local cover_url = shelf_book.cover
    local progress
    local progress_source
    local cloud_read_progress = cloud_progress
        and tonumber(cloud_progress.read_progress)
    if cloud_read_progress
        and cloud_read_progress >= 0 and cloud_read_progress <= 10000 then
        progress = cloud_read_progress / 10000
        progress_source = "cloud"
    else
        progress = progress_from_shelf(shelf_book)
        progress_source = "shelf"
    end
    local cloud_item_id = cloud_progress
        and (cloud_progress.item_id or cloud_progress.itemId)
    if cloud_item_id ~= nil and tostring(cloud_item_id) ~= "" then
        cloud_item_id = tostring(cloud_item_id)
    end
    local cloud_read_timestamp = cloud_progress
        and tonumber(cloud_progress.read_timestamp)
    local book = {
        book_id = tostring(book_id),
        title = title,
        author = author,
        item_id = cloud_item_id or shelf_book.item_id,
        latest_read_item_id = cloud_item_id
            or shelf_book.latest_read_item_id,
        last_chapter_item_id = shelf_book.last_chapter_item_id,
        total_chapters = tonumber(shelf_book.total_chapters) or total_count,
        progress = progress,
        cover = cover_url,
        cache_dir = directory,
        cached_count = cached_count,
        book_type = tonumber(shelf_book.book_type),
    }
    return {
        provider_id = provider.id,
        book_id = tostring(book_id),
        title = title,
        author = author,
        description = shelf_book.abstract
            or shelf_book.desc
            or shelf_book.description
            or "",
        cached_count = cached_count,
        total_count = total_count,
        progress_percent = U.progress_percent(progress),
        progress_source = progress_source,
        last_read_title = U.trim(
            shelf_book.item_show_title
                or shelf_book.last_chapter_title
                or ""
        ),
        read_timestamp = cloud_read_timestamp
            or tonumber(shelf_book.read_timestamp),
        cache_path = directory_exists and directory or nil,
        cache_bytes = directory_exists and U.directory_size(directory) or 0,
        cover_url = cover_url,
        cover_path = first_existing_cover(cache_root, book_id),
        book = book,
    }
end

function Provider:scan(plugin, options)
    if not (plugin and plugin.settings and plugin.settings.get_download_dir) then
        return {}
    end

    options = options or {}
    local include_uncached = options.scope ~= "cached_only"
    local cache_root = plugin.settings:get_download_dir()
    local shelf, shelf_by_id = load_shelf(cache_root)
    local cloud_progress = options.allow_network
        and cloud_progress_map(plugin) or {}
    local records = {}
    local seen = {}
    local function append(book_id, shelf_book)
        book_id = tostring(book_id)
        if seen[book_id] then
            return
        end
        local record = build_record(
            self, cache_root, book_id, shelf_book, include_uncached,
            cloud_progress[book_id]
        )
        if record then
            seen[book_id] = true
            records[#records + 1] = record
        end
    end

    if include_uncached then
        for _, shelf_book in ipairs(shelf) do
            local book_id = shelf_book.book_id or shelf_book.bookId
            if book_id ~= nil then
                append(book_id, shelf_book)
            end
        end
    end

    local ok, iter, dir_obj = pcall(lfs.dir, cache_root)
    if not ok or type(iter) ~= "function" then
        return records
    end
    for entry in iter, dir_obj do
        if entry ~= "." and entry ~= ".." and not NON_BOOK_DIRS[entry] then
            local directory = cache_root .. "/" .. entry
            if U.dir_exists(directory) then
                local cached_count = count_cached_chapters(directory)
                if cached_count > 0 then
                    append(entry, shelf_by_id[entry])
                end
            end
        end
    end
    return records
end

function Provider:open(plugin, book)
    if not plugin or type(plugin.openBook) ~= "function" then
        return false, "番茄小说插件未启用或接口不可用"
    end
    local ok, err = pcall(plugin.openBook, plugin, book)
    if not ok then
        return false, err
    end
    return true
end

return Provider
