-- Run from the KOReader directory: ./luajit - < this-file
-- BRIDGE_PLUGIN_PATH selects a staged or installed copy. No screen/UI is opened.
require("setupkoenv")
G_reader_settings = require("luasettings"):open("settings.reader.lua")
local plugin = assert(os.getenv("BRIDGE_PLUGIN_PATH"))
local output = assert(os.getenv("BRIDGE_TEST_OUTPUT"))
package.path = plugin .. "/?.lua;" .. package.path
package.loaded.device = { hasColorScreen = function() return false end }
local cre = require("libs/libkoreader-cre")
package.loaded["document/credocument"] = {
    engineInit = function() return cre end,
}
local GenericCover = require("provider_library.generic_cover")
local generated = {}
for id = 1, 3 do
    local path, err, variant = GenericCover.generate(plugin,
        { data_dir = output }, { id = "fanqie" }, {
            book_id = tostring(id),
            title = ({ "《长夜将尽》", "★江上月明★", "山海之间：归途" })[id],
            author = "霞鹜文楷 示例作者",
        })
    assert(path, err)
    generated[variant] = true
    local image = assert(require("ui/renderimage"):renderImageFile(path))
    assert(image:getWidth() == 600 and image:getHeight() == 800)
    image:free()
    print("COVER_OK", variant, path)
end
assert(generated.eclipse and generated.current and generated.lattice)
print("DEVICE_COVERS_OK")
