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
local flashLight = hash("StructureFlashingLight")
local hangarDoor = hash("StructureMediumHangerDoor")
local hangarDoorInterName = ""
local hangarDoorExterName = ""
local poweredVent = hash("StructurePoweredVent")
local poweredVentInterName = ""
local poweredVentExterName = ""
local light = hash("StructureWallLight")

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

ic.batch_write(hangarDoor, LT.Lock, 1)
ic.batch_write(flashLight, LT.Lock, 1)
ic.batch_write(flashLight, LT.On, 0)
ic.batch_write(light, LT.Lock, 1)
ic.batch_write(light, LT.On, 1)


while true do
    currentState = state.idle --Le système est en attente d'un lancement du cycle
    local startCycle = true
    
    if startCycle then
        currentState = state.interExterDepresurisation
        ic.batch_write_name(hangarDoor, hangarDoorInterName, LT.Open, 0)
        local hangarDoorOpenState = ic.batch_read(hangarDoor, LT.Open, LBM.Maximum)
        if hangarDoorOpenState==1 then
            print(system.log.time().."h "..system.log.level("fatal").." : Porte non fermer")
            -- faire crash le programme
        end
        ic.batch_write(flashLight, LT.On, 1)
        ic.batch_write_name(poweredVent, poweredVentInterName, LT.Mode, 1) -- Dépressuriser
        ic.batch_write_name(poweredVent, poweredVentInterName, LT.On, 1)
        while system.safe.read(sensor, LT.Pressure, "Gas Sensor") ~= 0 do yield() end -- Tant que la pression !=0 alors je patiente
        ic.batch_write_name(poweredVent, poweredVentInterName, LT.On, 0)
    end
    yield()
end