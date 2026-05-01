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
    supervision = createScreen("supervision"),
}

-- Déffinition de la taille de l'écran physique
local w = ui.accueil.surface:size().w
local h = ui.accueil.surface:size().h
print("w=",w," | h=",h)

ui.accueil.clear()

--Liste tout les elements créer dans chaque écran
local elements = {
    accueil = {
        background = ui.accueil.surface:element({
            id = "background", type = "image",
            rect = { unit = "px", x = 0, y = 0, w = w, h = h },
            props = {url = ""},
        }),
        title = { 
            panel = ui.accueil.surface:element({
                id = "bg", type = "panel",
                rect = { unit = "px", x = 144, y = 368, w = 573, h = 130 },
                style = { bg = "#FFFFFF" }
            }),
            label = ui.accueil.surface:element({
                id = "title", type = "label",
                rect = { unit = "px", x = 144, y = 368, w = 573, h = 130 },
                props = { text = "Station automatisée de récolte et de stockage" },
                style = { font_size = 50, color = "#000000", align = "center" }
            }),
        button = ui.accueil.surface:element({
                id = "start", type = "button",
                rect = { unit = "px", x = 308, y = 254, w = 245, h = 75 },
                props = { text = "Commencer" },
                style = { bg = "#EDEDED", text = "#000000", font_size = 20 },
                on_click = function(playerName)
                    print("Clicked by " .. playerName)
                end
            }),
        },
    },
}

ui.accueil.set()

