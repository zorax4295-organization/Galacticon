--@module system

local system = {}
system.log={}
system.safe={}


----------------------------
-- Définition des fonctions
----------------------------

--Get time
---@return string
function system.log.time()
    return "Day " .. util.days_past()-1 .. " | " .. util.clock_time("HH")
end

--Renvoie un niveau de log formater
---@overload fun(value: "info"|"warn"|"fatal"|"debug"): string
function system.log.level(value)
    if value=="info" then return "[<color=#008000>INFO</color>]"
    elseif value=="warn" then return "[<color=#FFA500>WARN</color>]"
    elseif value=="fatal" then return "[<color=#FF0000>FATAL</color>]"
    elseif value=="debug" then return "[<color=#FFFF00>DEBUG</color>]"
    else return ""
    end
end

-- Renvoie le nom de la librairie formaté
---@param name string
---@return string
function system.log.moduleName(name)
    if type(name) ~= "string" then
        return ""
    end

    return "<color=#008000><</color>Module : <color=#FFFF00>" 
        .. name .. 
        "<color=#008000>></color>"
end

--Écriture protéger d'une valeur sur un appareil avec gestion d'erreur
---@param device integer
---@param logicType LogicType
---@param value number
---@param nameDevice string|nil
function system.safe.write(device, logicType, value, nameDevice)
    local status, error = pcall(function()
        ic.write(device, logicType, value)
    end)
    if status==false then
        print(system.log.time().."h "..system.log.level("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>]. Erreur : "..tostring(error))
        --Faire crash le programme ici
    end
end

--Écriture protéger d'une valeur sur un appareil avec gestion d'erreur
---@param deviceId integer
---@param logicType LogicType
---@param value number
---@param nameDevice string|nil
function system.safe.writeId(deviceId, logicType, value, nameDevice)
    local status, error = pcall(function()
        ic.write_id(deviceId, logicType, value)
    end)
    if status==false then
        print(system.log.time().."h "..system.log.level("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>]. Erreur : "..tostring(error))
        --Faire crash le programme ici
    end
end

--Écriture protéger d'une valeur sur un appareil avec gestion d'erreur
---@param device integer
---@param slot integer
---@param slotType LogicSlotType
---@param value number
---@param nameDevice string|nil
function system.safe.writeSlot(device, slot, slotType, value, nameDevice)
    local status, error = pcall(function()
        ic.write_slot(device, slot, slotType, value)
    end)
    if status==false then
        print(system.log.time().."h "..system.log.level("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>]. Erreur : "..tostring(error))
        --Faire crash le programme ici
    end
end

--Écriture protéger d'une valeur sur un appareil avec gestion d'erreur
---@param deviceId integer
---@param slot integer
---@param slotType LogicSlotType
---@param value number
---@param nameDevice string|nil
function system.safe.writeSlotId(deviceId, slot, slotType, value, nameDevice)
    local status, error = pcall(function()
        ic.write_slot_id(deviceId, slot, slotType, value)
    end)
    if status==false then
        print(system.log.time().."h "..system.log.level("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>]. Erreur : "..tostring(error))
        --Faire crash le programme ici
    end
end

--Écriture protéger d'une valeur sur un appareil avec gestion d'erreur
---@param device integer
---@param logicType LogicType
---@param nameDevice string|nil
---@return number|nil
function system.safe.read(device, logicType, nameDevice)
    local value = ic.read(device, logicType)
    if value==nil then
        print(system.log.time().."h "..system.log.level("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>].")
        --Faire crash le programme ici
    else
        return value
    end
end

--Écriture protéger d'une valeur sur un appareil avec gestion d'erreur
---@param deviceId integer
---@param logicType LogicType
---@param nameDevice string|nil
---@return number|nil
function system.safe.readId(deviceId, logicType, nameDevice)
    local value = ic.read(deviceId, logicType)
    if value==nil then
        print(system.log.time().."h "..system.log.level("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>].")
        --Faire crash le programme ici
    else
        return value
    end
end

--Écriture protéger d'une valeur sur un appareil avec gestion d'erreur
---@param device integer
---@param slot integer
---@param slotType LogicSlotType
---@param nameDevice string|nil
---@return number|nil
function system.safe.readSlot(device, slot, slotType, nameDevice)
    local value = ic.read_slot(device, slot, slotType)
    if value==nil then
        print(system.log.time().."h "..system.log.level("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>].")
        --Faire crash le programme ici
    else
        return value
    end
end

--Écriture protéger d'une valeur sur un appareil avec gestion d'erreur
---@param deviceId integer
---@param slot integer
---@param slotType LogicSlotType
---@param nameDevice string|nil
---@return number|nil
function system.safe.readSlotId(deviceId, slot, slotType, nameDevice)
    local value = ic.read_slot_id(deviceId, slot, slotType)
    if value==nil then
        print(system.log.time().."h "..system.log.level("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>].")
        --Faire crash le programme ici
    else
        return value
    end
end

return system -- equivalent a un export en java