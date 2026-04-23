local LT = ic.enums.LogicType
----------------------------------------------------
---- KEEP THOSE IN SYNC WITH THE FOUNDRY LIB
local SILO_BASE_NAME = "SDB Silo-"
local SORTER_BASE_NAME = "Logic Sorter-"
local STACKER_BASE_NAME = "Stacker-"
local SILO_CHUTE_VALVE_BASE_NAME = "Chute Digital Valve-"
local ORES = { "Iron", "Copper", "Gold", "Silver", "Lead", "Cobalt", "Nickel", "Silicon", "Coal", "Uranium" }
local GASES_ORES = { "Oxite", "Nitrice", "Volatiles", "Ice", "ReagentMix" } -- Deal with reagent as gases for now => Not in Silos
----------------------------------------------------

local function powerAndLock(deviceId)
  ic.write_id(deviceId, LT.On, 1)
  -- ic.write_id(deviceId, LT.Lock, 1)
end

local function initOreSorters()
  for _, value in ipairs(ORES) do
    local silo = ic.find(SILO_BASE_NAME .. value)
    if silo == nil then
      print(string.format("Init error: Silo %s not found", value))
      break
    end
    local stacker = ic.find(STACKER_BASE_NAME .. value)
    if stacker == nil then
      print(string.format("Init error: Stacker %s not found", value))
      break
    end
    local sorter = ic.find(SORTER_BASE_NAME .. value)
    if sorter == nil then
      print(string.format("Init error: Sorter %s not found", value))
      break
    end
    local operation = ic.bit_sll(hash("Item" .. value .. "Ore"), 8)
    local operation = ic.bit_or(operation, 1) -- 1 is for prefabHash match
    powerAndLock(sorter)
    ic.write_id(sorter, LT.Mode, 1)
    ic.mem_clear_id(sorter)
    ic.mem_put_id(sorter, 1, operation)

    powerAndLock(stacker)
    ic.write_id(stacker, LT.Setting, 50)

    powerAndLock(silo)
    ic.write_id(silo, LT.Open, 1)
  end
end

local function initUnloader()
  local unloader = ic.find("Unloader-Mining")
  local sorter = ic.find("Logic Sorter-Unloader-Mining")
  local chute = ic.find("Chute Export Bin-Mining")

  powerAndLock(unloader)
  powerAndLock(sorter)
  powerAndLock(chute)

  -- We want to keep ores /!\ Chutes are inverted, so we wan't to set opposite rules
  --- Not ores
  local notOreOperation = ic.bit_sll(10, 16)                     -- 10 is SlotType Ore
  notOreOperation = ic.bit_or(notOreOperation, ic.bit_sll(3, 8)) -- 3 is for "notEquals"
  notOreOperation = ic.bit_or(notOreOperation, 4)                -- 4 is for FilterSlotTypeCompare
  -- Always clear mem before write
  ic.mem_clear_id(sorter)
  ic.mem_put_id(sorter, 1, notOreOperation)
end

local function initGasesSorter()
  local sorter = ic.find("Logic Sorter-Gases")
  powerAndLock(sorter)
  ic.mem_clear_id(sorter)

  --- gases
  for index, value in ipairs(GASES_ORES) do   -- Also add ReagentMix
    local operation = ic.bit_sll(hash("Item" .. value), 8)
    local operation = ic.bit_or(operation, 1) -- 1 is for prefabHash match
    ic.mem_put_id(sorter, index, operation)
  end
  -- Set mode to ANY
  ic.write_id(sorter, LT.Mode, 1)
end

local function initSiloValves()
  for _, value in ipairs(ORES) do
    local valve = ic.find(SILO_CHUTE_VALVE_BASE_NAME .. value)
    if valve == nil then
      print(string.format("Init error: Chute Valve %s not found", value))
      break
    end
    powerAndLock(valve)
    ic.write_id(valve, LT.Open, 0)
    ic.write_id(valve, LT.Setting, 0)
  end
end

initSiloValves()
initOreSorters()
initUnloader()
initGasesSorter()
