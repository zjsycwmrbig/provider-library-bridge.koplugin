local generated_path
local generated_svg
local template = [[
<svg xmlns="http://www.w3.org/2000/svg">
  <title>{{TITLE}}</title>
  {{TITLE_MARKUP}}
  <text>{{AUTHOR}}</text>
</svg>
]]

package.preload["provider_library.util"] = function()
    return {
        clean_title = function(value)
            return tostring(value)
                :gsub("《", " ")
                :gsub("》", " ")
                :gsub("：", " ")
                :gsub("%[", " ")
                :gsub("%]", " ")
                :gsub("%s+", " ")
                :gsub("^%s+", "")
                :gsub("%s+$", "")
        end,
        ensure_dir = function()
            return true
        end,
        read_file = function()
            return template
        end,
        safe_filename = function(value)
            return tostring(value)
        end,
        writeToFile = function(content, path)
            generated_path = path
            generated_svg = content
            return true
        end,
    }
end

package.preload["util"] = function()
    return {
        splitToChars = function(value)
            local chars = {}
            for character in tostring(value):gmatch(
                "[%z\1-\127\194-\244][\128-\191]*"
            ) do
                chars[#chars + 1] = character
            end
            return chars
        end,
        writeToFile = function(content, path)
            generated_path = path
            generated_svg = content
            return true
        end,
    }
end

package.path = "./?.lua;" .. package.path

local GenericCover = require("provider_library.generic_cover")
local provider = {
    id = "fanqie",
    label = "番茄小说",
    tag = "番茄",
}
local record = {
    book_id = "7277393036894538793",
    title = "《长夜将尽》：测试版",
    author = "[示例] 作者",
}
local settings = {
    data_dir = "/tmp/provider-library-test",
}

local path, err, style = GenericCover.generate(
    ".", settings, provider, record
)
assert(path, err)
assert(path == generated_path)
assert(style == "eclipse" or style == "current" or style == "lattice")
assert(generated_svg:match("<svg"))
assert(generated_svg:match("<title>长夜将尽 测试版</title>"))
assert(generated_svg:match("示例 作者"))
assert(not generated_svg:match("{{TITLE"))
assert(not generated_svg:match("{{AUTHOR"))
print("generic_cover_spec: ok")
