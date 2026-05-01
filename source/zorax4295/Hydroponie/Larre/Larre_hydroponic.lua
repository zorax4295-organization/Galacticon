LT  = ic.enums.LogicType 
LST = ic.enums.LogicSlotType

----------------------------
-- import de la librairie
----------------------------

local system = require("system")

----------------------------
-- Définition des donnés
----------------------------

local larreDevice = 0
local chuteImportBin = 1
HYDROPONIC_DEVICES = { -- liste les index de station du larre pour chaque zone de plantation
    {zone=1, stationIndexes={1,2,3,4,13,14,15,16}},
    {zone=2, stationIndexes={5,6,7,8,9,10,11,12}},
    {zone=3, stationIndexes={17,18,19,20,29,30,31,32}},
    {zone=4, stationIndexes={21,22,23,24,25,26,27,28}},
}
local states = {
    idle=1,
    harvestingSeeds=2,
    harvestingFruits=3,
    unloadHarvest=4, moveToTray=5,
    plantSeeds=6,
    unloadHarvestFruits=7
}
local currentState = states.idle

----------------------------
--Définition des fonction
----------------------------

local function moveToTray(stationIndex, ignoreIdle)
    system.safe.write(larreDevice, LT.Setting, stationIndex, "Larre hydroponic")
    if ignoreIdle~=true then
        while system.safe.read(larreDevice, LT.Idle, "Larre hydroponic")==0 or system.safe.read(larreDevice, LT.Error, "Larre hydroponic")==1 do yield() end
    end
end
local function unloadHarvest(state)
    currentState = state or states.unloadHarvest
    moveToTray(-1)
    while system.safe.readSlot(larreDevice, 1, LST.Occupied, "Larre hydroponic")==1 do -- unload les fruits jusqu'a ce que la seed du slot 1 passe en slot 0
        if system.safe.readSlot(chuteImportBin, 0, LST.Occupied, "Larre hydroponic")==0 then
            system.safe.write(larreDevice, LT.Activate, 1, "Larre hydroponic")
            while system.safe.readSlot(chuteImportBin, 0, LST.Occupied, "Larre hydroponic")==0 do yield() end
            system.safe.write(chuteImportBin, LT.Open, 0, "Chute Import Bin - export fruits")
        end
        sleep(1)
    end
end
local function harvestSeedsFromTray(stationIndex)
    currentState = states.harvestingSeeds
    moveToTray(stationIndex)
    system.safe.write(larreDevice, LT.Activate, 1, "Larre hydroponic")
end
local function harvestFruitsFromTray(stationIndex)
    local deviceId = ic.find("Hydroponics Device " .. stationIndex)
    currentState = states.harvestingFruits
    moveToTray(stationIndex)
    while system.safe.readSlotId(deviceId, 0, LST.Occupied, "Hydroponics Tray")==1 do
        system.safe.write(larreDevice, LT.Activate, 1, "Larre hydroponic")
        sleep(1)
        if system.safe.readSlot(larreDevice, 0, LST.Quantity, "Larre hydroponic")==system.safe.readSlot(larreDevice, 0, LST.MaxQuantity, "Larre hydroponic") then
            unloadHarvest(states.unloadHarvestFruits)
            currentState = states.harvestingFruits
            moveToTray(stationIndex)
        end
    end
end
local function plantSeeds(stationIndex)
    currentState = states.plantSeeds
    moveToTray(stationIndex)
    system.safe.write(larreDevice, LT.Activate, 1, "Larre hydroponic")
end
local function larreHarvestAndReplantZone(hydroponicDevicesSeeding)
    if currentState==states.idle or currentState==states.harvestingSeeds then
        for _, stationIndex in ipairs(hydroponicDevicesSeeding) do
            local deviceId = ic.find("Hydroponics Device " .. stationIndex)
            local isSeeding = system.safe.readSlotId(deviceId, 0, LST.Seeding, "Hydroponics Device "..stationIndex)
            if isSeeding==1 then -- utile pour la restauration apres restart server car si seeding=0 alors il ne reste pas de seed a récolté et inversement
                harvestSeedsFromTray(stationIndex)
            end
        end
        currentState = states.harvestingFruits
    end
    if currentState==states.harvestingFruits or currentState==states.unloadHarvestFruits then
        for i = #hydroponicDevicesSeeding, 1, -1 do -- permet d'incrementer le tableau a l'enver parceque le #hydroponicDevicesSeeding recupere l'inde max du tableau
            local stationIndex = hydroponicDevicesSeeding[i]
            local deviceId = ic.find("Hydroponics Device " .. stationIndex)
            local isOccupied = system.safe.readSlotId(deviceId, 0, LST.Occupied, "Hydroponics Device "..stationIndex)
            if isOccupied==1 then
                harvestFruitsFromTray(stationIndex)
            end
        end
        currentState = states.unloadHarvest
    end
    if currentState==states.unloadHarvest then
        unloadHarvest()
        currentState = states.plantSeeds
    end
    if currentState==states.plantSeeds then
        for _, stationIndex in ipairs(hydroponicDevicesSeeding) do
            local deviceId = ic.find("Hydroponics Device " .. stationIndex)
            local isOccupied = system.safe.readSlotId(deviceId, 0, LST.Occupied, "Hydroponics Device "..stationIndex)
            if isOccupied==0 then
                plantSeeds(stationIndex)
            end
        end
    end
    moveToTray(0, true)
    currentState = states.idle
end

----------------------------
-- Sauvgarde des donnés
----------------------------

function serialize()
    return util.json.encode({
        hydroponicDevicesSeeding=HYDROPONIC_DEVICES_SEEDING,
        currentState=currentState
    }) -- sauvgarde les hydroponic tray a recolter
end

----------------------------
-- Reconstruction des donnés
----------------------------

function deserialize(blob)
    if type(blob) ~= "string" then
        print(system.log.time().."h "..system.log.level("warn").." : Impossible de reconstruire les donnés : [<color=#FFFF00>blob!=string</color>")
        return
    end
    local ok, data = pcall(util.json.decode, blob)
    if ok and type(data)=="table" then
        if data.hydroponicDevicesSeeding~=nil and data.currentState~=nil then
            HYDROPONIC_DEVICES_SEEDING = data.hydroponicDevicesSeeding
            currentState = data.currentState
        else
            HYDROPONIC_DEVICES_SEEDING = {}
            currentState = states.idle
        end
    end
end
if currentState ~= states.idle and type(HYDROPONIC_DEVICES_SEEDING)=="table" then -- si le larre n'est pas au repos donc a la gare
    larreHarvestAndReplantZone(HYDROPONIC_DEVICES_SEEDING)
end

----------------------------
--Initialisation
----------------------------

do
    system.safe.write(larreDevice, LT.On, 1, "Larre hydroponic")
    print(system.log.time().."h "..system.log.level("info").." : Programme initialiser")
end

while true do
    -- Récupération des variables de chaque hydroponicDevices
    for _, zone in ipairs(HYDROPONIC_DEVICES) do -- itere sur chaque zone de plantation
        -- Actualise la variables seeding de chaque hydroponic tray
        HYDROPONIC_DEVICES_SEEDING = {}
        for _, stationIndex in ipairs(zone.stationIndexes) do -- itere sur chaque stationIndex d'une même zone
            local deviceId = ic.find("Hydroponics Device " .. stationIndex)
            local seeding=ic.read_slot_id(deviceId, 0, LST.Seeding)
            if seeding==1 then
                table.insert(HYDROPONIC_DEVICES_SEEDING, stationIndex) -- permet d'inserer dans un tableau des value sans qu'il ne soit trouer
            end
        end
        if #HYDROPONIC_DEVICES_SEEDING>0 then -- permet de compter la taille du tableau (en nombre d'index présent)
            larreHarvestAndReplantZone(HYDROPONIC_DEVICES_SEEDING)
        end
    end
    sleep(4)
end


do -- récolte
    -- pour chaque plantes d'une zone qui on produit une graine
    -- déplacement du larre jusqu'a l'hydroponic Tray
    -- récolte de toute les graine
    -- récolte de tout les fruit
    -- Si la pince est pleine de fruit avant d'avoir tout récolter alors :
        -- déplacement du larre jusqu'a la station de déchargement
        -- Dépose des fruit
        --  continues la recolte la ou il ses arrêter
    -- Une fois tout les fruit récolter
        -- déplacement du larre jusqu'a la station de déchargement
        -- déchargement du fruit
        -- replantage des graines sur les hydroponic tray fraichement recolter
        -- retour a la gare
end
