local util = require("util")

local U = require("provider_library.util")

local GenericCover = {}
local registered_fonts = {}

local STYLES = {
    { id = "eclipse", file = "02-eclipse.svg", top = 774 },
    { id = "current", file = "03-current.svg", top = 786 },
    { id = "lattice", file = "05-lattice.svg", top = 830 },
}

local function xml_escape(value)
    local escaped = tostring(value or "")
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
        :gsub("'", "&apos;")
    return escaped
end

local function split_chars(value)
    return util.splitToChars(value)
end

local function wrap_title(value)
    local chars = split_chars(U.clean_title(value))
    local max_chars = 7
    local max_total = 21
    local lines = {}
    for start = 1, math.min(#chars, max_total), max_chars do
        local line = table.concat(chars, "", start, math.min(start + max_chars - 1, #chars))
        lines[#lines + 1] = line
    end
    return lines
end

local function title_markup(title, top)
    local lines = wrap_title(title)
    local total = 0
    for _, line in ipairs(lines) do
        total = total + #split_chars(line)
    end
    local font_size = total <= 7 and 84 or (total <= 14 and 74 or 64)
    local line_height = math.floor(font_size * 1.15)
    local first_line = top - math.floor((#lines - 1) * line_height / 2)
    local markup = {}
    for index, line in ipairs(lines) do
        markup[#markup + 1] = string.format(
            '<text x="450" y="%d" text-anchor="middle" '
                .. 'font-family="\'LXGW WenKai Lite\',\'LXGW WenKai\',\'KaiTi\',serif" '
                .. 'font-size="%d" font-weight="600" fill="#f5f2e9">%s</text>',
            first_line + (index - 1) * line_height,
            font_size,
            xml_escape(line)
        )
    end
    return table.concat(markup, "\n  ")
end

local function style_for(provider_id, book_id)
    local key = tostring(provider_id or "") .. "\n" .. tostring(book_id or "")
    local hash = 0
    for index = 1, #key do
        hash = (hash * 33 + key:byte(index)) % 104729
    end
    return STYLES[hash % #STYLES + 1]
end

function GenericCover.generate(plugin_path, settings, provider, record)
    local style = style_for(provider.id, record.book_id)
    local template_path = string.format(
        "%s/assets/generic-covers/%s", plugin_path, style.file
    )
    local template = U.read_file(template_path)
    if not template then
        return nil, "通用封面模板不存在"
    end

    local title = U.clean_title(record.title)
    local author = U.clean_title(record.author)
    if author == "无题" then
        author = "佚名"
    end
    local svg = template:gsub(
        "{{TITLE_MARKUP}}", title_markup(title, style.top)
    )
    svg = svg:gsub("{{TITLE}}", xml_escape(title))
    svg = svg:gsub("{{AUTHOR}}", xml_escape(author))

    local directory = settings.data_dir .. "/generic-covers"
    U.ensure_dir(settings.data_dir)
    U.ensure_dir(directory)
    local path = directory .. "/"
        .. U.safe_filename(provider.id .. "-" .. tostring(record.book_id), "cover")
        .. ".svg"
    local ok = util.writeToFile(svg, path, true, false)
    if not ok then
        return nil, "写入通用封面失败"
    end
    -- NanoSVG (used by ImageWidget for SVG files) does not render text.
    -- Render once with CRE/LunaSVG, then cache a portable PNG for every UI.
    local rendered, png_or_error = pcall(function()
        local cre = require("document/credocument"):engineInit()
        local font = plugin_path .. "/assets/fonts/LXGWWenKaiLite-Regular.ttf"
        if not registered_fonts[font] then
            assert(cre.registerFont(font) ~= false, "注册封面楷体失败")
            registered_fonts[font] = true
        end
        local renderer = require("ui/renderimage")
        local image = assert(renderer:renderImageFile(
            path, false, 600, 800
        ), "渲染通用封面失败")
        if image:getWidth() ~= 600 or image:getHeight() ~= 800 then
            local scaled = assert(renderer:scaleBlitBuffer(image, 600, 800),
                "缩放通用封面失败")
            if scaled ~= image then image:free() end
            image = scaled
        end
        local png = path:gsub("%.svg$", ".png")
        local wrote, write_error = image:writeToFile(png, "png")
        image:free()
        assert(wrote, write_error or "写入封面 PNG 失败")
        return png
    end)
    if not rendered then
        return nil, tostring(png_or_error)
    end
    return png_or_error, nil, style.id
end

return GenericCover
