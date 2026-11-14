local BottomContainer = require("ui/widget/container/bottomcontainer")
local Device = require("device")
local Geom = require("ui/geometry")
local InfoMessage = require("ui/widget/infomessage")

local BottomMessage = InfoMessage:extend{}

function BottomMessage:init()
    InfoMessage.init(self)
    local Screen = Device.screen
    self[1] = BottomContainer:new{
        dimen = Geom:new{
            x = 0,
            y = 0,
            w = Screen:getWidth(),
            h = Screen:getHeight() - Screen:scaleBySize(18),
        },
        self.movable,
    }
end

return BottomMessage
