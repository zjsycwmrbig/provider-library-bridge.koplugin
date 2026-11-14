local placeholder = "/mnt/us/Books/示例书 [42].html"
local source_dir = "/mnt/us/koreader/example/cache/42"
local source_file = source_dir .. "/chapter_1.html"
local normal_file = "/mnt/us/Books/普通书.epub"
local values = {}
local flushed = 0
local history_flushed = 0
local added_paths = {}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

G_reader_settings = {
    readSetting = function(_, key, default)
        if values[key] == nil then return copy(default) end
        return copy(values[key])
    end,
    saveSetting = function(_, key, value)
        values[key] = copy(value)
    end,
    flush = function()
        flushed = flushed + 1
    end,
}

package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function(path, field)
            if path == placeholder then
                return field == "mode" and "file" or { mode = "file" }
            end
        end,
    }
end

local function original_add_item(self, path, timestamp)
    added_paths[#added_paths + 1] = path
    local time = tonumber(timestamp) or 1
    for index = #self.hist, 1, -1 do
        if self.hist[index].file == path then
            time = math.max(time, tonumber(self.hist[index].time) or 0)
            table.remove(self.hist, index)
        end
    end
    table.insert(self.hist, 1, { file = path, time = time })
    return true
end

local ReadHistory = {
    hist = {
        { file = source_file, time = 200 },
        { file = source_dir .. "/chapter_2.html", time = 150 },
        { file = placeholder, time = 50 },
        { file = normal_file, time = 80 },
    },
    addItem = original_add_item,
    removeItem = function(self, _, index)
        table.remove(self.hist, index)
    end,
    _flush = function()
        history_flushed = history_flushed + 1
    end,
}

package.preload["readhistory"] = function()
    return ReadHistory
end

package.path = "./?.lua;" .. package.path
local History = require("provider_library.history")

History.register(placeholder, {
    source_dir,
    source_dir .. "/full.html",
})
assert(History.canonical_for(source_file) == placeholder)
assert(History.canonical_for(source_dir .. "/nested/path.html") == placeholder)
assert(History.canonical_for(source_dir .. "-other/chapter.html") == nil)
assert(History.canonical_for(normal_file) == nil)

assert(History.install())
ReadHistory:addItem(source_file, 300)
assert(added_paths[#added_paths] == placeholder)

ReadHistory.hist = {
    { file = source_file, time = 200 },
    { file = source_dir .. "/chapter_2.html", time = 150 },
    { file = placeholder, time = 50 },
    { file = normal_file, time = 80 },
}
History.reconcile()
assert(history_flushed > 0 and flushed > 0)
local placeholders = 0
for _, item in ipairs(ReadHistory.hist) do
    assert(item.file ~= source_file)
    assert(item.file ~= source_dir .. "/chapter_2.html")
    if item.file == placeholder then
        placeholders = placeholders + 1
        assert(item.time == 200)
    end
end
assert(placeholders == 1)

History.unregister(placeholder)
assert(History.canonical_for(source_file) == nil)
History.remove_canonical(placeholder)
for _, item in ipairs(ReadHistory.hist) do
    assert(item.file ~= placeholder)
end

print("history_spec: ok")
