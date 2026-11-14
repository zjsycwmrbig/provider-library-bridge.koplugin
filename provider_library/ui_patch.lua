local FileChooser = require("ui/widget/filechooser")

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
        local bridge = ui and ui[plugin_name]
        if not (bridge and item and type(item.path) == "string") then
            return text
        end

        local filename = item.path:match("([^/]+)$") or ""
        local tag = filename:match("^%[([^%]]+)%]")
        if not tag then
            return text
        end
        for _, provider in ipairs(bridge.providers or {}) do
            if provider.tag == tag then
                return tag .. " · " .. tostring(text or "")
            end
        end
        return text
    end
end

return UIPatch
