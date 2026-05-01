--@module scriptedScreen

local scriptedScreen = {}
scriptedScreen.element = {}

-- Permet la création d'un carré ou d'un rectangle
---@param id string
---@param x number
---@param y number
---@param w number
---@param h number
---@param color string
---@param thickness number
function scriptedScreen.element.createRect(parent, id, x, y, w, h, color, thickness)
    thickness = thickness or 2
    color = color or "#000000"

    local rect = {
        x = x, y = y, w = w, h = h,
        style = {
            color = color,
            thickness = thickness
        }
    }

    local function apply_style(element)
        element:set_style({
            color = rect.style.color,
            thickness = rect.style.thickness
        })
    end

    rect.top = parent:element({
        id = id .. "_top",
        type = "line",
        props = { x1 = x, y1 = y, x2 = x + w, y2 = y },
        style = rect.style
    })

    rect.right = parent:element({
        id = id .. "_right",
        type = "line",
        props = { x1 = x + w, y1 = y, x2 = x + w, y2 = y + h },
        style = rect.style
    })

    rect.bottom = parent:element({
        id = id .. "_bottom",
        type = "line",
        props = { x1 = x, y1 = y + h, x2 = x + w, y2 = y + h },
        style = rect.style
    })

    rect.left = parent:element({
        id = id .. "_left",
        type = "line",
        props = { x1 = x, y1 = y, x2 = x, y2 = y + h },
        style = rect.style
    })

    -- fonction de mise à jour de props.
    -- utiliser nil pour ne pas mettre a jour un argument
    ---@param x number
    ---@param y number
    ---@param w number
    ---@param h number
    function rect:set_props(x, y, w, h)
        self.x = x or self.x
        self.y = y or self.y
        self.w = w or self.w
        self.h = h or self.h

        self.top:set_props({ x1=self.x, y1=self.y, x2=self.x+self.w, y2=self.y })
        self.right:set_props({ x1=self.x+self.w, y1=self.y, x2=self.x+self.w, y2=self.y+self.h })
        self.bottom:set_props({ x1=self.x, y1=self.y+self.h, x2=self.x+self.w, y2=self.y+self.h })
        self.left:set_props({ x1=self.x, y1=self.y, x2=self.x, y2=self.y+self.h })
    end

    -- fonction de mise à jour de style.
    -- utiliser nil pour ne pas mettre a jour un argument
    ---@param color string
    ---@param thickness number
    function rect:set_style(color, thickness)
        self.style.color = color or self.style.color
        self.style.thickness = thickness or self.style.thickness

        self.top:set_style(self.style)
        self.right:set_style(self.style)
        self.bottom:set_style(self.style)
        self.left:set_style(self.style)
    end

    return rect
end

return scriptedScreen