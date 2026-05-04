-----------------------------------
---gestion acces card
---Si appuie sur BP SOS
    ---Interuption du cycle en cours
--- Si accessLevel == 2 and switchMaintenance activer
    --- Rentrer en mode maintenance
---Si appuie sur BP cycle sas
    ---lancement cycle
---arrêt cycle
-----------------------------------


----------------------------
-- import de la librairie
----------------------------

local system = require("system")

----------------------------
-- Définition des donnés
----------------------------

local LT = ic.enums.LogicType
local LBM = ic.enums.LogicBatchMethod

local housingAccess = 0
local weatherStation = 1
local housingCoreId = ic.find("IC Housing core")
local bpAcquiterId = ic.find("Acquiter SOS")
local switchMaintenanceId = ic.find("Maintenance")
local bpSosId = ic.find("SOS")
local stateWheater = {
    noStorm = 0,
    stormIncoming = 1,
    inStorm = 2,
}

----------------------------
-- Définition des functions
----------------------------
local function clignotementBpAcquiter()
    system.safe.writeId(bpAcquiterId, LT.Color, 4, "Bouton Acquitement SOS") -- Rouge
    yield()
    system.safe.writeId(bpAcquiterId, LT.Color, 5, "Bouton Acquitement SOS") -- Jaune
end


----------------------------
-- Initialisation
----------------------------

system.safe.writeId(bpAcquiterId, LT.Color, 0, "Bouton Acquitement SOS") -- Bleu


while true do
    ----------------------------
    -- Lecture des donnés
    ----------------------------

    local dcy = true -- Intégrer le message réseau de la console
    local bpSosState = system.safe.readId(bpSosId, LT.Activate, "Bouton SOS")
    local bpAcquiterstate = system.safe.readId(bpAcquiterId, LT.Activate, "Bouton Acquitement SOS")
    local SwitchMaintenanceState = system.safe.readId(switchMaintenanceId, LT.On, "Switch Maintenance")
    local accessLevel = system.safe.read(housingAccess, LT.Setting, "IC Housing Access")
    local actualWeatherMode = system.safe.read(weatherStation, LT.Mode, "Weather Station")
    local nextWeatherEventTime = system.safe.read(weatherStation, LT.NextWeatherEventTime, "weather station") / 60 -- Renvoie dans combient de temps arrive la prochaine tempète en minute

    if actualWeatherMode == 0 then
        local actualWeather = stateWheater.noStorm
    elseif actualWeatherMode == 1 then
        local actualWeather = stateWheater.stormIncoming
    else
        local actualWeather = stateWheater.inStorm
    end

    if SwitchMaintenanceState == 1 then
        ic.net.send(housingCoreId, "SwitchMaintenanceState", true)
    elseif bpSosState == 1 then
        ic.net.send(housingCoreId, "bpSosState", true)
    elseif bpAcquiterstate == 1 then
        ic.net.send(bpAcquiterId, "bpAcquiterstate", true)
    elseif dcy == 1 then
        ic.net.send(housingCoreId, "dcy", true)
    end
    ic.net.send(screen, "weather", {actualWeatherMode = actualWeatherMode, nextWeatherEventTime = nextWeatherEventTime})
end