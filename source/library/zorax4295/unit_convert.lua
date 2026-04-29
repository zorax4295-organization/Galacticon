--@module unitConvert

----------------------------
-- import de la librairie
----------------------------

local system = require("system")


local unitConvert = {}
unitConvert.pressure={}

--Convertion de pression
---@param value number
---@param from string -- "Pa", "kPa", "MPa"
---@param to string   -- "Pa", "kPa", "MPa"
---@return number
function unitConvert.pressure(value, from, to)
    -- Facteurs vers Pascal (unité de base)
    local toPa = {
        Pa  = 1,
        kPa = 1e3,
        MPa = 1e6
    }

    -- Gestion erreur
    if not toPa[from] then
        print(system.log.time().."h "..system.log.level("fatal")..system.log.moduleName("unitConvert").."Unité source invalide: " .. tostring(from))
    end
    if not toPa[to] then
        print(system.log.time().."h "..system.log.level("fatal")..system.log.moduleName("unitConvert").."Unité cible invalide: " .. tostring(to))
    end

    -- Conversion
    local valueInPa = value * toPa[from]
    return valueInPa / toPa[to]
end