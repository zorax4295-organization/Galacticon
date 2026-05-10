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
-- Création des écran
local ui = {
    accueil = createScreen("accueil"),
    setting = createScreen("setting"),
    supervision = createScreen("supervision"),
}

-- Déffinition de la taille de l'écran physique
local w = ui.accueil.surface:size().w
local h = ui.accueil.surface:size().h

ui.accueil.set()