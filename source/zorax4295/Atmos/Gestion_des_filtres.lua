local LBM = ic.enums.LogicBatchMethod
local LST = ic.enums.LogicSlotType
--Définition des device
FILTRATION_HASH = hash("StructureFiltration")

-- Définition des donnés
    -- Recupere le jour, l'heure et les minute de la journé
    TIME = "day " .. util.days_past()-1 .. " | " .. util.clock_time("HH:MM")
    -- Recupération de la liste des gaz pour déclarer les gauge et icon
    local filterByNames = {
        {shortName="O2", longName="Oxygen", gauges={}},
        {shortName="H2", longName="Hydrogen", gauges={}},
        {shortName="N", longName="Nitrogen", gauges={}},
        {shortName="CO2", longName="CarbonDioxide", gauges={}},
        {shortName="POL", longName="Pollutant", gauges={}},
        {shortName="CH4", longName="Methane", gauges={}},
        {shortName="N2O", longName="NitrousOxide", gauges={}},
        {shortName="H2O", longName="Water", gauges={}}
    }
    -- Permet de sauvgarder les donné des filtres
    SAVED_FILTER_STATE = {}
    -- Reconstruction des donnés par rapport au json
    function deserialize(blob)
        if type(blob) ~= "string" then
            print(TIME.." [<color=#FFA500>WARN</color>] : Échec du décodage de la table")
            return
        end
    end


--Définition des functions
    -- renvoie les parametre des ecran dans la table des ecran
    function CREATE_SCREEN(name_screen)
        local surface = ss.ui.surface(name_screen)
        return {
            surface = ss.ui.surface(name_screen),
            activate = function()
                ss.ui.activate(name_screen)
            end
        }
    end
    -- liste des ecran
        local screens = {
            main = CREATE_SCREEN("main"), -- obtien la liste des paramtre de main
        }
    function CREATE_GAUGE(gazName, index)
        local decallageX = index < 4 and 30 or W/2+30 -- ses comme un if else
        local decallageY = index < 4 and index or index-4
        local icon = screens.main.surface:element({
            id = gazName.."_icon", type = "icon",
            rect = { unit = "px", x = decallageX, y = 70 + (GAUGE_H + GAUGE_ESPACEMENT_H)*decallageY, w = GAUGE_W, h = GAUGE_H },
            props = { name = ss.ui.icons.gas[gazName] }
        })
        local gaugeFilter1 = icon:element({
            id = gazName .. " filter 1", type = "gauge",
            rect = { unit = "px", x = GAUGE_W + GAUGE_ESPACEMENT_W, y = 0, w = GAUGE_W, h = GAUGE_H },
            props = {
                min = 0,
                max = 100,
                warn = 0.80,
                danger = 0.90,
                label = "Filtre 1",
                unit = " %",
                invert = true
            },
            style = {
                bg = "#111827",
                arc_thickness = 8,
                font_size = 12,
                value_color = "#FFFFFF",
                label_color = "#FFFFFF"
            }
        })
        local gaugeFilter2 = gaugeFilter1:element({
            id = gazName .. " filter 2", type = "gauge",
            rect = { unit = "px", x = GAUGE_W + GAUGE_ESPACEMENT_W, y = 0, w = GAUGE_W, h = GAUGE_H },
            props = {
                min = 0,
                max = 100,
                warn = 0.80,
                danger = 0.90,
                label = "Filtre 2",
                unit = " %",
                invert = true
            },
            style = {
                bg = "#111827",
                arc_thickness = 8,
                font_size = 12,
                value_color = "#FFFFFF",
                label_color = "#FFFFFF"
            }
        })
        return {gaugeFilter1, gaugeFilter2}
    end
    --Permet de définir la couleur du text de la gauge en fonction de la valeur
    function GAUGE_SET_COLOR(gauge, value)
        if value > 20 then
            gauge:set_style({value_color = "#008000"})
        elseif value > 10 then
            gauge:set_style({value_color = "#FFFF00"})
        elseif value >= 0 then
            gauge:set_style({value_color = "#FF0000"})
        end
    end
    -- Permet d'actualisé les gauge des filtres
    function GAUGE_UPDATE(gauge1, gauge2, filtrationName)
        local filter1 = ic.batch_read_slot_name(FILTRATION_HASH, filtrationName, 0, LST.Quantity, LBM.Minimum)
        gauge1:set_props({value = filter1})
        local filter2 = ic.batch_read_slot_name(FILTRATION_HASH, filtrationName, 1, LST.Quantity, LBM.Minimum)
        gauge2:set_props({value = filter2})
        GAUGE_SET_COLOR(gauge1, filter1)
        GAUGE_SET_COLOR(gauge2, filter2)
        return {
            filter1 = filter1,
            filter2 = filter2
        }
    end
    -- Permet de sauvgarder l'état des filtre au moment de la fermeture du monde
    function serialize()
        return util.json.encode(SAVED_FILTER_STATE)
    end


-- Définition des variables
    -- Recupere la taille physique de l'ecran
    W = screens.main.surface:size().w
    H = screens.main.surface:size().h
    GAUGE_ESPACEMENT_W = 20
    GAUGE_ESPACEMENT_H = 20
    GAUGE_W = 100
    GAUGE_H = 100

-- suppression des element sur l'écran et affichage
    screens.main.surface:clear()
    screens.main.activate()
print(TIME .. " : Programme initialise")

-- Construction de la page main
-- Background
local mainBack = screens.main.surface:element({
    id = "main_back",
    type = "panel",
    rect = { unit = "px", x = 0, y = 0, w = W, h = H },
    style = { bg = "#0F172A" }
})
-- Title
local mainTitle = screens.main.surface:element({
    id = "main_title",
    type = "label",
    rect = {unit="px", x=0, y=0, w=W, h=40},
    props = {text="Gestion des filtres atmosphériques"},
    style = {font_size = 40, align = "center"}
})
--ligne de title
local mainLineTitle = screens.main.surface:element({
    id = "main_line_title",
    type = "line",
    props = { x1 = "0", y1 = "50", x2 = "1000", y2 = "50" },
    style = {color = "#FFFFFF", thickness = 5 }
})
--ligne de separation milieux ecran
local mainLineSeparationTitle = screens.main.surface:element({
    id = "mainLineSeparationTitle",
    type = "line",
    props = { x1 = W/2, y1 = "50", x2 = W/2, y2 = H },
    style = {color = "#FFFFFF", thickness = 3 }
})


for index, value in ipairs(filterByNames) do
    value.gauges = CREATE_GAUGE(value.longName, index-1)
end

-- boucle principale
while true do
    sleep(2)
    for _, value in ipairs(filterByNames) do
        local filtrationName = value.longName
        SAVED_FILTER_STATE[filtrationName] = GAUGE_UPDATE(value.gauges[1], value.gauges[2],hash("Filtration-"..value.shortName))
        print(filtrationName .." | Filtre 1 : "..SAVED_FILTER_STATE[filtrationName]["filter1"] .." | Filtre 2 : "..SAVED_FILTER_STATE[filtrationName]["filter2"])
    end
end