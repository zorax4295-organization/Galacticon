-------------------------------
-- CO2 SCRUBBER
--- d0: Active Vent (pulls base air into scrubber circuit)
--- d1: Enable/disable switch (optional, leave disconnected to always run)
-------------------------------
-- Purpose
--- Day-to-day CO2 management via a dedicated gas filter circuit.
--- Runs continuously and independently from base_air.lua.
--- Thresholds are tighter than base_air.lua so the scrubber handles
--- chronic CO2 drift from crew respiration without ever triggering
--- the base-wide filtration system.
---
--- base_air.lua CO2 band : [0.0190, 0.0210]  <- safety fallback
--- scrubber CO2 band     :   [0.0195, 0.0205] <- day-to-day target
---
-- Circuit
---   Base room
---      └─ Active Vent (d0) ─ [pressure buffer] ─ Gas Filter (CO2)
---                                                      ├─ CO2 ──> Waste
---                                                      └─ N2/O2 > Passive Vent > Base room
-------------------------------

local LT                     = ic.enums.LogicType
local LBM                    = ic.enums.LogicBatchMethod
local GAS_SENSOR_PREFAB_HASH = hash("StructureGasSensor")
local GAS_SENSOR_NAME_HASH   = hash("Gas Sensor-Base")

-- Scrubber thresholds — must stay inside base_air.lua's [0.0190, 0.0210] band
-- Start scrubbing when CO2 rises above this
local CO2_SCRUB_START = 0.0205
-- Stop scrubbing only once CO2 drops below this (hysteresis)
local CO2_SCRUB_STOP  = 0.0195

local scrubbing = false

while true do
  -- Check enable switch on d1 (skip if nothing connected — defaults to 0 which means always run)
  local switchOff = ic.valid(1) and ic.read(1, LT.Activate) == 0
  if switchOff then
    ic.write(0, LT.On, 0)
    print("[CO2 Scrubber] Disabled by switch")
    goto done
  end

  local co2 = ic.batch_read_name(GAS_SENSOR_PREFAB_HASH, GAS_SENSOR_NAME_HASH, LT.RatioCarbonDioxide, LBM.Average)

  -- Hysteresis: start above CO2_SCRUB_START, stop only below CO2_SCRUB_STOP
  if co2 > CO2_SCRUB_START and not scrubbing then
    scrubbing = true
    print(string.format("[CO2 Scrubber] CO2 %.4f > %.4f — starting scrub", co2, CO2_SCRUB_START))
  elseif co2 < CO2_SCRUB_STOP and scrubbing then
    scrubbing = false
    print(string.format("[CO2 Scrubber] CO2 %.4f < %.4f — target reached, stopping", co2, CO2_SCRUB_STOP))
  else
    print(string.format("[CO2 Scrubber] CO2 %.4f | scrubbing: %s | band: [%.4f, %.4f]",
      co2, scrubbing and "ON" or "off", CO2_SCRUB_STOP, CO2_SCRUB_START))
  end

  ic.write(0, LT.On, scrubbing and 1 or 0)

  ::done::
  yield()
end
