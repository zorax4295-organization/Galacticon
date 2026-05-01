----------------------------------Explication du programme--------------------------------------
-- Se système est conçus pour s'afficher sur cette écran : Computer (Big Screen Wall Mounted)
-- La taille de l'écran est de : w=862px | h=584px
-- Cette écran à été dimmensionné avec : https://www.figma.com
---------------------------------------Objectif-------------------------------------------------
-- Supperviser la position et les état du larre
-- Commander le système en manuel
-- Superviser les stock de graine et de fruit dans les frigo
-- Gerer et parametre l'eclairage
------------------------------------------------------------------------------------------------


-- Déffinition des parametre de chaque écran
local function createScreen(name)
    local surface = ss.ui.surface(name)
    return {
        -- Rend accessible la surface pour utilisation ulterieur
        surface=surface,
        -- Affiche l'écran
        set = function()
            ss.ui.activate(name)
        end,
        -- Retire tout les élément afficher a l'écran
        clear = function ()
            surface:clear()            
        end,
    }
end

------------------------
-- Création des écran
------------------------

---Liste toute les table et elements associer 
local ui = {
    accueil = createScreen("accueil"),
    setting = createScreen("setting"),
    auto = createScreen("auto"),
    manu = createScreen("manu"),
}

-- Déffinition de la taille de l'écran physique
local w = 862
local h = 584

-- Permet la création d'un carré ou d'un rectangle
---@param id string
---@param x number
---@param y number
---@param w number
---@param h number
---@param color string
---@param thickness number
function CREATE_RECT(parent, id, x, y, w, h, color, thickness)
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

ui.accueil.clear()
ui.auto.clear()
ui.accueil.set()

--Liste tout les elements créer dans chaque écran
local elements = {
    accueil = {
        background = ui.accueil.surface:element({
            id = "background_accueil", type = "image",
            rect = { unit = "px", x = 0, y = 0, w = w, h = h },
            props = { url = "https://github.com/zorax4295-organization/Galacticon/blob/zorax4295/Larre_Hydroponie/source/zorax4295/Hydroponie/Larre/ressource/larre_hydroponie_screen/accueil_background.png?raw=true"},
        }),
        title = { 
            panel = ui.accueil.surface:element({
                id = "panel_title_accueil", type = "panel",
                rect = { unit = "px", x = 144, y = 368, w = 573, h = 130 },
                style = { bg = "#FFFFFF" }
            }),
            label = ui.accueil.surface:element({
                id = "title_accueil", type = "label",
                rect = { unit = "px", x = 144, y = 368, w = 573, h = 130 },
                props = { text = "Station automatisée de récolte et de stockage" },
                style = { font_size = 50, color = "#000000", align = "center" }
            }),
        },
        button_commencer = ui.accueil.surface:element({
            id = "button_commencer_accueil", type = "button",
            rect = { unit = "px", x = 308, y = 254, w = 245, h = 75 },
            props = { text = "Commencer" },
            style = { bg = "#EDEDED", text = "#000000", font_size = 20 },
            on_click = function()
                ui.auto.set()
            end
        }),
    },
    auto = {
        background = ui.auto.surface:element({
            id = "background_auto", type = "panel",
            rect = { unit = "px", x = 0, y = 0, w = w, h = h },
            style = { bg = "#FFFFFF" }
        }),
        title = ui.auto.surface:element({
            id = "title_auto", type = "label",
            rect = { unit = "px", x = 369, y = 14, w = 123, h = 38 },
            props = { text = "AUTO" },
            style = { font_size = 32, color = "#000000", align = "center" }
        }),
        line_sep_titre = ui.auto.surface:element({
            id = "line_sep_titre_auto", type = "line",
            props = { x1 = "0", y1 = "64", x2 = "862", y2 = "64" },
            style = { color = "#000000", thickness = "3" },
        }),
        line_sep_commande_supervision = ui.auto.surface:element({
            id = "line_sep_commande_supervision_auto", type = "line",
            props = { x1 = "540", y1 = "64", x2 = "540", y2 = "640" },
            style = { color = "#000000", thickness = "3" },
        }),
        menu = {
            home = {
                button = ui.auto.surface:element({
                    id = "button_home_auto", type = "button",
                    rect = { unit = "px", x = 0, y = 544, w = 85, h = 40 },
                    props = { text = "Accueil" },
                    style = { bg = "#F59E0B", text = "#000000", font_size = 20 },
                    on_click = function()
                        ui.accueil.set()
                    end
                }),
                rect = CREATE_RECT(ui.auto.surface, "rect_button_home_auto", 0, 544, 85, 40, "#000000", 2)
            },
        },
    },
}