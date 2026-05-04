--@module system

local system = {}
system.log={}
system.safe={}
system.utils={}

---@class LogicType
---@class LogicSlotType
---@class PrefabHash


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

    return "<color=#008000><</color>Module : <color=#FFFF00>" .. name .. "</color><color=#008000>></color>"
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

--Écriture protéger d'une valeur sur des appareils avec gestion d'erreur <p>
--La méthode sert a definir quelle valeur pour le retour est prise en compte la Max Min ect
---@param hash PrefabHash
---@param logicType LogicType
---@param value number
---@param nameDevice string|nil
function system.safe.batch_write(hash, logicType, value, nameDevice, methode)
    ic.batch_write(hash, logicType, value)
    yield()
    local actualValue = ic.batch_read(hash, logicType, methode)
    if actualValue ~= value then
        print(system.log.time().."h "..system.log.level("fatal").." : Device manquant : [<color=#FFFF00>"..(nameDevice==nil and "Unknow" or nameDevice).."</color>].")
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

---@param color "Blue" | "Red" | "Orange" | "Yellow" | "Green" | "Gray" | "White" | "Black" | "Brown" | "Pink" | "Purple" | "Khaki"
---@param message string
---@return string
function system.utils.color(color, message)
    if color=="Blue" then
        return "<color=#212AA5>" .. message .. "</color>"
    elseif color == "Red" then
        return "<color=#E70200>" .. message .. "</color>"
    elseif color == "Orange" then
        return "<color=#FF662B>" .. message .. "</color>"
    elseif color == "Yellow" then
        return "<color=#FFBC1B>" .. message .. "</color>"
    elseif color == "Green" then
        return "<color=#3F9B39>" .. message .. "</color>"
    elseif color == "Gray" then
        return "<color=#7B7B7B>" .. message .. "</color>"
    elseif color == "White" then
        return "<color=#E7E7E7>" .. message .. "</color>"
    elseif color == "Black" then
        return "<color=#080908>" .. message .. "</color>"
    elseif color == "Brown" then
        return "<color=#633C2B>" .. message .. "</color>"
    elseif color == "Pink" then
        return "<color=#E41C99>" .. message .. "</color>"
    elseif color == "Purple" then
        return "<color=#732CA7>" .. message .. "</color>"
    elseif color == "Khaki" then
        return "<color=#63633F>" .. message .. "</color>"
    end
    return ""
end

return system -- equivalent a un export en java