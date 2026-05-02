----------------------------------Explication du programme--------------------------------------
-- Se système est conçus pour s'afficher sur cette écran : Computer (Big Screen Wall Mounted)
-- La taille de l'écran est de : w=862px | h=584px
-- Cette écran à été dimmensionné avec : https://www.figma.com
---------------------------------------Objectif-------------------------------------------------
-- Supperviser la position et les état du larre
-- Commander le système en manuel
-- Superviser les stock de graine et de fruit dans les frigo
-- Gerer et parametre l'eclairage
------------------------------------Couleur voyant---------------------------------------------
-- Voyant d'arrêt {éteint = 5A0000, allumé = FF0000}
-- Voyant défaut {éteint = B36200, allumé = FF8C00}
-- Voyant marche {éteint = 009900, allumé = 00FF00}
-----------------------------------------------------------------------------------------------


----------------------------
-- import de la librairie
----------------------------

local scriptedScreen= require("scriptedScreen")

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


ui.accueil.clear()
ui.auto.clear()
ui.accueil.set()

--Liste tout les elements créer dans chaque écran
local container = {
    accueil = {},
    auto = {
        menu = ui.auto.surface:element({
            id = "container_menu_auto", type = "panel",
            rect = { unit = "px", x = 0, y = 544, w = 540, h = 40 },
            style = { bg = "#00000000" }
        }),
        supervision = ui.auto.surface:element({
            id = "container_supervision_auto", type = "panel",
            rect = { unit = "px", x = 0, y = 64, w = 540, h = 480 },
            style = { bg = "#00000000" }
        }),
        commande = ui.auto.surface:element({
            id = "container_commande_auto", type = "panel",
            rect = { unit = "px", x = 540, y = 64, w = 322, h = 520 },
            style = { bg = "#00000000" }
        }),
    },
}
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
            accueil = {
                -- button Accueil
                button = container.auto.menu:element({
                    id = "button_home_auto", type = "button",
                    rect = { unit = "px", x = 0, y = 0, w = 85, h = 40 },
                    props = { text = "Accueil" },
                    style = { bg = "#F59E0B", text = "#000000", font_size = 20 },
                    on_click = function()
                        ui.accueil.set()
                    end
                }),
                -- Contour du bouton Accueil
                rect = scriptedScreen.element.createRect(container.auto.menu, "rect_button_home_auto", container.auto.menu.rect.x, container.auto.menu.rect.y, 85, 40, "#000000", 2)
            },
            setting = {
                -- button Setting
                button = container.auto.menu:element({
                    id = "button_setting_auto", type = "button",
                    rect = { unit = "px", x = 85, y = 0, w = 85, h = 40 },
                    props = { text = "Setting" },
                    style = { bg = "#F59E0B", text = "#000000", font_size = 20 },
                    on_click = function()
                        ui.setting.set()
                    end
                }),
                -- Contour du bouton Setting
                rect = scriptedScreen.element.createRect(container.auto.menu, "rect_button_setting_auto", container.auto.menu.rect.x+85, container.auto.menu.rect.y, 85, 40, "#000000", 2)
            },
            auto = {
                -- button Auto
                button = container.auto.menu:element({
                    id = "button_auto_auto", type = "button",
                    rect = { unit = "px", x = 170, y = 0, w = 85, h = 40 },
                    props = { text = "Auto" },
                    style = { bg = "#F59E0B", text = "#000000", font_size = 20 },
                    on_click = function()
                        ui.auto.set()
                    end
                }),
                -- Contour du bouton Auto
                rect = scriptedScreen.element.createRect(container.auto.menu, "rect_button_auto_auto", container.auto.menu.rect.x+170, container.auto.menu.rect.y, 85, 40, "#000000", 2)
            },
            manu = {
                -- button Manuel
                button = container.auto.menu:element({
                    id = "button_manu_auto", type = "button",
                    rect = { unit = "px", x = 255, y = 0, w = 85, h = 40 },
                    props = { text = "Manuel" },
                    style = { bg = "#F59E0B", text = "#000000", font_size = 20 },
                    on_click = function()
                        ui.manu.set()
                    end
                }),
                -- Contour du bouton Auto
                rect = scriptedScreen.element.createRect(container.auto.menu, "rect_button_manu_auto", container.auto.menu.rect.x+255, container.auto.menu.rect.y, 85, 40, "#000000", 2)
            },
        },
        supervision = {
            entete = {
                title = container.auto.supervision:element({
                    id = "title_supervision_auto", type = "label",
                    rect = { unit = "px", x = 207, y = 14, w = 126, h = 29 },
                    props = { text = "Supervision" },
                    style = { font_size = 20, color = "#000000", align = "center" }
                }),
                line_sep_titre_supervision = container.auto.supervision:element({
                    id = "line_sep_titre_supervision_auto", type = "line",
                    props = {
                        -- L'équation permet de se baser sur les coordoné du container etant donné que x1 y1 ect son des coordoné absolue et ignore le parent
                        x1 = tostring(container.auto.supervision.rect.x+0),
                        y1 = tostring(container.auto.supervision.rect.y+58),
                        x2 = tostring(container.auto.supervision.rect.x+540),
                        y2 = tostring(container.auto.supervision.rect.y+58) },
                    style = { color = "#000000", thickness = "3" },
                }),
            },
        },
        commande = {
            entete = {
                title = container.auto.commande:element({
                    id = "title_commande_auto", type = "label",
                    rect = { unit = "px", x = 99, y = 14, w = 124, h = 29 },
                    props = { text = "Commande" },
                    style = { font_size = 20, color = "#000000", align = "center" }
                }),
                line_sep_titre_supervision = container.auto.commande:element({
                    id = "line_sep_titre_commande_auto", type = "line",
                    props = {
                        -- L'équation permet de se baser sur les coordoné du container etant donné que x1 y1 ect son des coordoné absolue et ignore le parent
                        x1 = tostring(container.auto.commande.rect.x+0),
                        y1 = tostring(container.auto.commande.rect.y+58),
                        x2 = tostring(container.auto.commande.rect.x+322),
                        y2 = tostring(container.auto.commande.rect.y+58) },
                    style = { color = "#000000", thickness = "3" },
                }),
            },
        },
    },
}
