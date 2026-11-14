local FileChooser = require("ui/widget/filechooser")
local DocSettings = require("docsettings")

local UIPatch = {}

function UIPatch.install(plugin_name)
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
end

return UIPatch
