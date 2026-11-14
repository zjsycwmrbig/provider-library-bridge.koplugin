local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local U = {}

function U.trim(value)
    return (tostring(value or ""):match("^%s*(.-)%s*$"))
end

function U.file_exists(path)
    return path and lfs.attributes(path, "mode") == "file"
end

function U.dir_exists(path)
    return path and lfs.attributes(path, "mode") == "directory"
end

function U.ensure_dir(path)
    if U.dir_exists(path) then
        return true
    end
    local ok, err = lfs.mkdir(path)
    return ok or U.dir_exists(path), err
end

function U.read_file(path)
    local handle = io.open(path, "rb")
    if not handle then
        return nil
    end
    local data = handle:read("*a")
    handle:close()
    return data
end

function U.load_lua(path)
    local chunk = loadfile(path)
    if not chunk then
        return nil
    end
    local ok, value = pcall(chunk)
    if ok and type(value) == "table" then
        return value
    end
end

function U.safe_filename(value, fallback)
    value = U.trim(value):gsub("[\\/:*?\"<>|%z\1-\31]", "_")
    value = value:gsub("%s+", " ")
    value = value:gsub("^[%. ]+", ""):gsub("[%. ]+$", "")
    if value == "" then
        value = fallback or "untitled"
    end
    value = util.fixUtf8(value:sub(1, 120), "_")
    return value
end

function U.display_title(provider, title)
    return string.format("[%s] %s", provider.tag, U.trim(title))
end

function U.signature(record)
    return table.concat({
        tostring(record.title or ""),
        tostring(record.author or ""),
        tostring(record.cached_count or 0),
        tostring(record.total_count or 0),
        tostring(record.cover_url or ""),
        tostring(record.provider_id or ""),
    }, "\n")
end

function U.remove_sidecar(path)
    local ok, DocSettings = pcall(require, "docsettings")
    if not ok or not DocSettings then
        return
    end
    local sidecar_dir = DocSettings:getSidecarDir(path)
    if sidecar_dir and DocSettings.removeSidecarDir then
        pcall(DocSettings.removeSidecarDir, sidecar_dir)
    end
end

return U
