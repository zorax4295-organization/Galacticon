-------------------------------
-- SETUP
--- waste analyzer sur d0
-------------------------------
-- Règles générales
--- Vent coupée si Pression ds la base < 80kpa
--- Vent coupée si Pression Waste > 45Mpa
--- Vent coupée si réserve d'air pure < 1Mpa
---
--- Vent se met en route si en dehors de la plage
---
--- Panic mode: gaz dangereux => depressurisation totale.
---


local LT                            = ic.enums.LogicType
local LBM                           = ic.enums.LogicBatchMethod
local GAS_SENSOR_PREFAB_HASH        = hash("StructureGasSensor")
local GAS_SENSOR_NAME_HASH          = hash("Gas Sensor-Base")
local ACTIVE_VENT_PREFAB_HASH       = hash("StructureActiveVent")
local POWERED_VENT_PREFAB_HASH      = hash("StructurePoweredVent")
local VENT_OUT_HASH                 = hash("Base Vent OUT")
local VENT_IN_HASH                  = hash("Base Vent IN")

local VALVE_CO2_FILTRATION_IN_NAME  = "Digital Valve-CO2 Filtration IN"
local PUMP_CO2_FILTRATION_OUT_NAME  = "Pump-Base CO2 Filtration OUT"
local PUMP_CO2_EVACUATION_NAME      = "Pump-Filtration CO2 out"
local VALVE_MAIN_FILTRATION_NAME    = "Digital Valve-Main Filtration"
local FILTRATION_CO2_BASE_NAME      = "Filtration CO2 Base"

local HYSTERESIS                    = 0.05
local CO2_LIGHT_VENT_OUT_PRESSURE   = 88
local MAX_WASTE_PRESSURE            = 40000
local WASTE_RESUME_PRESSURE         = 20000
local MIN_BREATHABLE_AIR_PRESSURE   = 1000
local MIN_BASE_AIR_PRESSURE         = 80
local MIN_BASE_AIR_PRESSURE_TOXIC   = 0
local MAX_BASE_AIR_PRESSURE         = 90

local ACCEPTABLE_VALUES             = {
  { shortName = "O2",  longName = "Oxygen",        expected = 0.3,  isToxic = false },
  { shortName = "CO2", longName = "CarbonDioxide", expected = 0.02, isToxic = false },
  { shortName = "N",   longName = "Nitrogen",      expected = 0.68, isToxic = false },
  { shortName = "H2",  longName = "Hydrogen",      expected = 0,    isToxic = true },
  { shortName = "CH4", longName = "Methane",       expected = 0,    isToxic = true },
  { shortName = "POL", longName = "Pollutant",     expected = 0,    isToxic = true },
  { shortName = "N2O", longName = "NitrousOxide",  expected = 0,    isToxic = true },
}

local function setCO2Filtration(On)
  local valveIn    = ic.find(VALVE_CO2_FILTRATION_IN_NAME)
  local pumpOut    = ic.find(PUMP_CO2_FILTRATION_OUT_NAME)
  local pumpEvac   = ic.find(PUMP_CO2_EVACUATION_NAME)
  local valveMain  = ic.find(VALVE_MAIN_FILTRATION_NAME)
  local scrubber   = ic.find(FILTRATION_CO2_BASE_NAME)
  if valveIn   then ic.write_id(valveIn,   LT.On, On)     end
  if pumpOut   then ic.write_id(pumpOut,   LT.On, On)     end
  if pumpEvac  then ic.write_id(pumpEvac,  LT.On, On)     end
  if valveMain then ic.write_id(valveMain, LT.On, 1 - On) end  -- inverse: closed during light mode, open otherwise
  if scrubber  then ic.write_id(scrubber,  LT.On, On)     end
  if On == 1 then
    -- Light mode: only ACTIVE_VENT OUT runs at a softer extraction threshold
    ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 0)
    ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 1)
    ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.PressureExternal, CO2_LIGHT_VENT_OUT_PRESSURE)
  else
    -- Restore VENT OUT pressure threshold; On/Off is managed by setFiltration
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

  -- DEFAULT TO PRESSURIZE
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 1)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 1)

  -- Ensure CO2 light filtration valves start closed
  setCO2Filtration(0)
end

local function stopVentsIn()
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.PressureExternal, MIN_BASE_AIR_PRESSURE_TOXIC)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.PressureExternal, MIN_BASE_AIR_PRESSURE_TOXIC)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
end

local function setPanicMode()
  -- Close CO2 light filtration immediately — toxic air must not be reinjected into the base
  setCO2Filtration(0)

  -- VENTS OUT — force on and exhaust to zero
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

local function toggleMaintenance(maintenanceState, alreadyInMaintenance)
  if alreadyInMaintenance then
    if maintenanceState == 0 then
      return false
    else
      return true
    end
  else
    if maintenanceState == 1 then
      setCO2Filtration(0)
      ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.Lock, 0)
      ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.Lock, 0)
      ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.Lock, 0)
      ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.Lock, 0)

      ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 0)
      ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 0)
      ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
      ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
      return true
    else
      return false
    end
  end
end

-- Check if gasRatio is acceptable.
-- Returns: status (0=OK, 1=too high, 2=too low), measuredRatio, minOKValue, maxOKValue
-- Toxic gases (isToxic=true) use strict zero-tolerance: any nonzero trace is status 1.
local function checkGas(gasProps)
  local ratioName = string.format("Ratio%s", gasProps.longName)
  local measuredRatio = ic.batch_read_name(GAS_SENSOR_PREFAB_HASH, GAS_SENSOR_NAME_HASH, LT[ratioName], LBM.Average)

  if gasProps.isToxic then
    if measuredRatio > 0 then
      return 1, measuredRatio, 0, 0
    end
    return 0, measuredRatio, 0, 0
  end

  local variance = gasProps.expected * HYSTERESIS
  local minOKValue = gasProps.expected - variance
  local maxOKValue = gasProps.expected + variance

  if measuredRatio > maxOKValue then
    return 1, measuredRatio, minOKValue, maxOKValue
  end
  if measuredRatio < minOKValue then
    return 2, measuredRatio, minOKValue, maxOKValue
  end
  return 0, measuredRatio, minOKValue, maxOKValue
end

local function depressurize()
  -- Push air out and stop bringing more in
  setCO2Filtration(0)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 1)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On, 1)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH, VENT_IN_HASH, LT.On, 0)
end

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

local function safetyShutdown()
  -- Turn off and unlock all vents
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.On,   0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH,  VENT_OUT_HASH, LT.On,   0)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH,  LT.On,   0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH,  VENT_IN_HASH,  LT.On,   0)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_OUT_HASH, LT.Lock, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH,  VENT_OUT_HASH, LT.Lock, 0)
  ic.batch_write_name(POWERED_VENT_PREFAB_HASH, VENT_IN_HASH,  LT.Lock, 0)
  ic.batch_write_name(ACTIVE_VENT_PREFAB_HASH,  VENT_IN_HASH,  LT.Lock, 0)
  -- Turn off and unlock CO2 circuit devices
  for _, name in ipairs({ VALVE_CO2_FILTRATION_IN_NAME, PUMP_CO2_FILTRATION_OUT_NAME,
                          PUMP_CO2_EVACUATION_NAME, VALVE_MAIN_FILTRATION_NAME,
                          FILTRATION_CO2_BASE_NAME }) do
    local device = ic.find(name)
    if device then
      ic.write_id(device, LT.On,   0)
      ic.write_id(device, LT.Lock, 0)
    end
  end
end

-------------------------------
initVents()
local missingDevices = checkDevices()
if #missingDevices > 0 then
  safetyShutdown()
  while true do
    print("[SAFETY] Script halted — missing devices:")
    for _, name in ipairs(missingDevices) do
      print(string.format("  - %s", name))
    end
    yield()
  end
end

local alreadyInMaintenance = false
local wasInSpecialMode = false
local isFiltering = false
local isCO2Filtering = false
local wasteFull = false
local lastEvent = "Script started"

while true do
  local airIsOK = true
  local airIsToxic = false
  local anyGasTooHigh = false
  local anyGasInRangeWhileFiltering = false
  local co2TooHigh = false
  local co2InRangeWhileCO2Filtering = false
  local anyOtherGasOff = false
  local gasResults = {}

  local wastePressure = ic.read(0, LT.Pressure)
  ic.write(2, LT.Mode, 14)
  ic.write(2, LT.Setting, wastePressure)
  local basePressure = ic.batch_read_name(GAS_SENSOR_PREFAB_HASH, GAS_SENSOR_NAME_HASH, LT.Pressure, LBM.Average)

  -------------------------------
  -- MAINTENANCE MODE
  -------------------------------
  -- local maintenanceOn = ic.read(1, LT.Activate)
  local maintenanceOn = 0
  if maintenanceOn == 1 then
    if not alreadyInMaintenance then lastEvent = "Maintenance ON" end
    alreadyInMaintenance = toggleMaintenance(maintenanceOn, alreadyInMaintenance)
    goto done
  elseif alreadyInMaintenance then
    lastEvent = "Maintenance OFF"
    isCO2Filtering = false
    alreadyInMaintenance = false
  end

  -- Update waste state early so panic can check it below
  if wastePressure >= MAX_WASTE_PRESSURE then
    if not wasteFull then
      lastEvent = string.format("Waste tank full (%.0f kPa)", wastePressure)
    end
    wasteFull = true
  elseif wasteFull and wastePressure < WASTE_RESUME_PRESSURE then
    lastEvent = string.format("Waste tank drained (%.0f kPa)", wastePressure)
    wasteFull = false
  end

  -------------------------------
  -- GAS RATIO CHECK — always runs first, toxic detection cannot be skipped
  -------------------------------
  for _, value in ipairs(ACCEPTABLE_VALUES) do
    local gasCheckValue, measured, minOK, maxOK = checkGas(value)
    gasResults[#gasResults + 1] = {
      shortName = value.shortName,
      measured  = measured,
      minOK     = minOK,
      maxOK     = maxOK,
      status    = gasCheckValue,
      isToxic   = value.isToxic,
    }
    if gasCheckValue == 0 then
      if isFiltering and not value.isToxic then
        -- Within the acceptable band but full filtration is active: keep going until
        -- the ratio drops below the lower bound (expected - hysteresis).
        airIsOK = false
        anyGasInRangeWhileFiltering = true
      elseif isCO2Filtering and value.shortName == "CO2" then
        -- CO2 within range during light filtration: keep going toward lower bound
        airIsOK = false
        co2InRangeWhileCO2Filtering = true
      end
    elseif gasCheckValue == 1 then
      if value.isToxic then
        airIsToxic = true
        airIsOK = false
        break
      else
        airIsOK = false
        anyGasTooHigh = true
        if value.shortName == "CO2" then
          co2TooHigh = true
        else
          anyOtherGasOff = true
        end
      end
    elseif gasCheckValue == 2 then
      airIsOK = false
      if not value.isToxic then
        -- Too low for any non-toxic gas (including CO2) cannot be fixed by CO2 extraction
        anyOtherGasOff = true
      end
    end
  end

  -- Determine filtration mode (CO2 light filtration vs full filtration — mutually exclusive).
  -- Light mode: CO2 is the only gas above its upper bound, nothing else is out of range.
  --   → Open CO2 valves to extract the excess directly; O2 and N stay in the base circuit.
  -- Full mode: any other non-toxic gas is out of range, or CO2 is out of range alongside others.
  --   → Run the full separation/reconstitution cycle as before.
  if not airIsToxic then
    -- Light CO2 filtration state machine
    if co2TooHigh and not anyOtherGasOff and not isFiltering then
      if not isCO2Filtering then
        lastEvent = "CO2 light filtration started (CO2 excess)"
        isCO2Filtering = true
        setCO2Filtration(1)
      end
    elseif isCO2Filtering then
      if anyOtherGasOff then
        -- Another gas went off — CO2 extraction alone is not enough, switch to full filtration
        lastEvent = "CO2 light → full filtration (other gas out of range)"
        isCO2Filtering = false
        setCO2Filtration(0)
      elseif not co2TooHigh and not co2InRangeWhileCO2Filtering then
        lastEvent = "CO2 light filtration stopped (CO2 at lower bound)"
        isCO2Filtering = false
        setCO2Filtration(0)
      end
    end

    -- Full filtration state machine (only when not in light CO2 mode)
    if not isCO2Filtering then
      if anyOtherGasOff and not isFiltering then
        lastEvent = "Full filtration started"
        isFiltering = true
      elseif isFiltering and not anyGasTooHigh and not anyGasInRangeWhileFiltering then
        lastEvent = "Full filtration stopped (all gases nominal)"
        isFiltering = false
      end
    end
  end

  -------------------------------
  -- PANIC MODE
  -------------------------------
  if airIsToxic then
    if not wasteFull then
      lastEvent = "PANIC — toxic gas detected"
      setPanicMode()
    else
      -- Waste is full: cannot exhaust yet, but stop all vent flow immediately
      lastEvent = "PANIC — toxic gas + waste full"
      setCO2Filtration(0)
      setFiltration(0)
      stopVentsIn()
    end
    isCO2Filtering = false
    wasInSpecialMode = true
    goto done
  end

  -- Waste gate for normal filtration (after panic so toxic is always handled first)
  if wasteFull then
    isCO2Filtering = false
    isFiltering = false
    setCO2Filtration(0)
    setFiltration(0)
    goto done
  end

  -- Depressurize if basePressure too high
  if basePressure > MAX_BASE_AIR_PRESSURE then
    lastEvent = string.format("Overpressure depressurize (%.0f kPa)", basePressure)
    depressurize()
    isCO2Filtering = false
    wasInSpecialMode = true
    goto done
  end

  -- Restore vent config once after exiting panic or depressurize
  if wasInSpecialMode then
    lastEvent = "Recovery — nominal configuration restored"
    initVents()
    isCO2Filtering = false
    wasInSpecialMode = false
  end

  -------------------------------
  -- NORMAL MODE
  -------------------------------
  if isCO2Filtering then
    -- setCO2Filtration(1) already called on transition
  elseif airIsOK then
    setFiltration(0)
  else
    setFiltration(1)
  end

  ::done::

  -- Compute current mode label from state
  local modeLabel
  if alreadyInMaintenance then
    modeLabel = "MAINTENANCE"
  elseif airIsToxic and wasteFull then
    modeLabel = "PANIC (exhaust blocked — waste full)"
  elseif airIsToxic then
    modeLabel = "!! PANIC — TOXIC GAS !!"
  elseif wasteFull then
    modeLabel = "WASTE FULL"
  elseif wasInSpecialMode then
    modeLabel = "DEPRESSURIZING"
  elseif isCO2Filtering then
    modeLabel = "CO2 LIGHT FILTRATION"
  elseif isFiltering then
    modeLabel = "FULL FILTRATION"
  else
    modeLabel = "NOMINAL"
  end

  print("========================================")
  print(string.format("  MODE:  %s", modeLabel))
  print(string.format("  SINCE: %s", lastEvent))
  print("  ---- PRESSURES")
  print(string.format("  Base:   %8.2f kPa   [%d - %d kPa]",
    basePressure, MIN_BASE_AIR_PRESSURE, MAX_BASE_AIR_PRESSURE))
  print(string.format("  Waste:  %8.2f kPa   [limit: %d | resume: %d]",
    wastePressure, MAX_WASTE_PRESSURE, WASTE_RESUME_PRESSURE))
  if #gasResults > 0 then
    print("  ---- GAS RATIOS")
    for _, r in ipairs(gasResults) do
      local statusStr
      if r.status == 0 then
        if (isFiltering and not r.isToxic) or (isCO2Filtering and r.shortName == "CO2") then
          statusStr = "in range (filtering)"
        else
          statusStr = "OK"
        end
      elseif r.status == 1 then
        if r.isToxic then statusStr = "!! TOXIC !!" else statusStr = "HIGH" end
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

  yield()
end
