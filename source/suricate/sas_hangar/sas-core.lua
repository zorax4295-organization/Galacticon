-----------------------------------
--- Init du programe dans le sens INTER->EXTER
--- Ecouter startCycle de l'ic housing controle
--- fermer les portes interne
--- Dépressuriser vent inter
--- Préssuriser vent exter
--- Ouvrire les portes externe
--- Switch du sens du sas
--- Ecouter startCycle de l'ic housing controle
--- fermer les portes exterieur
--- Dépressuriser vent exter
--- Préssuriser vent inter
--- Ouvrire les portes interieur
--- Switch du sens du sas
-----------------------------------

----------------------------
-- import de la librairie
----------------------------

local system = require("system")


----------------------------
-- Définition des appareil
----------------------------

local LT = ic.enums.LogicType
local LBM = ic.enums.LogicBatchMethod

local housingAccess = 0
local sensor = 1
local sensorIntern = 2
local sensorExtern = 3
local weatherStation = 4
local flashLightHash = hash("StructureFlashingLight")
local hangarDoorHash = hash("StructureGlassDoor")
local hangarDoorInterName = hash("Glass Door inter")
local hangarDoorExterName = hash("Glass Door exter")
local poweredVentHash = hash("StructureActiveVent")
local poweredVentInterName = hash("Active Vent inter")
local poweredVentExterName = hash("Active Vent exter")
local lightHash = hash("StructureLightRound")

local bpAcquiterHash = hash("ModularDeviceSquareButton")
local switchMaintenanceHash = hash("ModularDeviceFlipCoverSwitch")
local bpSosHash = hash("ModularDeviceUtilityButton2x2")



----------------------------
-- Définition des donnés
----------------------------

local startCycle = false -- Permet de lancer le cycle sas valeur a modifier
local lastSentWeatherMode
local lastSentNextWeatherEventTime
local stateCycle = {
    idle = 0,
    interExterDepresurisation = 1,
    interExterPresurisation = 2,
    ExterInterDepresurisation = 3,
    ExterInterPresurisation = 4,
    Maintenance = 5,
    Interruption = 6,
}
local currentState
local sensCycle = {
    interExter = 0,
    exterInter = 1,
}
local currentSensCycle = sensCycle.interExter

local stateWheater = {
    noStorm = 0,
    stormIncoming = 1,
    inStorm = 2,
}


----------------------------
-- Définition des functions
----------------------------

-- Test l'activation du bouton maintenance
local function setCurrentState(newState)
    if currentState ~= newState then
        currentState = newState
        ic.net.publish("sasHangarVehiculaire/currentState", currentState)
    end
end
local function setCurrentWeather(actualWeatherMode, nextWeatherEventTime)
    if actualWeatherMode ~= lastSentWeatherMode or nextWeatherEventTime ~= lastSentNextWeatherEventTime then
        ic.net.publish("sasHangarVehiculaire/weatherState", {
            actualWeatherMode = actualWeatherMode,
            nextWeatherEventTime = nextWeatherEventTime
        })

        lastSentWeatherMode = actualWeatherMode
        lastSentNextWeatherEventTime = nextWeatherEventTime
    end
end
local function isSwitchMaintenanceEnable()
    local SwitchMaintenanceState = ic.batch_read(switchMaintenanceHash, LT.On, LBM.Maximum)
    if SwitchMaintenanceState == 1 and system.safe.read(housingAccess, LT.Setting, "IC Housing Access") == 2 then
        return true
    else
        return false
    end
end
local function isInterruptionButtonActivate()
    local bpSosState = ic.batch_read(bpSosHash, LT.Activate, LBM.Maximum)
    if bpSosState == 1 then
        return true
    else
        return false
    end
end
local function isAcquitterButtonActivate()
    local bpAcquiterstate = ic.batch_read(bpAcquiterHash, LT.Activate, LBM.Maximum)
    if bpAcquiterstate == 1 then
        return true
    else
        return false
    end
end
-- Mode maintenance
local function maintenance()
    setCurrentState(stateCycle.Maintenance)
    print(system.log.time().."h "..system.log.level("info").." : Maintenance déclencher")
    ic.batch_write(flashLightHash, LT.On, 0)
    ic.batch_write(lightHash, LT.On, 1)
    ic.batch_write(poweredVentHash, LT.On, 0)

    ic.batch_write(hangarDoorHash, LT.Lock, 0)
    ic.batch_write(flashLightHash, LT.Lock, 0)
    ic.batch_write(lightHash, LT.Lock, 0)
    ic.batch_write(poweredVentHash, LT.Lock, 0)

    while isSwitchMaintenanceEnable() and system.safe.read(housingAccess, LT.Setting, "IC Housing Access") == 2 do
        yield()
    end
    print(system.log.time().."h "..system.log.level("info").." : fin de maintenance")
    ic.batch_write(flashLightHash, LT.On, 0)
    ic.batch_write(lightHash, LT.On, 1)
    ic.batch_write(poweredVentHash, LT.On, 0)

    ic.batch_write_name(hangarDoorHash, hangarDoorExterName, LT.Lock, 1)
    ic.batch_write(flashLightHash, LT.Lock, 1)
    ic.batch_write(lightHash, LT.Lock, 1)
    ic.batch_write(poweredVentHash, LT.Lock, 1)
end
-- Mode interruption
local function interruption()
    setCurrentState(stateCycle.Interruption)
    print(system.log.time().."h "..system.log.level("info").." : Intérruption déclencher")
    ic.batch_write(flashLightHash, LT.On, 1)
    ic.batch_write(lightHash, LT.On, 0)
    ic.batch_write(poweredVentHash, LT.On, 0)
    while not (isAcquitterButtonActivate() and system.safe.read(housingAccess, LT.Setting, "IC Housing Access") == 2) do
        ic.batch_write(bpAcquiterHash, LT.Color, 4) -- Rouge
        if isAcquitterButtonActivate() and system.safe.read(housingAccess, LT.Setting, "IC Housing Access") == 2 then
            break
        end
        yield()
        ic.batch_write(bpAcquiterHash, LT.Color, 5) -- Jaune
        if isAcquitterButtonActivate() and system.safe.read(housingAccess, LT.Setting, "IC Housing Access") == 2 then
            break
        end


        yield()
    end
    print(system.log.time().."h "..system.log.level("info").." : fin d'intérruption")
    ic.batch_write(hangarDoorHash, LT.Lock, 1)
    ic.batch_write(flashLightHash, LT.On, 0)
    ic.batch_write(lightHash, LT.On, 1)
    ic.batch_write(bpAcquiterHash, LT.Color, 0) -- Bleu
end
-- Lance le cycle INTER -> EXTER
local function cycleInterExter()
    print(system.log.time().."h "..system.log.level("info").." : Démarage cycle interieur -> exterieur")
    if currentState == stateCycle.interExterDepresurisation or currentState == stateCycle.idle then
        setCurrentState(stateCycle.interExterDepresurisation)
        ic.batch_write_name(hangarDoorHash, hangarDoorInterName, LT.Lock, 1)
        ic.batch_write_name(hangarDoorHash, hangarDoorInterName, LT.Open, 0)
        ic.batch_write(lightHash, LT.On, 0)
        ic.batch_write(flashLightHash, LT.On, 1)
        yield()
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.Mode, 1) -- Dépressuriser
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 1)
        while system.safe.read(sensor, LT.Pressure, "Gas Sensor") ~= 0 do -- Tant que la pression !=0 alors je patiente
            if isInterruptionButtonActivate() then
                interruption()
                return
            end
            yield()
        end
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 0)
        yield()
        setCurrentState(stateCycle.interExterPresurisation)
    end

    if currentState == stateCycle.interExterPresurisation then
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.Mode, 0) -- Préssuriser
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 1)
        while 
            system.safe.read(sensor, LT.Pressure, "Gas Sensor") ~= system.safe.read(sensorExtern, LT.Pressure, "Gas Sensor Extern") and
            system.safe.read(sensorExtern, LT.Pressure, "Gas Sensor Extern") >=10 -- Supérieur a 10kPa
        do
            if isInterruptionButtonActivate() then
                interruption()
                return
            end
            yield()
        end
        yield()
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 0)
        ic.batch_write_name(hangarDoorHash, hangarDoorExterName, LT.Lock, 0)
        ic.batch_write_name(hangarDoorHash, hangarDoorExterName, LT.Open, 1)
        ic.batch_write(flashLightHash, LT.On, 0)
        ic.batch_write(lightHash, LT.On, 1)
    end
    currentSensCycle = sensCycle.exterInter
end
-- Lance le cycle EXTER -> INTER
local function cycleExterInter()
    print(system.log.time().."h "..system.log.level("info").." : Démarage cycle exterieur -> interieur")
    if currentState == stateCycle.ExterInterDepresurisation or currentState == stateCycle.idle then
        setCurrentState(stateCycle.ExterInterDepresurisation)
        ic.batch_write_name(hangarDoorHash, hangarDoorExterName, LT.Lock, 1)
        ic.batch_write_name(hangarDoorHash, hangarDoorExterName, LT.Open, 0)
        ic.batch_write(lightHash, LT.On, 0)
        ic.batch_write(flashLightHash, LT.On, 1)
        yield()
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.Mode, 1) -- Dépressuriser
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 1)
        while system.safe.read(sensor, LT.Pressure, "Gas Sensor sas") ~= 0 do -- Tant que la pression !=0 alors je patiente
            if isInterruptionButtonActivate() then
                interruption()
                return
            end
            yield()
        end
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 0)
        yield()
        setCurrentState(stateCycle.ExterInterPresurisation)
    end
    
    if currentState == stateCycle.ExterInterPresurisation then
        local pressureInter = system.safe.read(sensorIntern, LT.Pressure, "Gas Sensor Intern")
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.Mode, 0) -- Pressuriser
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.PressureExternal, pressureInter)
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 1)
        while
            system.safe.read(sensor, LT.Pressure, "Gas Sensor sas") <= system.safe.read(sensorIntern, LT.Pressure, "Gas Sensor Intern")-0.5 and
            system.safe.read(sensorIntern, LT.Pressure, "Gas Sensor Intern") >=10 -- Supérieur a 10kPa
        do
            if isInterruptionButtonActivate() then
                interruption()
                return
            end
            yield()
        end
        yield()
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 0)
        ic.batch_write_name(hangarDoorHash, hangarDoorInterName, LT.Lock, 0)
        ic.batch_write_name(hangarDoorHash, hangarDoorInterName, LT.Open, 1)
        ic.batch_write(flashLightHash, LT.On, 0)
        ic.batch_write(lightHash, LT.On, 1)
    end
    currentSensCycle = sensCycle.interExter
end

----------------------------
-- Init du système
----------------------------
do
    ic.batch_write_name(hangarDoorHash, hangarDoorExterName, LT.Lock, 1)
    ic.batch_write(flashLightHash, LT.Lock, 1)
    ic.batch_write(flashLightHash, LT.On, 0)
    ic.batch_write(lightHash, LT.Lock, 1)
    ic.batch_write(lightHash, LT.On, 1)
    ic.batch_write(poweredVentHash, LT.Lock, 1)
    ic.batch_write(poweredVentHash, LT.On, 0)
    ic.batch_write(bpAcquiterHash, LT.Color, 0) -- Bleu
end


local buttonStartTemp = ic.find("Logic Button Round")

while true do
    ----------------------------
    -- Lecture des donnés
    ----------------------------

    local startCycle = ic.read_id(buttonStartTemp, LT.Activate) -- Intégrer le message réseau de la console
    local accessLevel = system.safe.read(housingAccess, LT.Setting, "IC Housing Access")
    local actualWeatherMode = system.safe.read(weatherStation, LT.Mode, "Weather Station")
    local nextWeatherEventTime = system.safe.read(weatherStation, LT.NextWeatherEventTime, "weather station") / 60 -- Renvoie dans combient de temps arrive la prochaine tempète en minute

    setCurrentWeather(actualWeatherMode, nextWeatherEventTime) --Envoie les valeur actualiser a l'ecran

    if isSwitchMaintenanceEnable() then
        maintenance()
    end
    if isInterruptionButtonActivate() then
        interruption()
    end
    

    if startCycle==1 and accessLevel >= 1 then -- accessLevel 1 = accès normal et 2 = accès maintenance
        if currentSensCycle == sensCycle.interExter then
            cycleInterExter()
        else
            cycleExterInter()
        end
    end

    setCurrentState(stateCycle.idle) --Le système est en attente d'un lancement du cycle
    yield()
end