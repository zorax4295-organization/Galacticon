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
-- Définition des constante
----------------------------

local targetPressureExternal = 2 --kPa


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
local weatherStation = 3
local pipeAnalizer = 4
local flashLightHash = hash("StructureFlashingLight")
local hangarDoorHash = hash("StructureMediumHangerDoor")
local hangarDoorInterName = hash("Hangar Door Inter")
local hangarDoorExterName = hash("Hangar Door Exter")
local poweredVentHash = hash("StructurePoweredVentLarge")
local poweredVentInterName = hash("Powered Vent Large Inter")
local poweredVentExterName = hash("Powered Vent Large Exter")
local lightHash = hash("StructureLightLongWide")

local bpAcquiterHash = hash("ModularDeviceSquareButton")
local switchMaintenanceHash = hash("ModularDeviceFlipCoverSwitch")
local bpSosHash = hash("ModularDeviceUtilityButton2x2")



----------------------------
-- Définition des donnés
----------------------------

local memInitDone = mem_read(0)
local lastSentWeatherMode
local lastSentNextWeatherEventTime
local startCycleRequested = false
local cancelCycleRequested  = false
local stateCycle = {
    idle = 0,
    interExterDepresurisation = 1,
    interExterPresurisation = 2,
    ExterInterDepresurisation = 3,
    ExterInterPresurisation = 4,
    Maintenance = 5,
    Interruption = 6,
    cancelToExter = 7,
    cancelToInter = 8,
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

-- Définit le current state
local function setCurrentState(newState)
    if currentState ~= newState then
        currentState = newState
        ic.net.publish("sasHangarVehiculaire/currentState", currentState)
    end
end
-- Si une nouvelle valeur apparait parmis les argument alors on envoie toute les valeur en message réseau
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


-- Test l'activation du bouton maintenance
local function isSwitchMaintenanceEnable()
    local SwitchMaintenanceState = ic.batch_read(switchMaintenanceHash, LT.On, LBM.Maximum)
    if SwitchMaintenanceState == 1 and system.safe.read(housingAccess, LT.Setting, "IC Housing Access") == 2 then
        return true
    else
        return false
    end
end
-- Est ce que le bouton SOS est activer
local function isInterruptionButtonActivate()
    local bpSosState = ic.batch_read(bpSosHash, LT.Activate, LBM.Maximum)
    if bpSosState == 1 then
        return true
    else
        return false
    end
end
-- Est ce que le bouton acquiter sos est activer
local function isAcquitterButtonActivate()
    local bpAcquiterstate = ic.batch_read(bpAcquiterHash, LT.Activate, LBM.Maximum)
    if bpAcquiterstate == 1 then
        return true
    else
        return false
    end
end
-- Envoie des donnés de pression du tank et de la room
local function refreshPressurGauge()
    ic.net.publish("sasHangarVehiculaire/actualPressure", {
        actualRoomPressure = system.safe.read(sensor, LT.Pressure, "Gas Sensor"),
        actualTankPressure = system.safe.read(pipeAnalizer, LT.Pressure),
    })
end


-- Arrête prematurement le cycle du sas en ouvrant la porte externe
local function cancelToExter()
    cancelCycleRequested = false
    print(system.log.time().."h "..system.log.level("info").." : le cycle a été arrêter prématurément")

    ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 0)
    ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 0)

    yield()

    ic.batch_write_name(hangarDoorHash, hangarDoorExterName, LT.Lock, 0)
    ic.batch_write_name(hangarDoorHash, hangarDoorExterName, LT.Open, 1)

    ic.batch_write(flashLightHash, LT.On, 0)
    ic.batch_write(lightHash, LT.On, 1)

    currentSensCycle = sensCycle.exterInter
    setCurrentState(stateCycle.idle)
end
-- Arrête prematurement le cycle du sas en ouvrant la porte interne
local function cancelToInter()
    cancelCycleRequested = false
    print(system.log.time().."h "..system.log.level("info").." : le cycle a été arrêter prématurément")

    ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 0)
    ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 0)

    yield()

    ic.batch_write_name(hangarDoorHash, hangarDoorInterName, LT.Lock, 0)
    ic.batch_write_name(hangarDoorHash, hangarDoorInterName, LT.Open, 1)

    ic.batch_write(flashLightHash, LT.On, 0)
    ic.batch_write(lightHash, LT.On, 1)

    currentSensCycle = sensCycle.interExter
    setCurrentState(stateCycle.idle)
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
        refreshPressurGauge()
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
        refreshPressurGauge()

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

        -- Test si l'arrêt du cycle est demander par cancel
        if cancelCycleRequested then
            setCurrentState(stateCycle.cancelToExter)
            cancelToExter()
            return
        end

        yield()
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.Mode, 1) -- Dépressuriser
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 1)
        while system.safe.read(sensor, LT.Pressure, "Gas Sensor") ~= 0 do -- Tant que la pression !=0 alors je patiente
            refreshPressurGauge()
            if isInterruptionButtonActivate() then
                interruption()
                return
            end

            -- Test si l'arrêt du cycle est demander par cancel
            if cancelCycleRequested then
                setCurrentState(stateCycle.cancelToExter)
                cancelToExter()
                return
            end

            yield()
        end
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 0)
        yield()
        setCurrentState(stateCycle.interExterPresurisation)
    end

    refreshPressurGauge()
    -- Test si l'arrêt du cycle est demander par cancel
    if cancelCycleRequested then
        setCurrentState(stateCycle.cancelToExter)
        cancelToExter()
        return
    end

    if currentState == stateCycle.interExterPresurisation then
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.Mode, 0) -- Préssuriser
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 1)
        while 
            system.safe.read(sensor, LT.Pressure, "Gas Sensor") >= targetPressureExternal and
            targetPressureExternal >=10 -- Supérieur a 10kPa
        do
            refreshPressurGauge()
            if isInterruptionButtonActivate() then
                interruption()
                return
            end

            -- Test si l'arrêt du cycle est demander par cancel
            if cancelCycleRequested then
                setCurrentState(stateCycle.cancelToExter)
                cancelToExter()
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

        -- Test si l'arrêt du cycle est demander par cancel
        if cancelCycleRequested then
            setCurrentState(stateCycle.cancelToInter)
            cancelToInter()
            return
        end

        yield()
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.Mode, 1) -- Dépressuriser
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 1)
        while system.safe.read(sensor, LT.Pressure, "Gas Sensor sas") ~= 0 do -- Tant que la pression !=0 alors je patiente
            refreshPressurGauge()
            if isInterruptionButtonActivate() then
                interruption()
                return
            end

            -- Test si l'arrêt du cycle est demander par cancel
            if cancelCycleRequested then
                setCurrentState(stateCycle.cancelToInter)
                cancelToInter()
                return
            end

            yield()
        end
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 0)
        yield()
        setCurrentState(stateCycle.ExterInterPresurisation)
    end

    refreshPressurGauge()
    -- Test si l'arrêt du cycle est demander par cancel
    if cancelCycleRequested then
        setCurrentState(stateCycle.cancelToInter)
        cancelToInter()
        return
    end

    if currentState == stateCycle.ExterInterPresurisation then
        local pressureInter = system.safe.read(sensorIntern, LT.Pressure, "Gas Sensor Intern")
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.Mode, 0) -- Pressuriser
        yield() -- obligatoire sinon le pressureExternal n'est pas definit car trop rapide
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.PressureExternal, pressureInter)
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 1)
        while
            system.safe.read(sensor, LT.Pressure, "Gas Sensor sas") <= system.safe.read(sensorIntern, LT.Pressure, "Gas Sensor Intern")-0.5 and
            system.safe.read(sensorIntern, LT.Pressure, "Gas Sensor Intern") >=10 -- Supérieur a 10kPa
        do
            refreshPressurGauge()
            if isInterruptionButtonActivate() then
                interruption()
                return
            end

            -- Test si l'arrêt du cycle est demander par cancel
            if cancelCycleRequested then
                setCurrentState(stateCycle.cancelToInter)
                cancelToInter()
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


-- Sauvgarde des donnés
function serialize()
    return util.json.encode({
        currentState = currentState,
        currentSensCycle = currentSensCycle,
    })
end
-- Reconstruction des donnés
function deserialize(blob)
    if type(blob) ~= "string" then
        print(system.log.time() .. "h " .. system.log.level("warn") .. " : Echec de la Reconstruction des donnés blob n'est pas de type string")
        return
    end
    local ok, data = pcall(util.json.decode, blob)
    if ok and type(data) == "table" then
        currentState = data.currentState
        currentSensCycle = data.currentSensCycle
    else
        print(system.log.time().."h "..system.log.level("info").." : Echec de la Reconstruction des donnés data n'est pas de type table")
    end
end

----------------------------
-- Init du système
----------------------------

if memInitDone ~= 1 then -- Permet d'executer une seul fois dans toute la vie du programme
    ic.batch_write_name(hangarDoorHash, hangarDoorExterName, LT.Lock, 1)
    ic.batch_write_name(hangarDoorHash, hangarDoorInterName, LT.Lock, 0)
    ic.batch_write(flashLightHash, LT.Lock, 1)
    ic.batch_write(flashLightHash, LT.On, 0)
    ic.batch_write(lightHash, LT.Lock, 1)
    ic.batch_write(lightHash, LT.On, 1)
    ic.batch_write(poweredVentHash, LT.Lock, 1)
    ic.batch_write(poweredVentHash, LT.On, 0)
    ic.batch_write(bpAcquiterHash, LT.Color, 0) -- Bleu
    mem_write(0, 1)
end


-----------------------------------------------------
-- reception message réseau
-----------------------------------------------------

ic.net.listen("sasHangarVehiculaire/startCycleRequested", function (_, _, payload)
    if type(payload) ~= "boolean" then
        print(system.log.time() .. "h " .. system.log.level("warn").."La charge utile du message réseau <<color=#FFFF00>sasHangarVehiculaire/startCycleRequested</color>> n'est pas de type <color=#FFFF00>boolean</color>.")
        return
    end
    startCycleRequested = payload
end)
ic.net.listen("sasHangarVehiculaire/cancelCycleRequested", function (_, _, payload)
    if type(payload) ~= "boolean" then
        print(system.log.time() .. "h " .. system.log.level("warn").."La charge utile du message réseau <<color=#FFFF00>sasHangarVehiculaire/cancelCycleRequested</color>> n'est pas de type <color=#FFFF00>boolean</color>.")
        return
    end

    cancelCycleRequested = payload
end)




while true do
    ----------------------------
    -- Redemare le cancelCycle si on était dedans avant le redemarage serveur
    ----------------------------
    if currentState == stateCycle.cancelToExter then
        cancelToExter()
    elseif currentState == stateCycle.cancelToInter then
        cancelToInter()
    elseif currentState == stateCycle.Maintenance then
        maintenance()
    elseif currentState == stateCycle.Interruption then
        interruption()
    elseif currentState == stateCycle.interExterDepresurisation or currentState == stateCycle.interExterPresurisation then
        cycleInterExter()
    elseif currentState == stateCycle.ExterInterDepresurisation or currentState == stateCycle.ExterInterPresurisation then
        cycleExterInter()
    end

    ----------------------------
    -- Lecture des donnés
    ----------------------------

    local accessLevel = system.safe.read(housingAccess, LT.Setting, "IC Housing Access")
    local actualWeatherMode = system.safe.read(weatherStation, LT.Mode, "Weather Station")
    local nextWeatherEventTime = system.safe.read(weatherStation, LT.NextWeatherEventTime, "weather station") -- Renvoie dans combient de temps arrive la prochaine tempète en seconde

    refreshPressurGauge()

    setCurrentWeather(actualWeatherMode, nextWeatherEventTime) --Envoie les valeur actualiser a l'ecran

    if isSwitchMaintenanceEnable() then
        maintenance()
    end
    if isInterruptionButtonActivate() then
        interruption()
    end


    if startCycleRequested==true then -- accessLevel 1 = accès normal et 2 = accès maintenance
    startCycleRequested = false
        if accessLevel >= 1 then
            if currentSensCycle == sensCycle.interExter then
                cycleInterExter()
            else
                cycleExterInter()
            end
        end
    end

    setCurrentState(stateCycle.idle) --Le système est en attente d'un lancement du cycle
    yield()
end
