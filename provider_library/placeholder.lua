local DocSettings = require("docsettings")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local ltn12 = require("ltn12")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")

local GenericCover = require("provider_library.generic_cover")
local U = require("provider_library.util")

local Placeholder = {}

local function image_extension(data)
    if type(data) ~= "string" then
        return nil
    end
    if data:sub(1, 3) == "\255\216\255" then return "jpg" end
    if data:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
    if data:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WEBP" then return "webp" end
    if data:sub(1, 6) == "GIF87a" or data:sub(1, 6) == "GIF89a" then return "gif" end
end

local function download(url)
    if type(url) ~= "string" or url == "" then
        return nil
    end
    local client
    if url:match("^https://") then
        local ok, https = pcall(require, "ssl.https")
        if not ok then return nil end
        client = https
    elseif url:match("^http://") then
        local ok, http = pcall(require, "socket.http")
        if not ok then return nil end
        client = http
    else
        return nil
    end

    local chunks = {}
    local ok, code = client.request{
        url = url,
        sink = ltn12.sink.table(chunks),
        headers = {
            ["User-Agent"] = "KOReader Provider Library Bridge/0.1",
        },
    }
    if not ok or tonumber(code) ~= 200 then
        return nil
    end
    local data = table.concat(chunks)
    if #data < 16 then
        return nil
    end
    return data
end

local function cover_cache_path(settings, provider_id, book_id, extension)
    local directory = settings.data_dir .. "/covers"
    U.ensure_dir(settings.data_dir)
    U.ensure_dir(directory)
    return directory .. "/" .. U.safe_filename(
        provider_id .. "-" .. book_id, "cover"
    ) .. "." .. extension
end

local function is_image_file(path)
    local handle = path and io.open(path, "rb")
    if not handle then
        return false
    end
    local data = handle:read(16)
    handle:close()
    return image_extension(data) ~= nil
end

local function ensure_cover(settings, provider_record, allow_network)
    if provider_record.cover_path and is_image_file(provider_record.cover_path) then
        return provider_record.cover_path
    end
    for _, extension in ipairs({ "jpg", "png", "webp", "gif" }) do
        local cached = cover_cache_path(settings, provider_record.provider_id,
            provider_record.book_id, extension)
        if is_image_file(cached) then
            return cached
        end
    end
    if not allow_network then
        return nil
    end

    local data = download(provider_record.cover_url)
    local extension = image_extension(data)
    if not extension then
        return nil
    end
    local path = cover_cache_path(
        settings,
        provider_record.provider_id,
        provider_record.book_id,
        extension
    )
    local ok = util.writeToFile(data, path, true, false)
    if ok then
        return path
    end
end

local function placeholder_html(provider, record)
    local display_title = U.display_title(provider, record.title)
    local author = U.clean_title(record.author)
    if author == "无题" then
        author = "佚名"
    end
    local chapter_progress = string.format(
        "%d / %d",
        record.cached_count or 0,
        record.total_count or record.cached_count or 0
    )
    local percent = U.progress_percent(record.progress_percent)
    local progress_label = percent and string.format("%.1f%%", percent) or "暂无数据"
    local progress_width = percent and string.format("%.1f%%", percent) or "0%"
    local last_read = record.last_read_title
    if not last_read or last_read == "" then
        last_read = "尚未记录"
    end
    local last_opened = U.format_time(record.last_opened_at, "尚未打开")
    local last_sync = U.format_time(record.last_sync, "尚未同步")
    local cache_size = U.format_bytes(record.cache_bytes)
    local escaped_title = U.html_escape(display_title)
    local escaped_author = U.html_escape(author)
    local escaped_provider = U.html_escape(provider.label)
    return table.concat({
        "<!DOCTYPE html>",
        '<html lang="zh-CN"><head><meta charset="utf-8"/>',
        '<meta name="provider-library-placeholder" content="1"/>',
        '<meta name="viewport" content="width=device-width, initial-scale=1"/>',
        "<title>", escaped_title, "</title>",
        "<style>",
        "html,body{margin:0;padding:0;}",
        "body{font-family:serif;color:#151515;padding:7% 7% 10%;line-height:1.55;}",
        ".source{display:inline-block;border:1px solid #333;padding:.15em .55em;"
            .. "font-size:.78em;margin-bottom:1.1em;}",
        "h1{font-size:1.55em;line-height:1.35;margin:.2em 0 .35em;text-align:center;}",
        ".author{text-align:center;color:#555;margin:0 0 1.8em;}",
        ".card{border:1px solid #777;margin:1em 0;padding:.8em 1em;}",
        ".card h2{font-size:.83em;letter-spacing:.08em;margin:0 0 .7em;color:#555;}",
        ".progress{font-size:1.45em;margin:.05em 0 .35em;}",
        ".track{height:.55em;border:1px solid #777;margin:.45em 0 .7em;}",
        ".fill{height:100%;background:#555;}",
        ".field{margin:.42em 0;}",
        ".label{color:#666;}",
        ".value{font-weight:bold;}",
        ".note{border-left:3px solid #777;padding-left:.8em;color:#555;"
            .. "font-size:.9em;margin-top:1.6em;}",
        "</style></head><body>",
        '<div class="source">', escaped_provider, " · 在线占位书</div>",
        "<h1>", escaped_title, "</h1>",
        '<p class="author">', escaped_author, "</p>",
        '<div class="card">',
        "<h2>阅读进度</h2>",
        '<div class="progress">', progress_label, "</div>",
        '<div class="track"><div class="fill" style="width:', progress_width, ';"></div></div>',
        '<div class="field"><span class="label">上次读到：</span>',
        '<span class="value">', U.html_escape(last_read), "</span></div>",
        '<div class="field"><span class="label">上次打开：</span>',
        '<span class="value">', last_opened, "</span></div>",
        "</div>",
        '<div class="card">',
        "<h2>缓存状态</h2>",
        '<div class="field"><span class="label">已缓存章节：</span>',
        '<span class="value">', chapter_progress, "</span></div>",
        '<div class="field"><span class="label">本地占用：</span>',
        '<span class="value">', cache_size, "</span></div>",
        '<div class="field"><span class="label">最近同步：</span>',
        '<span class="value">', last_sync, "</span></div>",
        "</div>",
        '<p class="note">正在打开 ', escaped_provider,
        " 阅读界面。若来源插件不可用，此页会保留并显示错误提示。</p>",
        "</body></html>",
    })
end

local function marker_for(provider, record, existing_marker)
    return {
        version = 1,
        marker_schema = 2,
        provider_id = provider.id,
        provider_label = provider.label,
        tag = provider.tag,
        book_id = record.book_id,
        title = record.title,
        author = record.author,
        cached_count = record.cached_count,
        total_count = record.total_count,
        progress_percent = U.progress_percent(record.progress_percent),
        last_read_title = record.last_read_title,
        read_timestamp = record.read_timestamp,
        cache_bytes = record.cache_bytes,
        last_sync = record.last_sync,
        last_opened_at = existing_marker and existing_marker.last_opened_at,
        book = record.book,
    }
end

local function sidecar_marker(path)
    local doc_settings = DocSettings:open(path)
    return doc_settings:readSetting("provider_library_placeholder")
end

function Placeholder.is_owned(path, provider_id, book_id)
    if not U.file_exists(path) then
        return false
    end
    local marker = sidecar_marker(path)
    return type(marker) == "table"
        and marker.provider_id == provider_id
        and tostring(marker.book_id) == tostring(book_id)
end

function Placeholder.remove(path)
    if U.file_exists(path) then
        os.remove(path)
    end
    U.remove_sidecar(path)
end

local function remove_custom_covers(path)
    for _ = 1, 8 do
        local cover = DocSettings:findCustomCoverFile(path)
        if not cover then
            break
        end
        os.remove(cover)
    end
end

function Placeholder.upsert(provider, record, settings, allow_network, plugin_path)
    local provider_dir = settings:get("target_root", "/mnt/us/Books")
    U.ensure_dir(provider_dir)

    local safe_id = U.safe_filename(record.book_id, "book")
    local display_title = U.display_title(provider, record.title)
    local filename = U.safe_filename(display_title, "untitled")
        .. " [" .. safe_id .. "].html"
    local path = provider_dir .. "/" .. filename
    local existing = settings:get_placeholder(provider.id, record.book_id)
    if existing and existing.path and existing.path ~= path
        and Placeholder.is_owned(existing.path, provider.id, record.book_id) then
        Placeholder.remove(existing.path)
    end
    if U.file_exists(path)
        and not Placeholder.is_owned(path, provider.id, record.book_id) then
        return nil, "目标路径已有其他文件"
    end

    local signature = U.signature({
        provider_id = provider.id,
        title = record.title,
        author = record.author,
        cached_count = record.cached_count,
        total_count = record.total_count,
        progress_percent = record.progress_percent,
        last_read_title = record.last_read_title,
        read_timestamp = record.read_timestamp,
        cache_bytes = record.cache_bytes,
        cover_url = record.cover_url,
    })
    local existing_cover = DocSettings:findCustomCoverFile(path)
    local has_cover_source = record.cover_path or record.cover_url
    local existing_marker = sidecar_marker(path)
    signature = signature .. "\n" .. tostring(
        existing_marker and existing_marker.last_opened_at or 0
    )
    record.last_opened_at = existing_marker and existing_marker.last_opened_at
    record.last_sync = os.time()
    local cover_is_ready = existing_cover ~= nil
        and not existing_cover:match("%.svg$")
    local retry_official_cover = allow_network
        and has_cover_source
        and existing_marker
        and existing_marker.cover_kind == "generic"
    if existing and existing.path == path and existing.signature == signature
        and Placeholder.is_owned(path, provider.id, record.book_id)
        and existing_marker and existing_marker.marker_schema == 2
        and cover_is_ready and not retry_official_cover then
        return "unchanged"
    end

    local created = not U.file_exists(path)
    local wrote = util.writeToFile(
        placeholder_html(provider, record), path, true, false
    )
    if not wrote then
        return nil, "写入占位书失败"
    end

    local official_cover = ensure_cover(settings, record, allow_network)
    if not official_cover and existing_marker
        and existing_marker.cover_kind == "official"
        and is_image_file(existing_cover) then
        official_cover = existing_cover
    end
    local cover_path = official_cover
    local cover_kind = official_cover and "official" or nil
    local cover_variant
    if not cover_path then
        local generated, err
        generated, err, cover_variant = GenericCover.generate(
            plugin_path, settings, provider, record
        )
        if generated then
            cover_path = generated
            cover_kind = "generic"
        elseif err then
            logger.warn(
                "provider-library-bridge: generic cover failed",
                provider.id, tostring(record.book_id), tostring(err)
            )
        end
    end

    local marker = marker_for(provider, record, existing_marker)
    marker.cover_kind = cover_kind
    marker.cover_variant = cover_variant

    local doc_settings = DocSettings:open(path)
    doc_settings:saveSetting("doc_props", {
        title = display_title,
        authors = record.author or "",
        series = provider.label,
        keywords = provider.label .. "\n在线书库占位书",
        description = record.description or "",
    })
    doc_settings:saveSetting(
        "provider_library_placeholder", marker
    )
    doc_settings:saveSetting("summary", {
        status = "reading",
        modified = os.date("%Y-%m-%d"),
    })
    doc_settings:flush()

    if cover_path and U.file_exists(cover_path) then
        -- Never delete an official cover when it is also our copy source.
        local ok, result
        if cover_path == existing_cover then
            ok, result = true, true
        else
            remove_custom_covers(path)
            ok, result = pcall(
                DocSettings.flushCustomCover, DocSettings, path, cover_path
            )
        end
        if not ok or not result then
            logger.warn(
                "provider-library-bridge: custom cover failed",
                provider.id, tostring(record.book_id), tostring(result)
            )
        end
    elseif has_cover_source then
        logger.warn(
            "provider-library-bridge: cover unavailable",
            provider.id, tostring(record.book_id),
            tostring(record.cover_path or record.cover_url)
        )
    end

    settings:set_placeholder(provider.id, record.book_id, {
        path = path,
        signature = signature,
        title = record.title,
        updated_at = os.time(),
    })

    UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", path))
    return created and "created" or "updated"
end

return Placeholder
