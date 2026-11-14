local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local U = {}

local function utf8_codepoint(character)
    local first = character:byte(1) or 0
    if first < 0x80 then
        return first
    elseif first < 0xE0 then
        local second = character:byte(2) or 0
        return (first - 0xC0) * 0x40 + (second - 0x80)
    elseif first < 0xF0 then
        local second = character:byte(2) or 0
        local third = character:byte(3) or 0
        return (first - 0xE0) * 0x1000
            + (second - 0x80) * 0x40
            + (third - 0x80)
    else
        local second = character:byte(2) or 0
        local third = character:byte(3) or 0
        local fourth = character:byte(4) or 0
        return (first - 0xF0) * 0x40000
            + (second - 0x80) * 0x1000
            + (third - 0x80) * 0x40
            + (fourth - 0x80)
    end
end

local function is_whitespace(codepoint)
    return codepoint == 0x09
        or codepoint == 0x0A
        or codepoint == 0x0D
        or codepoint == 0x20
        or codepoint == 0xA0
        or codepoint == 0x1680
        or (codepoint >= 0x2000 and codepoint <= 0x200A)
        or codepoint == 0x2028
        or codepoint == 0x2029
        or codepoint == 0x202F
        or codepoint == 0x205F
        or codepoint == 0x3000
end

local function is_punctuation_or_symbol(codepoint)
    return codepoint < 0x20
        or (codepoint >= 0x21 and codepoint <= 0x2F)
        or (codepoint >= 0x3A and codepoint <= 0x40)
        or (codepoint >= 0x5B and codepoint <= 0x60)
        or (codepoint >= 0x7B and codepoint <= 0xBF)
        or codepoint == 0xD7
        or codepoint == 0xF7
        or (codepoint >= 0x2000 and codepoint <= 0x206F)
        or (codepoint >= 0x20A0 and codepoint <= 0x20CF)
        or (codepoint >= 0x2100 and codepoint <= 0x214F)
        or (codepoint >= 0x2190 and codepoint <= 0x2BFF)
        or (codepoint >= 0x2E00 and codepoint <= 0x2E7F)
        or (codepoint >= 0x3001 and codepoint <= 0x303F)
        or (codepoint >= 0xFE00 and codepoint <= 0xFE6F)
        or (codepoint >= 0xFF01 and codepoint <= 0xFF0F)
        or (codepoint >= 0xFF1A and codepoint <= 0xFF20)
        or (codepoint >= 0xFF3B and codepoint <= 0xFF40)
        or (codepoint >= 0xFF5B and codepoint <= 0xFF65)
        or (codepoint >= 0x1F000 and codepoint <= 0x1FAFF)
end

function U.trim(value)
    return (tostring(value or ""):match("^%s*(.-)%s*$"))
end

function U.clean_title(value)
    value = U.trim(value)
    if value == "" then
        return "无题"
    end
    local cleaned = {}
    for _, character in ipairs(util.splitToChars(value)) do
        local codepoint = utf8_codepoint(character)
        if is_whitespace(codepoint) then
            cleaned[#cleaned + 1] = " "
        elseif not is_punctuation_or_symbol(codepoint) then
            cleaned[#cleaned + 1] = character
        end
    end
    local title = table.concat(cleaned):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return title ~= "" and title or "无题"
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
    return U.clean_title(title)
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
