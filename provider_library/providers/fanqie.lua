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

local function shelf_index(cache_root)
    local shelf = U.load_lua(cache_root .. "/shelf_cache.lua") or {}
    local index = {}
    for _, book in ipairs(shelf) do
        local id = book.book_id or book.bookId
        if id ~= nil then
            index[tostring(id)] = book
        end
    end
    return index
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

function Provider:scan(plugin)
    if not (plugin and plugin.settings and plugin.settings.get_download_dir) then
        return {}
    end

    local cache_root = plugin.settings:get_download_dir()
    local shelf = shelf_index(cache_root)
    local records = {}
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
                    local shelf_book = shelf[entry] or {}
                    local meta = U.load_lua(directory .. "/book_meta.lua") or {}
                    local catalog = U.load_lua(directory .. "/catalog_cache.lua") or {}
                    local total_count = #catalog
                    if total_count == 0 then
                        total_count = tonumber(shelf_book.total_chapters) or cached_count
                    end

                    local title = U.trim(
                        shelf_book.title or meta.title or ("番茄小说 " .. entry)
                    )
                    local author = U.trim(
                        meta.author or shelf_book.author or ""
                    )
                    local cover_url = shelf_book.cover
                    local book = {
                        book_id = entry,
                        title = title,
                        author = author,
                        item_id = shelf_book.item_id,
                        latest_read_item_id = shelf_book.latest_read_item_id,
                        last_chapter_item_id = shelf_book.last_chapter_item_id,
                        total_chapters = tonumber(shelf_book.total_chapters) or total_count,
                        cover = cover_url,
                    }
                    records[#records + 1] = {
                        provider_id = self.id,
                        book_id = entry,
                        title = title,
                        author = author,
                        description = shelf_book.abstract or shelf_book.desc or "",
                        cached_count = cached_count,
                        total_count = total_count,
                        cover_url = cover_url,
                        cover_path = first_existing_cover(cache_root, entry),
                        book = book,
                    }
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
