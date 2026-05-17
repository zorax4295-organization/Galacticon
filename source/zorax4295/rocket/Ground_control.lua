-----------------------------------------------------------------------------
--- Sur les umbilical le LT.Maxium = se que passe au maximum l'appareil le débit en L/tick pour un gas ou le requiredPower pour l'electrique
-----------------------------------------------------------------------------
---------------------------------Objectif------------------------------------
--- Préparer la fusée (electriquement, carburant, vidange cargo)
--- lors du décolage préparer le launch mout au lancement
--- Faire interagir le pupitre de commande et les ihm avec le programme
-----------------------------------------------------------------------------


----------------------------
-- import de la librairie
----------------------------

local system = require("system")

----------------------------
-- Définition des donnés
----------------------------

local LT = ic.enums.LogicType
local LBM = ic.enums.LogicBatchMethod

local pumpFuel = {
    id = ic.find("Display Pump direction"),

    displayDirection = {
        remplissage = pack_ascii6("<---"), --Encode en ascii6 pour pouvoir affiché le texte sur un LED DISPLAY
        vidange = pack_ascii6("--->"),
    },
}
local umbilicalHash = {
    gas = hash(""),
    power = hash(""),
    chute = hash(""),
}


while true do
    yield()
end