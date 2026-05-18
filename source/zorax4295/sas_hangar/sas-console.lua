----------------------------------Explication du programme--------------------------------------
-- Se système est conçus pour s'afficher sur cette écran : Console Monitor
-- La taille de l'écran est de : w=460px | h=460px
-- Cette écran à été dimmensionné avec : https://www.figma.com
---------------------------------------Objectif-------------------------------------------------

------------------------------------------------------------------------------------------------


-----------------------------------------------------
-- import de la librairie
-----------------------------------------------------

local system = require("system")
local scriptedScreen = require("scriptedScreen")


----------------------------
-- Définition des constante
----------------------------


-- Garde l'id de la derniere page UI active pour que serialize() puisse
-- sauvegarder cette page et que deserialize() puisse la restaurer.
-- La valeur "auto" represente seulement la page par defaut de ce script,
-- utilisee avant le premier set() ou si aucune sauvegarde n'est restauree.
-- Dans un autre script, cette valeur pourrait etre "manu" ou toute autre
-- page initiale choisie. Elle est definie ici, avant createScreen(), car
-- les fonctions set() crees dans createScreen() doivent toutes modifier
-- cette meme variable.
local currentUi = "auto"

-- Déffinition des parametre de chaque écran
local function createScreen(name)
    local surface = ss.ui.surface(name)
    return {
        -- Rend accessible la surface pour utilisation ulterieur
        surface = surface,
        -- Affiche l'écran
        set = function()
            -- Retourne l'id de la page acctuel
            currentUi = name
            ss.ui.activate(name)
        end,
        -- Retire tout les élément afficher a l'écran
        clear = function ()
            surface:clear()            
        end,
    }
end

-----------------------------------------------------
-- Création des écran
-----------------------------------------------------

--Liste toute les page 
local ui = {
    manu = createScreen("manu"),
    auto = createScreen("auto"),
    setting = createScreen("setting"),
}

-----------------------------------------------------
-- Déffinition d'une résolution virtuelle
-----------------------------------------------------

ui.manu.surface:get_resolution(460, 460)
local size = ui.manu.surface:size()

-- Déffinition de la taille de l'écran virtuelle
local w = size.w
local h = size.h

-----------------------------------------------------
-- Initialisation des ecran
-----------------------------------------------------

ui.manu.clear()
ui.auto.clear()
ui.auto.set()

-----------------------------------------------------
-- Déffinition des données
-----------------------------------------------------

local url = {
    buttonStart = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/button_start.png",
    buttonCancel = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/button_cancel.png",
    buttonStartBlocked = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/button_start_blocked.png",
    buttonSettingBlue = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/button_setting_blue.png",
    buttonMenuBlue = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/button_menu_blue.png",
    buttonMenuOrange = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/button_menu_orange.png",
    buttonMenuRed = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/button_menu_red.png",
    noStorm = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/no_storm.png",
    stormIncoming = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/storm_incoming.png",
    inStorm = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/in_storm.png",
    stateSecurited = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/state_securited.png",
    stateCycleEnCours = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/state_cycle_en_cours.png",
    stateReady = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/state_ready.png",
    stateMaintenance = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/state_maintenance.png",
    stateInterruption = "https://raw.githubusercontent.com/zorax4295-organization/Galacticon/refs/heads/main/source/.ressource/sas_hangar_vehiculaire/state_interruption.png",
}
local stateCycle = {
    idle = 0,
    interExterDepresurisation = 1,
    interExterPresurisation = 2,
    ExterInterDepresurisation = 3,
    ExterInterPresurisation = 4,
    Maintenance = 5,
    Interruption = 6,
}
local buttonCycleAction = {
    start = "start",
    cancel = "cancel",
    blocked = "blocked",
}
local weatherState
local nextWeatherEventTime = 0
local actualRoomPressure = 0
local actualTankPressure = 0
local currentState = stateCycle.idle


local function getButtonCycleAction()
    if weatherState == 2 and currentState == stateCycle.idle then
        return buttonCycleAction.blocked
    elseif currentState == stateCycle.idle then
        return buttonCycleAction.start
    elseif currentState == stateCycle.Maintenance or currentState == stateCycle.Interruption then
        return nil
    else
        return buttonCycleAction.cancel
    end
end

-----------------------------------------------------
-- Construction des ui
-----------------------------------------------------

--Permet l'imbriquation d'elements dans des container
local container = {
    sasControl = {
        menu = ui.auto.surface:element({
            id = "container_menu_sasControl", type = "panel",
            rect = { unit = "px", x = 0, y = 410, w = w, h = 50 },
            style = { bg = "#00000000" }
        }),
        run = ui.auto.surface:element({
            id = "container_run_sasControl", type = "panel",
            rect = { unit = "px", x = 0, y = 108, w = w, h = 215 },
            style = { bg = "#00000000" }
        }),
    },
}
--Contien des sous container imbriqué dans des container
local subContainer = {
    sasControl = {
        run = {
            title = container.sasControl.run:element({
                id = "container_run_title_sasControl", type = "panel",
                rect = { unit = "px", x = 0, y = 0, w = w, h = 50 },
                style = { bg = "#00000000" }
            }),
            info = container.sasControl.run:element({
                id = "container_run_info_sasControl", type = "panel",
                rect = { unit = "px", x = 0, y = 50, w = w, h = 115 },
                style = { bg = "#00000000" }
            }),
        },
    },
}
--Liste tout les elements créer dans chaque écran
local element = {
    cycleSas = {
        background = ui.auto.surface:element({
            id = "background", type = "panel",
            rect = { unit = "px", x = 0, y = 0, w = w, h = h },
            style = { bg = "#000000" }
        }),
        weatherPanel = ui.auto.surface:element({
            id = "weatherPanel", type = "image",
            rect = { unit = "px", x = 0, y = 0, w = w, h = 108 },
            props = { url = url.noStorm },
        }),
        labelNextWeatherEventTime = ui.auto.surface:element({
            id = "labelNextWeatherEventTime_sasControl", type = "label",
            rect = { unit = "px", x = 118, y = 63, w = 210, h = 15 },
            props = { text = "" },
            style = { font_size = 14, color = "#FFFFFF", align = "center" }
        }),
        menu = {
            buttonSetting = {
                image = container.sasControl.menu:element({
                    id = "imageButtonSetting_sasControl", type = "image",
                    rect = { unit = "px", x = 311, y = 0, w = 149, h = 50 },
                    props = { url = url.buttonSettingBlue },
                }),
                button = container.sasControl.menu:element({
                    id = "buttonSetting_sasControl", type = "button",
                    rect = { unit = "px", x = 311, y = 0, w = 149, h = 50 },
                    props = { text = "" },
                    style = { bg = "#00000000", text = "#FFFFFF", font_size = 14 },
                    on_click = function()
                        ui.setting.set()
                    end
                }),
            },
            buttonMenu = {
                image = container.sasControl.menu:element({
                    id = "imageButtonMenu_sasControl", type = "image",
                    rect = { unit = "px", x = 0, y = 0, w = 57, h = 50 },
                    props = { url = url.buttonMenuBlue },
                }),
                button = container.sasControl.menu:element({
                    id = "buttonMenu_sasControl", type = "button",
                    rect = { unit = "px", x = 0, y = 0, w = 57, h = 50 },
                    props = { text = "" },
                    style = { bg = "#00000000", text = "#FFFFFF", font_size = 14 },
                    on_click = function()
                    end
                }),
            },
        },
        run = {
            title = {
                labelTitle = subContainer.sasControl.run.title:element({
                    id = "title_sasControl", type = "label",
                    rect = { unit = "px", x = 204, y = 4, w = 51, h = 20 },
                    props = { text = "SAS" },
                    style = { font_size = 24, color = "#0bc1f4", align = "center" }
                }),
                labelSubTitle = subContainer.sasControl.run.title:element({
                    id = "subTitle_sasControl", type = "label",
                    rect = { unit = "px", x = 133, y = 27, w = 193, h = 17 },
                    props = { text = "Interface de fonctionnement" },
                    style = { font_size = 14, color = "#FFFFFF", align = "center" }
                }),
                border = scriptedScreen.element.createRect(subContainer.sasControl.run.title, "borderTitle_sasControl",
                subContainer.sasControl.run.title.rect.x,
                subContainer.sasControl.run.title.rect.y,
                w, 50, "#0bc1f4", 2),
            },
            info = {
                room = {
                    labelTitleRoom = subContainer.sasControl.run.info:element({
                        id = "labelTitleRoom_sasControl", type = "label",
                        rect = { unit = "px", x = 0, y = 3, w = 158, h = 19 },
                        props = { text = "Pression dans la pièce" },
                        style = { font_size = 12, color = "#FFFFFF", align = "center" }
                    }),
                    labelStateRoom = subContainer.sasControl.run.info:element({
                        id = "labelStateRoom_sasControl", type = "label",
                        rect = { unit = "px", x = 38, y = 90, w = 82, h = 20 },
                        props = { text = "NORMAL" },
                        style = { font_size = 14, color = "#008000 ", align = "center" }
                    }),
                    gaugePressureRoom = subContainer.sasControl.run.info:element({
                        id = "gaugePressureRoom_sasControl", type = "gauge",
                        rect = { unit = "px", x = 39, y = 28, w = 80, h = 60 },
                        props = {
                            value = 0,
                            min = 0,
                            max = 300,
                            warn = 140/300,
                            danger = 170/300,
                            label = "",
                            unit = " kPa",
                        },
                        style = {
                            bg = "#111827",
                            arc_thickness = 8,
                            font_size = 16,
                            value_color = "#0bc1f4",
                            label_color = "#FFFFFF",
                        }
                    }),
                },
                tank = {
                    labelTitleTank = subContainer.sasControl.run.info:element({
                        id = "labelTitleTank_sasControl", type = "label",
                        rect = { unit = "px", x = 322, y = 5, w = 115, h = 17 },
                        props = { text = "Pression dans le réservoire du sas" },
                        style = { font_size = 12, color = "#FFFFFF", align = "center" }
                    }),
                    labelStateTank = subContainer.sasControl.run.info:element({
                        id = "labelStateTank_sasControl", type = "label",
                        rect = { unit = "px", x = 339, y = 90, w = 82, h = 20 },
                        props = { text = "NORMAL" },
                        style = { font_size = 14, color = "#008000 ", align = "center" }
                    }),
                    gaugePressureTank = subContainer.sasControl.run.info:element({
                        id = "gaugePressureTank_sasControl", type = "gauge",
                        rect = { unit = "px", x = 342, y = 28, w = 80, h = 60 },
                        props = {
                            value = 0,
                            min = 0,
                            max = 60000,
                            warn = 45/60,
                            danger = 50/60,
                            label = "",
                            unit = " kPa",
                        },
                        style = {
                            bg = "#111827",
                            arc_thickness = 8,
                            font_size = 16,
                            value_color = "#0bc1f4",
                            label_color = "#FFFFFF",
                        }
                    }),
                },
                buttonCycle = {
                    image = subContainer.sasControl.run.info:element({
                        id = "imageButtonCycle_sasControl", type = "image",
                        rect = { unit = "px", x = 131, y = 51, w = 200, h = 50 },
                        props = { url = url.buttonStart },
                    }),
                    button = subContainer.sasControl.run.info:element({
                        id = "buttonCycle_sasControl", type = "button",
                        rect = { unit = "px", x = 131, y = 51, w = 200, h = 50 },
                        props = { text = "" },
                        style = { bg = "#00000000", text = "#FFFFFF", font_size = 14 },
                        on_click = function()
                            local action = getButtonCycleAction()

                            if action == buttonCycleAction.start then
                                ic.net.send("IC Housing core", "sasHangarVehiculaire/startCycleRequested", true)
                            elseif action == buttonCycleAction.cancel then
                                ic.net.send("IC Housing core", "sasHangarVehiculaire/cancelCycleRequested", true)
                            end
                        end
                    }),
                },
            },
            state = container.sasControl.run:element({
                id = "state_sasControl", type = "image",
                rect = { unit = "px", x = 0, y = 199, w = w, h = 94 },
                props = { url = url.stateReady },
            }),
        },
    },
}


-----------------------------------------------------
-- Déffinition des functions
-----------------------------------------------------

local function getColorBorderTitleCycleSas()
    if weatherState == 2 then
        return "#D00000"
    elseif weatherState == 1 then
        return "#E08A00"
    else
        return "#0bc1f4"
    end
end
local function getWeatherUrl()
    if weatherState == 2 then
        return url.inStorm
    elseif weatherState == 1 then
        return url.stormIncoming
    else
        return url.noStorm
    end
end
local function getStateUrl()
    -- Priorité 1 : tempête active
    -- Si weatherState == 2, on force stateSecurited.
    if weatherState == 2 and currentState == stateCycle.idle then
        return url.stateSecurited
    end

    -- Priorité 2
    if currentState == stateCycle.idle then
        return url.stateReady
    elseif currentState == stateCycle.Maintenance then
        return url.stateMaintenance
    elseif currentState == stateCycle.Interruption then
        return url.stateInterruption
    else
        return url.stateCycleEnCours
    end
end
local function getButtonCycleUrl()
    if weatherState == 2 and currentState == stateCycle.idle then
        return url.buttonStartBlocked
    elseif currentState == stateCycle.idle then
        return url.buttonStart
    elseif currentState == stateCycle.Maintenance or currentState == stateCycle.Interruption then
        return url.buttonStartBlocked
    else
        return url.buttonCancel
    end
end

--Actualise l'interface
local function updateScreen()
    element.cycleSas.weatherPanel:set_props({ url = getWeatherUrl()})

    -- Actualise le temps avant l'arriver de la tempête
    if nextWeatherEventTime > 0 then
        if nextWeatherEventTime <= 60 then
            element.cycleSas.labelNextWeatherEventTime:set_props({ text = "Arrivée estimée : " .. nextWeatherEventTime .. " secondes" })
        else
            -- /60 pour convertir en minute et le *10 /10 permet d'avoir arrondit avec 1 chiffre apres la virgule
            nextWeatherEventTime = math.floor((nextWeatherEventTime / 60) * 10 ) / 10
            element.cycleSas.labelNextWeatherEventTime:set_props({ text = "Arrivée estimée : " .. nextWeatherEventTime .. " minute" })
        end
    else
        element.cycleSas.labelNextWeatherEventTime:set_props({ text = "" })
    end

    -- Actualise l'état du sas
    element.cycleSas.run.state:set_props({ url = getStateUrl() })
    -- Actualise le bouton cycle
    element.cycleSas.run.info.buttonCycle.image:set_props({ url = getButtonCycleUrl() })
    -- Actualise le contour du titre de la page cycleSas
    element.cycleSas.run.title.border:set_style(getColorBorderTitleCycleSas())

    
    -- Actualisation des gauges de pression
    if actualRoomPressure >= 1000 then
        element.cycleSas.run.info.room.gaugePressureRoom:set_props({ value = actualRoomPressure / 1000, max = 60, unit = " MPa" })
    else
        element.cycleSas.run.info.room.gaugePressureRoom:set_props({ value = actualRoomPressure })
    end
    if actualTankPressure >= 1000 then
        element.cycleSas.run.info.tank.gaugePressureTank:set_props({ value = actualTankPressure / 1000, max = 60, unit = " MPa" })
    else
        element.cycleSas.run.info.tank.gaugePressureTank:set_props({ value = actualTankPressure })
    end
end


-----------------------------------------------------
-- Sauvgarde / Restauration de la dernière interface active
-----------------------------------------------------

-- Sauvgarde l'id de la dernière page utilisé
function serialize()
    return currentUi
end

--En Lua, dans un if, tout ce qui n’est pas nil ou false est considéré comme true.
-- au if : si blob n'est pas un string ou si la table n'existe pas alors sa ne passe pas
--Si la table existe sa renvoie la table et non nil ou false donc la condition ne passe pas

function deserialize(blob)
    if type(blob) ~= "string" or not ui[blob] then --ui[blob] lit la valeur de blob (ex: blob="auto" => ui.auto), ui.blob cherche la cle fixe "blob"; donc [] sert quand le nom est variable
        print(system.log.time().."h "..system.log.level("warn").." : Echec de la Reconstruction des donnés blob n'est pas de type string")
        return
    end
    currentUi = blob
    ui[blob].set()
end



-----------------------------------------------------
-- reception message réseau
-----------------------------------------------------

--Reception de l'état de la weatherStation
ic.net.subscribe("sasHangarVehiculaire/weatherState", function(_, payload, _, _, _)
    if type(payload) ~= "table" then -- Gestion des erreurs
        print(system.log.time() .. "h " .. system.log.level("warn").."La charge utile du message réseau <<color=#FFFF00>sasHangarVehiculaire/weatherState</color>> n'est pas de type <color=#FFFF00>table</color>.")
        return
    end
    weatherState = payload.actualWeatherMode
    nextWeatherEventTime = payload.nextWeatherEventTime
    updateScreen()
end)
--Reception de l'état actuel du programme core
ic.net.subscribe("sasHangarVehiculaire/currentState", function (_, payload, _, _, _)
    if type(payload) ~= "number" then
        print(system.log.time() .. "h " .. system.log.level("warn").."La charge utile du message réseau <<color=#FFFF00>sasHangarVehiculaire/currentState</color>> n'est pas de type <color=#FFFF00>number</color>.")
        return
    end
    currentState = payload
    updateScreen()
end)
ic.net.subscribe("sasHangarVehiculaire/actualPressure", function (_, payload, _, _, _)
    if type(payload) ~= "table" then
        print(system.log.time() .. "h " .. system.log.level("warn").."La charge utile du message réseau <<color=#FFFF00>sasHangarVehiculaire/actualPressure</color>> n'est pas de type <color=#FFFF00>table</color>.")
        return
    end

    actualRoomPressure = payload.actualRoomPressure
    actualTankPressure = payload.actualTankPressure
    updateScreen()
end)


while true do
    yield()
end
