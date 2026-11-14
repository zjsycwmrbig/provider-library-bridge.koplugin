local FileChooser = require("ui/widget/filechooser")
local DocSettings = require("docsettings")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")

local History = require("provider_library.history")

local UIPatch = {}

local function mosaic_item_class()
    local ok_mm, MosaicMenu = pcall(require, "mosaicmenu")
    if not ok_mm or not MosaicMenu then
        return
    end
    local ok_up, userpatch = pcall(require, "userpatch")
    if not ok_up or not userpatch or type(userpatch.getUpValue) ~= "function" then
        return
    end
    local builder = MosaicMenu._simpleui_native_build
        or MosaicMenu._updateItemsBuildUI
    return userpatch.getUpValue(builder, "MosaicMenuItem")
end

local function item_path(item)
    return item.filepath
        or (item.entry and (item.entry.path or item.entry.file))
end

local function item_tag(item)
    if item._provider_library_tag_checked then
        return item._provider_library_tag
    end
    item._provider_library_tag_checked = true
    local path = item_path(item)
    if type(path) ~= "string" or path:sub(-5):lower() ~= ".html"
        or not DocSettings:hasSidecarFile(path) then
        return
    end
    local marker = DocSettings:open(path):readSetting("provider_library_placeholder")
    if type(marker) == "table" and type(marker.tag) == "string"
        and marker.tag ~= "" then
        item._provider_library_tag = marker.tag
        return marker.tag
    end
end

local function cover_dimen(item)
    local cover = item._cover_frame or (item[1] and item[1][1] and item[1][1][1])
    if cover and cover.dimen and cover.dimen.w and cover.dimen.h then
        return cover.dimen
    end
end

local function paint_tag_badge(item, bb, cell_x, cell_y)
    local tag = item_tag(item)
    local dimen = tag and cover_dimen(item)
    if not (tag and dimen and dimen.w > 80 and dimen.h > 80) then
        return
    end

    local screen = Device.screen
    local font_size = math.max(9, math.min(15, math.floor(dimen.w * 0.075)))
    local pad_x = screen:scaleBySize(5)
    local pad_y = screen:scaleBySize(3)
    local text_widget = TextWidget:new{
        text = tag,
        face = Font:getFace("cfont", font_size),
        padding = 0,
        fgcolor = Blitbuffer.COLOR_BLACK,
        bgcolor = Blitbuffer.COLOR_WHITE,
    }
    local text_size = text_widget:getSize()
    local badge_w = text_size.w + pad_x * 2
    local badge_h = text_size.h + pad_y * 2
    local cover_x = dimen.x
    local cover_y = dimen.y
    if not cover_x or cover_x == 0 then
        cover_x = cell_x + math.floor(((item.width or dimen.w) - dimen.w) / 2)
    end
    if not cover_y or cover_y == 0 then
        cover_y = cell_y + math.floor(((item.height or dimen.h) - dimen.h) / 2)
    end
    local badge_x = math.floor(cover_x + screen:scaleBySize(7))
    local badge_y = math.floor(cover_y + screen:scaleBySize(7))
    bb:paintRect(
        badge_x, badge_y, badge_w, badge_h, Blitbuffer.COLOR_WHITE
    )
    bb:paintBorder(badge_x, badge_y, badge_w, badge_h, 1)
    text_widget:paintTo(bb, badge_x + pad_x, badge_y + pad_y)
    text_widget:free()
end

function UIPatch.installMosaicBadge()
    local MosaicMenuItem = mosaic_item_class()
    if not MosaicMenuItem then
        return false
    end
    if MosaicMenuItem._provider_library_badge_patched then
        return true
    end
    MosaicMenuItem._provider_library_badge_patched = true
    local original_paint = MosaicMenuItem.paintTo
    MosaicMenuItem.paintTo = function(item, bb, x, y)
        original_paint(item, bb, x, y)
        if not item.is_directory and not item.file_deleted then
            paint_tag_badge(item, bb, x, y)
        end
    end
    return true
end

function UIPatch.install(plugin_name)
    History.install()
    if FileChooser._provider_library_bridge_original_mandatory then
        return
    end
    FileChooser._provider_library_bridge_original_mandatory =
        FileChooser.getMenuItemMandatory

    FileChooser.getMenuItemMandatory = function(chooser, item, collate)
        local original = FileChooser._provider_library_bridge_original_mandatory
        local text = original(chooser, item, collate)
        local ui = chooser and chooser.ui
        if not (ui and item and type(item.path) == "string") then
            return text
        end

        if item.path:sub(-5):lower() ~= ".html"
            or not DocSettings:hasSidecarFile(item.path) then
            return text
        end

        local marker = DocSettings:open(item.path):readSetting(
            "provider_library_placeholder"
        )
        if type(marker) == "table" and marker.tag and marker.tag ~= "" then
            return marker.tag .. " · " .. tostring(text or "")
        end
        return text
    end

    local function schedule_badge_install(attempt)
        UIManager:nextTick(function()
            local installed = UIPatch.installMosaicBadge()
            if not installed and attempt < 8 then
                UIManager:scheduleIn(2, function()
                    schedule_badge_install(attempt + 1)
                end)
            end
        end)
    end
    schedule_badge_install(0)
end

return UIPatch
