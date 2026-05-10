-----------------------------------
---gestion acces card
---Si appuie sur BP cycle sas
    ---lancement cycle
---arrêt cycle
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

local BPsas = hash("ModularDeviceBigLever")
local accessLevel = 0
local weatherDetector = 1
