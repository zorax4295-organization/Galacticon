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
-- Définition des donnés
----------------------------

local LT = ic.enums.LogicType
local LBM = ic.enums.LogicBatchMethod

local sensor = 0
local sensorIntern = 1
local sensorExtern = 2
local flashLight = hash("StructureFlashingLight")
local hangarDoor = hash("StructureGlassDoor")
local hangarDoorInterName = hash("Glass Door inter")
local hangarDoorExterName = hash("Glass Door exter")
local poweredVentHash = hash("StructureActiveVent")
local poweredVentInterName = hash("Active Vent inter")
local poweredVentExterName = hash("Active Vent exter")
local light = hash("StructureLightRound")

local startCycle = false

local state = {
    idle = 0,
    interExterDepresurisation = 1,
    interExterPresurisation = 2,
    ExterInterDepresurisation = 3,
    ExterInterPresurisation = 4,
}
local currentState = state.idle
local sensCycle = {
    interExter = 0,
    exterInter = 1,
}
local currentSensCycle = sensCycle.interExter


----------------------------
-- Init du système
----------------------------

ic.batch_write(hangarDoor, LT.Lock, 0)
ic.batch_write(flashLight, LT.Lock, 0)
ic.batch_write(flashLight, LT.On, 0)
ic.batch_write(light, LT.Lock, 0)
ic.batch_write(light, LT.On, 1)
ic.batch_write(poweredVentHash, LT.On, 0)

----------------------------
-- Définition des functions
----------------------------

local function cycleInterExter()
    if currentState == state.interExterDepresurisation or currentState == state.idle then
        currentState = state.interExterDepresurisation
        ic.batch_write_name(hangarDoor, hangarDoorInterName, LT.Open, 0)
        ic.batch_write(flashLight, LT.On, 1)
        yield()
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.Mode, 1) -- Dépressuriser
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 1)
        while system.safe.read(sensor, LT.Pressure, "Gas Sensor") ~= 0 do yield() end -- Tant que la pression !=0 alors je patiente
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 0)
        yield()
        currentState = state.interExterPresurisation
    end
    
    if currentState == state.interExterPresurisation then
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.Mode, 0) -- Préssuriser
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 1)
        while 
            system.safe.read(sensor, LT.Pressure, "Gas Sensor") ~= system.safe.read(sensorExtern, LT.Pressure, "Gas Sensor Extern") and
            system.safe.read(sensorExtern, LT.Pressure, "Gas Sensor Extern") >=10 -- Supérieur a 10kPa
        do
            yield()
        end
        yield()
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 0)
        ic.batch_write_name(hangarDoor, hangarDoorExterName, LT.Open, 1)
        ic.batch_write(flashLight, LT.On, 0)
    end
    currentSensCycle = sensCycle.exterInter
end

local function cycleExterInter()
    if currentState == state.ExterInterDepresurisation or currentState == state.idle then
        currentState = state.ExterInterDepresurisation
        ic.batch_write_name(hangarDoor, hangarDoorExterName, LT.Open, 0)
        ic.batch_write(flashLight, LT.On, 1)
        yield()
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.Mode, 1) -- Dépressuriser
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 1)
        while system.safe.read(sensor, LT.Pressure, "Gas Sensor") ~= 0 do yield() end -- Tant que la pression !=0 alors je patiente
        ic.batch_write_name(poweredVentHash, poweredVentExterName, LT.On, 0)
        yield()
        currentState = state.ExterInterPresurisation
    end
    
    if currentState == state.ExterInterPresurisation then
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.Mode, 0) -- Pressuriser
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 1)
        while 
            system.safe.read(sensor, LT.Pressure, "Gas Sensor") <= system.safe.read(sensorIntern, LT.Pressure, "Gas Sensor Extern")-0.5 and
            system.safe.read(sensorIntern, LT.Pressure, "Gas Sensor Extern") >=10 -- Supérieur a 10kPa
        do
            yield()
        end
        yield()
        ic.batch_write_name(poweredVentHash, poweredVentInterName, LT.On, 0)
        ic.batch_write_name(hangarDoor, hangarDoorInterName, LT.Open, 1)
        ic.batch_write(flashLight, LT.On, 0)
    end
    currentSensCycle = sensCycle.interExter
end



while true do
    if startCycle==1 then
        if currentSensCycle == sensCycle.interExter then
            cycleInterExter()
        else
            cycleExterInter()
        end
    end

    currentState = state.idle --Le système est en attente d'un lancement du cycle
    yield()
end