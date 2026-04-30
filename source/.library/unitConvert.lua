--@module unitConvert

----------------------------
-- import de la librairie
----------------------------

local system = require("system")

local unitConvert = {}


--Convertion de pression
---@overload fun(value: number, from: "Pa"|"kPa"|"MPa", to: "Pa"|"kPa"|"MPa"): number
function unitConvert.pressure(value, from, to)
    local toPa = {
        Pa  = 1,
        kPa = 1e3,
        MPa = 1e6
    }

    -- Gestion erreur
    if not toPa[from] then
        print(system.log.time().."h "..system.log.level("fatal")..system.log.moduleName("unitConvert").."Unité source invalide: " .. tostring(from))
        return
    elseif not toPa[to] then
        print(system.log.time().."h "..system.log.level("fatal")..system.log.moduleName("unitConvert").."Unité cible invalide: " .. tostring(to))
        return
    end

    -- Conversion
    local valueInPa = value * toPa[from]
    return valueInPa / toPa[to]
end
return unitConvert