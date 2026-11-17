package.preload["libs/libkoreader-lfs"] = function()
    return {}
end

package.preload["util"] = function()
    return {
        fixUtf8 = function(value)
            return value
        end,
        splitToChars = function(value)
            local chars = {}
            for character in tostring(value):gmatch(
                "[%z\1-\127\194-\244][\128-\191]*"
            ) do
                chars[#chars + 1] = character
            end
            return chars
        end,
    }
end

package.path = "./?.lua;" .. package.path

local U = require("provider_library.util")

assert(U.clean_title("三体全集（全三册）") == "三体全集 全三册")
assert(U.clean_title("Re：从零开始的异世界生活") == "Re 从零开始的异世界生活")
assert(U.clean_title("《无人逝去》") == "无人逝去")
assert(U.clean_title("★神通者★") == "神通者")
assert(U.clean_title("   ") == "无题")

assert(U.html_escape([[<书&"名">]]) == "&lt;书&amp;&quot;名&quot;&gt;")
assert(U.progress_percent(0.425) == 42.5)
assert(U.progress_percent(42.5) == 42.5)
assert(U.progress_percent(150) == 100)
assert(U.format_bytes(1536) == "2 KB")
assert(U.display_title({
    display_title = function(_, title) return title end,
}, "Ura Baito: Toubou Kinshi") == "Ura Baito: Toubou Kinshi")

print("util_spec: ok")
