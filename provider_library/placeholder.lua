local DocSettings = require("docsettings")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local ltn12 = require("ltn12")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")

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

local function ensure_cover(settings, provider_record, allow_network)
    if provider_record.cover_path and U.file_exists(provider_record.cover_path) then
        return provider_record.cover_path
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
    local ok = util.writeToFile(data, path, true, true)
    if ok then
        return path
    end
end

local function placeholder_html(provider, record)
    local display_title = U.display_title(provider, record.title)
    local progress = string.format(
        "%d / %d", record.cached_count or 0, record.total_count or 0
    )
    return table.concat({
        "<!DOCTYPE html>",
        '<html lang="zh-CN"><head><meta charset="utf-8"/>',
        '<meta name="provider-library-placeholder" content="1"/>',
        "<title>", display_title:gsub("&", "&amp;"):gsub("<", "&lt;"), "</title>",
        "<style>",
        "body{font-family:serif;text-align:center;padding:12% 8%;}",
        "h1{font-size:1.35em;}",
        ".tag{border:1px solid #555;padding:.12em .45em;font-size:.72em;}",
        ".meta{color:#555;line-height:1.7;}",
        "</style></head><body>",
        '<p class="tag">', provider.label, "</p>",
        "<h1>", display_title:gsub("&", "&amp;"):gsub("<", "&lt;"), "</h1>",
        '<p class="meta">', (record.author or ""):gsub("&", "&amp;"):gsub("<", "&lt;"), "</p>",
        '<p class="meta">缓存进度：', progress, "</p>",
        "<p>点击后将自动打开 ", provider.label, " 阅读界面。</p>",
        "</body></html>",
    })
end

local function marker_for(provider, record)
    return {
        version = 1,
        provider_id = provider.id,
        provider_label = provider.label,
        tag = provider.tag,
        book_id = record.book_id,
        title = record.title,
        author = record.author,
        cached_count = record.cached_count,
        total_count = record.total_count,
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

function Placeholder.upsert(provider, record, settings, allow_network)
    local provider_dir = settings:get("target_root", "/mnt/us/Books")
    U.ensure_dir(provider_dir)

    local safe_id = U.safe_filename(record.book_id, "book")
    local filename = U.safe_filename(record.title, "untitled")
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
        cover_url = record.cover_url,
    })
    local existing_cover = DocSettings:findCustomCoverFile(path)
    local has_cover_source = record.cover_path or record.cover_url
    local cover_is_ready = not has_cover_source or existing_cover ~= nil
    if existing and existing.path == path and existing.signature == signature
        and Placeholder.is_owned(path, provider.id, record.book_id)
        and cover_is_ready then
        return "unchanged"
    end

    local created = not U.file_exists(path)
    local wrote = util.writeToFile(
        placeholder_html(provider, record), path, true, true
    )
    if not wrote then
        return nil, "写入占位书失败"
    end

    local display_title = U.display_title(provider, record.title)
    local doc_settings = DocSettings:open(path)
    doc_settings:saveSetting("doc_props", {
        title = display_title,
        authors = record.author or "",
        series = provider.label,
        keywords = provider.label .. "\n在线书库占位书",
        description = record.description or "",
    })
    doc_settings:saveSetting(
        "provider_library_placeholder", marker_for(provider, record)
    )
    doc_settings:saveSetting("summary", {
        status = "reading",
        modified = os.date("%Y-%m-%d"),
    })
    doc_settings:flush()

    local cover = ensure_cover(settings, record, allow_network)
    if cover and U.file_exists(cover) then
        local ok, err = pcall(DocSettings.flushCustomCover, DocSettings, path, cover)
        if not ok then
            logger.warn(
                "provider-library-bridge: custom cover failed",
                provider.id, tostring(record.book_id), tostring(err)
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
