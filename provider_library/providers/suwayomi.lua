local DataStorage = require("datastorage")

local U = require("provider_library.util")

local Provider = {
    id = "suwayomi",
    label = "Suwayomi",
    tag = "Suwayomi",
    plugin_name = "suwayomi",
    priority = 30,
}

local function copy_scalar_fields(target, source)
    for key, value in pairs(source or {}) do
        if type(value) ~= "table" then
            target[key] = value
        end
    end
    return target
end

local function merge_manga(target, source)
    if type(source) ~= "table" then
        return target
    end
    for key, value in pairs(source) do
        if value ~= nil then
            target[key] = value
        end
    end
    return target
end

local function chapter_identity(chapter)
    if type(chapter) ~= "table" then
        return nil
    end
    local chapter_id = chapter.id or chapter.chapter_id
    local name = chapter.name or chapter.chapter_name
    if (chapter_id == nil or tostring(chapter_id) == "")
        and (name == nil or tostring(name) == "")
    then
        return nil
    end
    return chapter_id, name
end

local function chapter_before(left, right, left_id, right_id)
    local left_order = tonumber(left and left.source_order)
        or tonumber(left and left.chapter_number)
        or math.huge
    local right_order = tonumber(right and right.source_order)
        or tonumber(right and right.chapter_number)
        or math.huge
    if left_order ~= right_order then
        return left_order < right_order
    end
    local left_number, right_number = tonumber(left_id), tonumber(right_id)
    if left_number and right_number and left_number ~= right_number then
        return left_number < right_number
    end
    return tostring(left_id) < tostring(right_id)
end

local function first_unread_chapter(manga, chapters)
    manga = type(manga) == "table" and manga or {}
    local explicit = manga.first_unread_chapter
    local explicit_id, explicit_name = chapter_identity(explicit)
    local has_read_state = false
    local selected, selected_id, selected_name
    if type(chapters) == "table" then
        for _, chapter in ipairs(chapters) do
            if type(chapter.is_read) == "boolean" then has_read_state = true end
            local chapter_id, chapter_name = chapter_identity(chapter)
            if chapter_id ~= nil or chapter_name ~= nil then
                if chapter.is_read ~= true
                    and (not selected
                        or chapter_before(chapter, selected, chapter_id, selected_id))
                then
                    selected, selected_id, selected_name = chapter, chapter_id, chapter_name
                end
            end
        end
    end
    if has_read_state then
        return selected, selected_id, selected_name
    end
    if explicit_id ~= nil or explicit_name ~= nil then
        return explicit, explicit_id, explicit_name
    end
    return nil
end

local function load_settings()
    local path = DataStorage:getSettingsDir() .. "/suwayomi.lua"
    return U.load_lua(path) or {}
end

local function image_extension(path)
    if type(path) ~= "string" then
        return nil
    end
    return path:lower():match("%.([%w]+)$")
end

local function image_type_extension(content_type, body)
    content_type = tostring(content_type or ""):lower()
    if content_type:match("image/png") then return "png" end
    if content_type:match("image/webp") then return "webp" end
    if content_type:match("image/gif") then return "gif" end
    if content_type:match("image/jpe?g") then return "jpg" end
    if type(body) == "string" then
        if body:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
        if body:sub(1, 3) == "\255\216\255" then return "jpg" end
        if body:sub(1, 4) == "RIFF" and body:sub(9, 12) == "WEBP" then
            return "webp"
        end
        if body:sub(1, 6) == "GIF87a" or body:sub(1, 6) == "GIF89a" then
            return "gif"
        end
    end
end

local function local_cover(plugin, manga, options)
    if type(manga.thumbnail_url) ~= "string" or manga.thumbnail_url == "" then
        return nil
    end
    local ok_cache, ThumbnailCache = pcall(
        require, "suwayomi/ui/thumbnail_cache"
    )
    local ok_settings, SuwayomiSettings = pcall(
        require, "suwayomi/settings"
    )
    if not (ok_cache and ThumbnailCache and ok_settings and SuwayomiSettings) then
        return nil
    end
    local ok_credentials, credentials = pcall(
        function()
            return SuwayomiSettings:load()
        end
    )
    if not ok_credentials or type(credentials) ~= "table" then
        return nil
    end

    local ok_find, cached
    for _, thumbnail_options in ipairs({
        { variant = "poster", width = 320, height = 480 },
        { variant = "manga_cover", width = 64, height = 96 },
    }) do
        ok_find, cached = pcall(
            ThumbnailCache.find,
            credentials,
            manga.thumbnail_url,
            thumbnail_options
        )
        if ok_find and U.file_exists(cached) then
            break
        end
        cached = nil
    end
    local data_dir = options
        and options.settings
        and options.settings.data_dir
    if ok_find and U.file_exists(cached)
        and image_extension(cached) ~= "bb" then
        return cached
    end

    if options and options.allow_network then
        local ok_api, SuwayomiAPI = pcall(require, "suwayomi/api")
        if ok_api and SuwayomiAPI then
            local ok_download, result = pcall(
                SuwayomiAPI.downloadBinary, credentials, manga.thumbnail_url, {
                    max_bytes = 2 * 1024 * 1024,
                    total_timeout_seconds = 15,
                }
            )
            if ok_download and result and result.ok and result.body then
                local extension = image_type_extension(
                    result.content_type, result.body
                )
                if extension and data_dir then
                    local output_dir = data_dir .. "/suwayomi-covers"
                    U.ensure_dir(data_dir)
                    U.ensure_dir(output_dir)
                    local output = output_dir .. "/" .. U.safe_filename(
                        tostring(manga.id), "manga"
                    ) .. "." .. extension
                    local util = require("util")
                    local wrote = util.writeToFile(
                        result.body, output, true, false
                    )
                    if wrote then
                        return output
                    end
                end
            end
        end
    end

    if not ok_find or not U.file_exists(cached) then
        return nil
    end
    if not data_dir then
        return nil
    end
    local output_dir = data_dir .. "/suwayomi-covers"
    U.ensure_dir(data_dir)
    U.ensure_dir(output_dir)
    local output = output_dir .. "/" .. U.safe_filename(
        tostring(manga.id), "manga"
    ) .. ".png"
    if U.file_exists(output) then
        return output
    end

    local ok_decode, bitmap = pcall(ThumbnailCache.loadDecoded, cached)
    if not ok_decode or not bitmap then
        return nil
    end
    local ok_write, written = pcall(bitmap.writeToFile, bitmap, output, "png")
    pcall(bitmap.free, bitmap)
    if ok_write and written then
        return output
    end
end

local function collect_downloads(data)
    local downloads = {}
    local function add(entry)
        if type(entry) ~= "table" or entry.manga_id == nil then
            return
        end
        local manga_id = tostring(entry.manga_id)
        local path = entry.path
        if type(path) == "string" and U.file_exists(path) then
            downloads[manga_id] = downloads[manga_id] or {}
            downloads[manga_id][path] = {
                path = path,
                manga_title = entry.manga_title,
                endpoint_scope = entry.endpoint_scope,
                chapter_id = entry.chapter_id,
                chapter_name = entry.chapter_name,
                source_order = tonumber(entry.source_order),
            }
        end
    end
    for _, entry in pairs(data.chapter_ledger or {}) do
        add(entry)
    end
    for _, entry in pairs(data.reader_return_contexts or {}) do
        add(entry)
    end
    return downloads
end

local function parent_directory(path)
    return type(path) == "string" and path:match("^(.*)/[^/]+$") or nil
end

local function latest_download(downloads)
    local latest
    for _, entry in pairs(downloads or {}) do
        if not latest
            or (tonumber(entry.source_order) or -1)
                > (tonumber(latest.source_order) or -1) then
            latest = entry
        end
    end
    return latest
end

local function chapter_progress(chapters, manga)
    local total = type(chapters) == "table" and #chapters or 0
    local unread = tonumber(manga.unread_count)
    if total > 0 and unread then
        local read = math.max(0, math.min(total, total - unread))
        return read, total, read / total
    end
    if total > 0 then
        local read = 0
        for _, chapter in ipairs(chapters) do
            if chapter.is_read == true then
                read = read + 1
            end
        end
        return read, total, read / total
    end
    return 0, 0, nil
end

local function build_record(provider, manga, chapters, downloaded, options)
    local local_paths = {}
    for path in pairs(downloaded or {}) do
        local_paths[#local_paths + 1] = path
    end
    table.sort(local_paths)
    local folder
    for _, path in ipairs(local_paths) do
        folder = parent_directory(path)
        if folder then
            break
        end
    end
    local latest = latest_download(downloaded)
    local _, total_count, ratio = chapter_progress(chapters, manga)
    local focus_chapter, focus_id = first_unread_chapter(manga, chapters)

    local book = copy_scalar_fields({
        id = manga.id,
        endpoint_scope = manga.endpoint_scope,
        in_library = manga.in_library,
    }, manga)
    book.id = manga.id
    book.endpoint_scope = manga.endpoint_scope
    book.cache_dir = folder
    book.first_unread_chapter = focus_chapter

    return {
        provider_id = provider.id,
        book_id = tostring(manga.id),
        title = U.trim(manga.title or ("Suwayomi " .. tostring(manga.id))),
        author = U.trim(manga.author or manga.artist or ""),
        description = manga.description or "",
        cached_count = #local_paths,
        total_count = total_count,
        progress_percent = U.progress_percent(ratio),
        progress_source = "chapters",
        last_read_title = latest and latest.chapter_name or "",
        first_unread_chapter_id = focus_id,
        cache_path = folder,
        cache_bytes = folder and U.directory_size(folder) or 0,
        cover_path = local_cover(provider, manga, options),
        history_sources = folder and { folder } or {},
        book = book,
    }
end

function Provider:scan(plugin, options)
    if not plugin then
        return {}
    end
    options = options or {}
    local data = load_settings()
    local downloads = collect_downloads(data)
    local mangas = {}

    local function ensure(manga)
        if type(manga) ~= "table" or manga.id == nil then
            return
        end
        local manga_id = tostring(manga.id)
        mangas[manga_id] = merge_manga(mangas[manga_id] or {}, manga)
    end

    for _, manga in ipairs(
        (data.library_cache and data.library_cache.manga) or {}
    ) do
        ensure(manga)
    end
    local chapter_cache = data.chapter_cache or {}
    for manga_id, listing in pairs(chapter_cache.mangas or {}) do
        if type(listing) == "table" then
            ensure(merge_manga(
                { id = manga_id, chapters = listing.chapters or {} },
                listing.manga
            ))
        end
    end
    for manga_id, entries in pairs(downloads) do
        for _, entry in pairs(entries) do
            ensure({
                id = manga_id,
                title = entry.manga_title,
                endpoint_scope = entry.endpoint_scope,
            })
            break
        end
    end

    local records = {}
    for manga_id, manga in pairs(mangas) do
        local listing = chapter_cache.mangas
            and chapter_cache.mangas[manga_id]
        local chapters = listing and listing.chapters or {}
        local local_downloads = downloads[manga_id] or {}
        local cached_count = 0
        for _ in pairs(local_downloads) do
            cached_count = cached_count + 1
        end
        if options.scope ~= "cached_only" or cached_count > 0 then
            records[#records + 1] = build_record(
                self, manga, chapters, local_downloads, options
            )
        end
    end
    table.sort(records, function(left, right)
        return left.title < right.title
    end)
    return records
end

function Provider:prepare(_plugin, book)
    if type(book) ~= "table" then
        return book
    end
    local book_id = book.book_id or book.id
    if book_id == nil or tostring(book_id) == "" then
        return book
    end
    local data = load_settings()
    local endpoint_scope = book.endpoint_scope
        or (data.library_cache and data.library_cache.endpoint_scope)
    local cache_matches = not endpoint_scope
        or not (data.library_cache and data.library_cache.endpoint_scope)
        or data.library_cache.endpoint_scope == endpoint_scope
    local latest
    if cache_matches then
        for _, manga in ipairs(
            (data.library_cache and data.library_cache.manga) or {}
        ) do
            if tostring(manga.id) == tostring(book_id)
                and (not endpoint_scope or not manga.endpoint_scope
                    or manga.endpoint_scope == endpoint_scope)
            then
                latest = manga
                break
            end
        end
    end
    local chapter_cache_scope = data.chapter_cache
        and data.chapter_cache.endpoint_scope
    local chapter_cache_matches = not endpoint_scope or not chapter_cache_scope
        or chapter_cache_scope == endpoint_scope
    local listing = cache_matches and chapter_cache_matches
        and data.chapter_cache
        and data.chapter_cache.mangas
        and data.chapter_cache.mangas[tostring(book_id)]
    local chapters = type(listing) == "table" and listing.chapters or nil
    local prepared = merge_manga({}, book)
    merge_manga(prepared, latest)
    if type(listing) == "table" then
        merge_manga(prepared, listing.manga)
    end
    prepared.endpoint_scope = prepared.endpoint_scope or endpoint_scope
    prepared.cache_dir = book.cache_dir or prepared.cache_dir
    local focus = first_unread_chapter(prepared, chapters)
    prepared.first_unread_chapter = focus
    local _, total_count, ratio = chapter_progress(chapters or {}, prepared)
    if total_count > 0 then
        prepared.progress = ratio
    end
    return prepared
end

function Provider:open(plugin, book)
    if not plugin
        or type(plugin.showChaptersForManga) ~= "function" then
        return false, "Suwayomi 插件未启用或章节接口不可用"
    end
    local focus = type(book) == "table" and book.first_unread_chapter or nil
    local focus_id, focus_name = chapter_identity(focus)
    local options
    if focus_id ~= nil or focus_name ~= nil then
        options = {
            return_context = {
                chapter_id = focus_id,
                chapter_name = focus_name,
            },
        }
    end
    local ok, opened = pcall(
        plugin.showChaptersForManga, plugin, book, options
    )
    if not ok then
        return false, opened
    end
    if opened == false then
        return false, "无法打开 Suwayomi 章节列表"
    end
    return true
end

function Provider:display_title(title)
    local value = U.trim(title)
    return value ~= "" and value or "无题"
end

return Provider
