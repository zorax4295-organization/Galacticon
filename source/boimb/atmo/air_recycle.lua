-------------------------------
-- AIR RECYCLE — STATE MACHINE
-------------------------------
-- States:
--   HALTED          : missing devices, script paused
--   MAINTENANCE     : manual override, all vents off/unlocked
--   PANIC           : toxic gas detected, depressurizing
--   PANIC_BLOCKED   : toxic gas + waste full, all flow stopped
--   WASTE_FULL      : waste full, filtration suspended
--   DEPRESSURIZING  : base overpressure, venting out
--   NOMINAL         : air OK, monitoring
--   CO2_FILTRATION  : CO2 excess only, light extraction
--   FULL_FILTRATION : multiple gases off, full recycle cycle
-------------------------------

local LT                           = ic.enums.LogicType
local LBM                          = ic.enums.LogicBatchMethod
local GAS_SENSOR_PREFAB_HASH       = hash("StructureGasSensor")
local GAS_SENSOR_NAME_HASH         = hash("Gas Sensor-Base")
local ACTIVE_VENT_PREFAB_HASH      = hash("StructureActiveVent")
local POWERED_VENT_PREFAB_HASH     = hash("StructurePoweredVent")
local VENT_OUT_HASH                = hash("Base Vent OUT")
local VENT_IN_HASH                 = hash("Base Vent IN")

local VALVE_CO2_FILTRATION_IN_NAME = "Digital Valve-CO2 Filtration IN"
local PUMP_CO2_FILTRATION_OUT_NAME = "Pump-Base CO2 Filtration OUT"
local PUMP_CO2_EVACUATION_NAME     = "Pump-Filtration CO2 out"
local VALVE_MAIN_FILTRATION_NAME   = "Digital Valve-Main Filtration"
local FILTRATION_CO2_BASE_NAME     = "Filtration CO2 Base"

local HYSTERESIS                   = 0.05
local CO2_LIGHT_VENT_OUT_PRESSURE  = 88
local MAX_WASTE_PRESSURE           = 40000
local WASTE_RESUME_PRESSURE        = 20000
local MIN_BREATHABLE_AIR_PRESSURE  = 1000
local MIN_BASE_AIR_PRESSURE        = 80
local MIN_FILTRATION_BASE_PRESSURE = 60
local MIN_BASE_AIR_PRESSURE_TOXIC  = 0
local MAX_BASE_AIR_PRESSURE        = 90

local ACCEPTABLE_VALUES            = {
  { shortName = "O2",  longName = "Oxygen",        expected = 0.3,  isToxic = false },
  { shortName = "CO2", longName = "CarbonDioxide", expected = 0.02, isToxic = false },
  { shortName = "N",   longName = "Nitrogen",      expected = 0.68, isToxic = false },
  { shortName = "H2",  longName = "Hydrogen",      expected = 0,    isToxic = true },
  { shortName = "CH4", longName = "Methane",       expected = 0,    isToxic = true },
  { shortName = "POL", longName = "Pollutant",     expected = 0,    isToxic = true },
  { shortName = "N2O", longName = "NitrousOxide",  expected = 0,    isToxic = true },
}

-------------------------------
-- HARDWARE HELPERS
-------------------------------

local function setCO2Filtration(On)
  local valveIn   = ic.find(VALVE_CO2_FILTRATION_IN_NAME)
  local pumpOut   = ic.find(PUMP_CO2_FILTRATION_OUT_NAME)
  local pumpEvac  = ic.find(PUMP_CO2_EVACUATION_NAME)
  local valveMain = ic.find(VALVE_MAIN_FILTRATION_NAME)
  local scrubber  = ic.find(FILTRATION_CO2_BASE_NAME)
  if valveIn then ic.write_id(valveIn, LT.On, On) end
  if pumpOut then ic.write_id(pumpOut, LT.On, On) end
  if pumpEvac then ic.write_id(pumpEvac, LT.On, On) end
  if valveMain then ic.write_id(valveMain, LT.On, 1 - On) end -- inverse: closed during light mode
  if scrubber then ic.write_id(scrubber, LT.On, On) end
  if On == 1 then
    -- Light mode: only the ACTIVE_VENT OUT runs at a softer extraction threshold
    ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 0)
    ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 1)
    ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.PressureExternal, CO2_LIGHT_VENT_OUT_PRESSURE)
  else
    -- Restore VENT OUT pressure threshold; On/Off managed by setFiltration
    ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.PressureExternal, MIN_BASE_AIR_PRESSURE)
  end
end

local function initVents()
  -- VENTS OUT
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.Mode, 1)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.Mode, 1)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.PressureInternal, MAX_WASTE_PRESSURE)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.PressureExternal, MIN_BASE_AIR_PRESSURE)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.PressureExternal, MIN_BASE_AIR_PRESSURE)
  -- VENTS IN
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.Mode, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.Mode, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.PressureInternal, MIN_BREATHABLE_AIR_PRESSURE)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.PressureExternal, MAX_BASE_AIR_PRESSURE)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.PressureExternal, MAX_BASE_AIR_PRESSURE)
  -- Default: pressurize
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 1)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 1)
  setCO2Filtration(0)
end

local function stopVentsIn()
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.PressureExternal, MIN_BASE_AIR_PRESSURE_TOXIC)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.PressureExternal, MIN_BASE_AIR_PRESSURE_TOXIC)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
end

local function setPanicMode()
  setCO2Filtration(0)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.PressureExternal, MIN_BASE_AIR_PRESSURE_TOXIC)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.PressureExternal, MIN_BASE_AIR_PRESSURE_TOXIC)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 1)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 1)
  stopVentsIn()
end

local function setFiltration(On)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, On)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, On)
end

local function depressurize()
  setCO2Filtration(0)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 1)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 1)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
end

local function safetyShutdown()
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 0)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.Lock, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.Lock, 0)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.Lock, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.Lock, 0)
  for _, name in ipairs({ VALVE_CO2_FILTRATION_IN_NAME, PUMP_CO2_FILTRATION_OUT_NAME,
    PUMP_CO2_EVACUATION_NAME, VALVE_MAIN_FILTRATION_NAME,
    FILTRATION_CO2_BASE_NAME }) do
    local device = ic.find(name)
    if device then
      ic.write_id(device, LT.On, 0)
      ic.write_id(device, LT.Lock, 0)
    end
  end
end

-------------------------------
-- DEVICE CHECK
-------------------------------

local REQUIRED_DEVICES = {
  "Gas Sensor-Base",
  "Base Vent OUT",
  "Base Vent IN",
  VALVE_CO2_FILTRATION_IN_NAME,
  PUMP_CO2_FILTRATION_OUT_NAME,
  PUMP_CO2_EVACUATION_NAME,
  VALVE_MAIN_FILTRATION_NAME,
  FILTRATION_CO2_BASE_NAME,
}

local function checkDevices()
  local missing = {}
  for _, name in ipairs(REQUIRED_DEVICES) do
    if not ic.find(name) then
      missing[#missing + 1] = name
    end
  end
  return missing
end

-------------------------------
-- GAS ANALYSIS
-------------------------------

-- Reads sensor ratios and returns a named analysis table:
--   airIsOK, airIsToxic, anyGasTooHigh, anyGasInRangeWhileFiltering,
--   co2TooHigh, co2InRangeWhileCO2Filtering, anyOtherGasOff,
--   results = { { shortName, measured, minOK, maxOK, status, isToxic }, ... }
-- currentState is passed so hysteresis logic knows whether filtration is active.
local function analyzeGases(currentState)
  local isFiltering                 = (currentState == "FULL_FILTRATION")
  local isCO2Filtering              = (currentState == "CO2_FILTRATION")

  local airIsOK                     = true
  local airIsToxic                  = false
  local anyGasTooHigh               = false
  local anyGasInRangeWhileFiltering = false
  local co2TooHigh                  = false
  local co2InRangeWhileCO2Filtering = false
  local anyOtherGasOff              = false
  local results                     = {}

  for _, value in ipairs(ACCEPTABLE_VALUES) do
    local ratioName = string.format("Ratio%s", value.longName)
    local measured  = ic.batch_read_name(GAS_SENSOR_PREFAB_HASH, GAS_SENSOR_NAME_HASH, LT[ratioName], LBM.Average)
    local status, minOK, maxOK

    if value.isToxic then
      status = (measured > 0) and 1 or 0
      minOK, maxOK = 0, 0
    else
      local variance = value.expected * HYSTERESIS
      minOK = value.expected - variance
      maxOK = value.expected + variance
      if measured > maxOK then
        status = 1
      elseif measured < minOK then
        status = 2
      else
        status = 0
      end
    end

    results[#results + 1] = {
      shortName = value.shortName,
      measured  = measured,
      minOK     = minOK,
      maxOK     = maxOK,
      status    = status,
      isToxic   = value.isToxic,
    }

    if status == 0 then
      if isFiltering and not value.isToxic and measured > value.expected then
        -- In range but full filtration is active: keep going until gas reaches expected value
        airIsOK = false
        anyGasInRangeWhileFiltering = true
      elseif isCO2Filtering and value.shortName == "CO2" and measured > value.expected then
        -- CO2 still above target during light filtration: keep going until it reaches expected
        airIsOK = false
        co2InRangeWhileCO2Filtering = true
      end
    elseif status == 1 then
      if value.isToxic then
        airIsToxic = true
        airIsOK    = false
        break
      else
        airIsOK       = false
        anyGasTooHigh = true
        if value.shortName == "CO2" then
          co2TooHigh = true
        else
          anyOtherGasOff = true
        end
      end
    elseif status == 2 then
      airIsOK = false
      if not value.isToxic then
        anyOtherGasOff = true
      end
    end
  end

  return {
    airIsOK                     = airIsOK,
    airIsToxic                  = airIsToxic,
    anyGasTooHigh               = anyGasTooHigh,
    anyGasInRangeWhileFiltering = anyGasInRangeWhileFiltering,
    co2TooHigh                  = co2TooHigh,
    co2InRangeWhileCO2Filtering = co2InRangeWhileCO2Filtering,
    anyOtherGasOff              = anyOtherGasOff,
    results                     = results,
  }
end

-------------------------------
-- STATE MACHINE
-------------------------------

local STATE              = {
  HALTED          = "HALTED",
  MAINTENANCE     = "MAINTENANCE",
  PANIC           = "PANIC",
  PANIC_BLOCKED   = "PANIC_BLOCKED",
  WASTE_FULL      = "WASTE_FULL",
  DEPRESSURIZING  = "DEPRESSURIZING",
  NOMINAL         = "NOMINAL",
  CO2_FILTRATION  = "CO2_FILTRATION",
  FULL_FILTRATION = "FULL_FILTRATION",
}

-- Integer codes written to the shared "Air Recycle State" memory chip each tick.
-- air_dashboard.lua reads these to display the current state.
local STATE_CODES        = {
  HALTED          = 0,
  NOMINAL         = 1,
  CO2_FILTRATION  = 2,
  FULL_FILTRATION = 3,
  MAINTENANCE     = 4,
  DEPRESSURIZING  = 5,
  WASTE_FULL      = 6,
  PANIC_BLOCKED   = 7,
  PANIC           = 8,
}
local STATE_MEMORY_NAME  = "Air Recycle State"

local currentState       = nil
local lastEvent          = "Script started"
local missingDevicesList = {}
local stateMem           = nil  -- handle to the shared memory chip, cached after first find

-- Forward-declared so state closures can call it
local transition

-- Each entry: enter() sets hardware for the state, exit() is called on departure,
-- tick(gas, wastePressure, basePressure) returns (newState, reason) or nothing.
local states             = {

  [STATE.HALTED] = {
    enter = function()
      safetyShutdown()
      print("[SAFETY] Script halted — missing devices:")
      for _, name in ipairs(missingDevicesList) do
        print(string.format("  - %s", name))
      end
    end,
    tick = function()
      -- Re-check each cycle in case hardware is reconnected
      local missing = checkDevices()
      if #missing == 0 then
        return STATE.NOMINAL, "All devices found — resuming"
      end
      missingDevicesList = missing
    end,
  },

  [STATE.MAINTENANCE] = {
    enter = function()
      setCO2Filtration(0)
      -- Unlock and shut off all vents for manual control
      ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.Lock, 0)
      ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.Lock, 0)
      ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.Lock, 0)
      ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.Lock, 0)
      ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 0)
      ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 0)
      ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
      ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
    end,
    exit = function()
      initVents()
    end,
    tick = function()
      local maintenanceOn = 0 -- ic.read(1, LT.Activate)
      if maintenanceOn == 0 then
        return STATE.NOMINAL, "Maintenance OFF — nominal restored"
      end
    end,
  },

  [STATE.PANIC] = {
    enter = function()
      setPanicMode()
    end,
    exit = function()
      initVents()
    end,
    tick = function(gas, wastePressure)
      if wastePressure >= MAX_WASTE_PRESSURE then
        return STATE.PANIC_BLOCKED, "PANIC — waste tank full, exhaust blocked"
      end
      if not gas.airIsToxic then
        return STATE.NOMINAL, "Recovery — toxic gas cleared"
      end
    end,
  },

  [STATE.PANIC_BLOCKED] = {
    enter = function()
      -- Cannot exhaust: stop all flow and wait for waste to drain
      setCO2Filtration(0)
      setFiltration(0)
      stopVentsIn()
    end,
    tick = function(gas, wastePressure)
      if not gas.airIsToxic then
        return STATE.NOMINAL, "Recovery — toxic gas cleared (waste full path)"
      end
      if wastePressure < WASTE_RESUME_PRESSURE then
        return STATE.PANIC, string.format("Waste drained (%.0f kPa) — resuming exhaust", wastePressure)
      end
    end,
  },

  [STATE.WASTE_FULL] = {
    enter = function()
      setCO2Filtration(0)
      setFiltration(0)
    end,
    tick = function(gas, wastePressure)
      if gas.airIsToxic then
        return STATE.PANIC_BLOCKED, "PANIC — toxic gas (waste full)"
      end
      if wastePressure < WASTE_RESUME_PRESSURE then
        return STATE.NOMINAL, string.format("Waste drained (%.0f kPa) — resuming", wastePressure)
      end
    end,
  },

  [STATE.DEPRESSURIZING] = {
    enter = function()
      depressurize()
    end,
    exit = function()
      initVents()
    end,
    tick = function(gas, wastePressure, basePressure)
      if gas.airIsToxic then
        return STATE.PANIC, "PANIC — toxic gas during depressurization"
      end
      if wastePressure >= MAX_WASTE_PRESSURE then
        return STATE.WASTE_FULL, "Waste full during depressurization"
      end
      if basePressure <= MAX_BASE_AIR_PRESSURE then
        return STATE.NOMINAL, string.format("Pressure nominal (%.0f kPa) — recovery", basePressure)
      end
    end,
  },

  [STATE.NOMINAL] = {
    enter = function()
      setFiltration(0)
    end,
    tick = function(gas, wastePressure, basePressure)
      -- Priority: toxic > waste > overpressure > maintenance > filtration need
      if gas.airIsToxic then
        if wastePressure >= MAX_WASTE_PRESSURE then
          return STATE.PANIC_BLOCKED, "PANIC — toxic gas + waste full"
        end
        return STATE.PANIC, "PANIC — toxic gas detected"
      end
      if wastePressure >= MAX_WASTE_PRESSURE then
        return STATE.WASTE_FULL, string.format("Waste tank full (%.0f kPa)", wastePressure)
      end
      if basePressure > MAX_BASE_AIR_PRESSURE then
        return STATE.DEPRESSURIZING, string.format("Overpressure (%.0f kPa)", basePressure)
      end
      local maintenanceOn = 0 -- ic.read(1, LT.Activate)
      if maintenanceOn == 1 then
        return STATE.MAINTENANCE, "Maintenance ON"
      end
      -- Light CO2 filtration: CO2 is the only gas above its upper bound
      if gas.co2TooHigh and not gas.anyOtherGasOff then
        return STATE.CO2_FILTRATION, "CO2 excess — light filtration"
      end
      -- Full filtration: any non-toxic gas out of range
      if gas.anyOtherGasOff then
        return STATE.FULL_FILTRATION, "Gas ratio off — full filtration"
      end
    end,
  },

  [STATE.CO2_FILTRATION] = {
    enter = function()
      setCO2Filtration(1)
    end,
    exit = function()
      setCO2Filtration(0)
    end,
    tick = function(gas, wastePressure)
      if gas.airIsToxic then
        if wastePressure >= MAX_WASTE_PRESSURE then
          return STATE.PANIC_BLOCKED, "PANIC — toxic gas + waste full"
        end
        return STATE.PANIC, "PANIC — toxic gas detected"
      end
      if wastePressure >= MAX_WASTE_PRESSURE then
        return STATE.WASTE_FULL, string.format("Waste tank full (%.0f kPa)", wastePressure)
      end
      if gas.anyOtherGasOff then
        return STATE.FULL_FILTRATION, "CO2 light → full filtration (other gas out of range)"
      end
      if not gas.co2TooHigh and not gas.co2InRangeWhileCO2Filtering then
        return STATE.NOMINAL, "CO2 light filtration done (CO2 at lower bound)"
      end
    end,
  },

  [STATE.FULL_FILTRATION] = {
    enter = function()
      setFiltration(1)
    end,
    exit = function()
      setFiltration(0)
    end,
    tick = function(gas, wastePressure, basePressure)
      if gas.airIsToxic then
        if wastePressure >= MAX_WASTE_PRESSURE then
          return STATE.PANIC_BLOCKED, "PANIC — toxic gas + waste full"
        end
        return STATE.PANIC, "PANIC — toxic gas detected"
      end
      if wastePressure >= MAX_WASTE_PRESSURE then
        return STATE.WASTE_FULL, string.format("Waste tank full (%.0f kPa)", wastePressure)
      end
      if basePressure <= MIN_FILTRATION_BASE_PRESSURE then
        return STATE.NOMINAL, string.format("Base pressure too low (%.0f kPa) — filtration suspended", basePressure)
      end
      if not gas.anyGasTooHigh and not gas.anyGasInRangeWhileFiltering then
        return STATE.NOMINAL, "Full filtration done — all gases nominal"
      end
    end,
  },
}

transition               = function(newState, reason)
  local s = states[currentState]
  if s and s.exit then s.exit() end
  lastEvent    = reason or newState
  currentState = newState
  print(string.format("[TRANSITION] → %s  (%s)", newState, lastEvent))
  s = states[currentState]
  if s and s.enter then s.enter() end
end

-------------------------------
-- LOGGING
-------------------------------

local function printStatus(gas, wastePressure, basePressure)
  print("========================================")
  print(string.format("  STATE: %s", currentState))
  print(string.format("  SINCE: %s", lastEvent))
  print("  ---- PRESSURES")
  print(string.format("  Base:   %8.2f kPa   [%d - %d kPa]",
    basePressure, MIN_BASE_AIR_PRESSURE, MAX_BASE_AIR_PRESSURE))
  print(string.format("  Waste:  %8.2f kPa   [limit: %d | resume: %d]",
    wastePressure, MAX_WASTE_PRESSURE, WASTE_RESUME_PRESSURE))
  if currentState == STATE.HALTED then
    print("  ---- MISSING DEVICES")
    for _, name in ipairs(missingDevicesList) do
      print(string.format("  - %s", name))
    end
  end
  if gas and #gas.results > 0 then
    print("  ---- GAS RATIOS")
    for _, r in ipairs(gas.results) do
      local statusStr
      if r.status == 0 then
        local filtering = (currentState == STATE.FULL_FILTRATION and not r.isToxic)
            or (currentState == STATE.CO2_FILTRATION and r.shortName == "CO2")
        statusStr = filtering and "in range (filtering)" or "OK"
      elseif r.status == 1 then
        statusStr = r.isToxic and "!! TOXIC !!" or "HIGH"
      else
        statusStr = "LOW"
      end
      if r.isToxic then
        print(string.format("  %-4s  %.4f   [must be 0]              %s",
          r.shortName, r.measured, statusStr))
      else
        print(string.format("  %-4s  %.4f   [%.4f - %.4f]   %s",
          r.shortName, r.measured, r.minOK, r.maxOK, statusStr))
      end
    end
  end
  print("========================================")
end

-------------------------------
-- BOOT
-------------------------------

initVents()
local missingDevices = checkDevices()
if #missingDevices > 0 then
  missingDevicesList = missingDevices
  currentState = STATE.HALTED
  states[STATE.HALTED].enter()
else
  currentState = STATE.NOMINAL
  states[STATE.NOMINAL].enter()
  lastEvent = "Script started"
end

-------------------------------
-- MAIN LOOP
-------------------------------

while true do
  local wastePressure = ic.read(0, LT.Pressure)
  ic.write(2, LT.Mode, 14)
  ic.write(2, LT.Setting, wastePressure)
  local basePressure = ic.batch_read_name(GAS_SENSOR_PREFAB_HASH, GAS_SENSOR_NAME_HASH, LT.Pressure, LBM.Average)

  local gas = analyzeGases(currentState)

  local nextState, reason = states[currentState].tick(gas, wastePressure, basePressure)
  if nextState then
    transition(nextState, reason)
  end

  -- Publish state code to the shared memory chip for air_dashboard.lua
  if not stateMem then stateMem = ic.find(STATE_MEMORY_NAME) end
  if stateMem then
    ic.write_id(stateMem, LT.Setting, STATE_CODES[currentState] or 0)
  end

  printStatus(gas, wastePressure, basePressure)
  yield()
end
