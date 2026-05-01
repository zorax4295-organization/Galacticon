LT  = ic.enums.LogicType 
LST = ic.enums.LogicSlotType

-- Définition des donnés
TIME = "day " .. util.days_past()-1 .. " | " .. util.clock_time("HH")
local larreDevice = 0
local fridgeSeedDevice = 1
local chuteImportBin = 2
IS_SEED_REQUESTED = false
local seedList = {
    {name="potato", slotIndex=0, prefabHash=0},
    {name="soybean", slotIndex=1, prefabHash=0},
    {name="tomato", slotIndex=2, prefabHash=-0},
    {name="wheat", slotIndex=3, prefabHash=-0},
}
local stationIndex = {
    dechargement=2,
    gare=0,
    fridgePlantation=-1,
    fridgeSeed=-2,
}

-- Définition des functions
local function logLevel(value)
    if value=="info" then return "[<color=#008000>INFO</color>]"
    elseif value=="warn" then return "[<color=#FFA500>WARN</color>]"
    elseif value=="fatal" then return "[<color=#FF0000>FATAL</color>]"
    elseif value=="debug" then return "[<color=#8F00FF>DEBUG</color>]"
    else return ""
    end
end
-- permet une écriture protéger
local function protectedWrite(device, variable, value, nameDevice)
    local status, error = pcall(function()
        ic.write(device, variable, value)
    end)
    if status==false then
        print(TIME.."h "..logLevel("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>]. Erreur : "..tostring(error))
        -- Faire crash le programme ici
    end
end
local function receiveSeedRequest(_, _, prefabHashPlant)
    for _, value in ipairs(seedList) do
        local prefabHash = ic.read_slot(fridgeSeedDevice, value.slotIndex, LST.OccupantHash) -- Régarde si le slot de la graine correspondante est occuper
        if prefabHash==nil then
            print(TIME.."h "..logLevel("fatal").." : Device manquant : [<color=#FFFF00>Fridge - Seed</color>].")
            return -- faire crash le programme
        else
            value.prefabHash = prefabHash -- récupére le prefab hash de chaque graine présente dans le frigot
        end
    end
    for index, value in ipairs(seedList) do
        if value.prefabHash==prefabHashPlant then
            FRIDGE_SEED_SLOT_INDEX = value.slotIndex
            ic.net.send("Housing - Larre Hydroponic", "response seed request", true) -- envoie au larre hydroponic j'ai trouver une graine
            print(TIME.."h "..logLevel("debug").." : graine de <color=#FFFF00>"..value.name.."</color> trouvé")
            IS_SEED_REQUESTED = true
            return
        end
        if index==4 then -- a modifier si on rajoute des graine par l'index maximal de la table seedList
            ic.net.send("Housing - Larre Hydroponic", "response seed request", false) -- envoie au larre hydroponic je n'est rien trouvé
            print(TIME.."h "..logLevel("warn").." : graine non trouvé")
        end
    end
end
local function transportSeed()
    IS_SEED_REQUESTED=false
    -- Début du déplacement du larre
    protectedWrite(larreDevice, LT.TargetSlotIndex, FRIDGE_SEED_SLOT_INDEX, "Larre hydroponic cargo") -- Définit le slot que cible le larre
    protectedWrite(larreDevice, LT.Setting, stationIndex.fridgeSeed, "Larre hydroponic cargo") -- Déplace le larre jusqu'au frigot à graine
    while ic.read(larreDevice, LT.Idle)==0 do yield() end -- Pattiente pendant le déplacement du larre
    protectedWrite(larreDevice, LT.Activate, 1, "Larre hydroponic cargo") -- Récupère la graine
    protectedWrite(larreDevice, LT.Setting, stationIndex.dechargement, "Larre hydroponic cargo") -- Déplace le larre jusqu'a la zone de dépot vers l'hydroponie
    while ic.read(larreDevice, LT.Idle)==0 do yield() end -- Pattiente pendant le déplacement du larre
    protectedWrite(larreDevice, LT.TargetSlotIndex, 0, "Larre hydroponic cargo") -- Définit le slot que cible le larre
    protectedWrite(larreDevice, LT.Activate, 1, "Larre hydroponic cargo") -- Dépose la graine
    protectedWrite(larreDevice, LT.Setting, stationIndex.gare, "Larre hydroponic cargo") -- Déplace le larre jusqu'a la gare
end

::init::
do
    protectedWrite(larreDevice, LT.On, 1, "Larre hydroponic cargo") -- Allume le larre
    ic.net.listen("seed request", receiveSeedRequest) -- s'enregistre pour écouter les demmande de seed
    print(TIME.."h "..logLevel("info").." : Programme initialiser")
end

while true do
    if IS_SEED_REQUESTED==true then
        transportSeed()
    end
    local chuteImporteBinOccupied = ic.read_slot(chuteImportBin, 0, LST.Occupied)
    if chuteImporteBinOccupied==nil then
        print(TIME.."h "..logLevel("fatal").." : Device manquant : [<color=#FFFF00>Chute Importe Bin - export seed</color>].")
        return -- faire crash le programme
    elseif chuteImporteBinOccupied==1 then
        protectedWrite(chuteImportBin, LT.Open, 0 , "Chute Importe Bin - export seed")
    end
    sleep(1)
end

-- tout fonctionne
-- il faut faire en sorte de récupére les plante recolter par la larre hydroponic puis les trier dans le deuxième frigot