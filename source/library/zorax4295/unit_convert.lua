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
        error(system.log.time().."h "..system.logLevel("fatal").."Unité source invalide: " .. tostring(from))
    end
    if not toPa[to] then
        error(system.log.time().."h "..system.logLevel("fatal").."Unité cible invalide: " .. tostring(to))
    end

    -- Conversion
    local valueInPa = value * toPa[from]
    return valueInPa / toPa[to]
end