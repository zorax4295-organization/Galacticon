--[[
    AIR MIXER - PID version (all pumps run simultaneously)
    -------------------------------------------------------------
    Mixes O2, N2 and CO2 using turbo pumps with PID-based ratio
    control. All three pumps run in parallel every tick.

    PID logic is implemented entirely in Lua (see makePID /
    stepPID below). No PID Controller devices are needed.
    Note: Stationeers PID devices cannot have their Input field
    written from Lua (ic.write_id on LT.Input has no effect),
    so hardware PIDs are not usable for this purpose.

    Because moles pumped ~ Setting * P / (R * T), raw PID outputs
    are pressure-temperature corrected before being applied:

        corrected_X = raw_X * T_src_X / P_src_X

    All three corrected values are then normalised so the largest
    one = 100, ensuring the bottleneck pump always runs flat-out
    while the others are throttled to maintain exact mole ratios.

    Each gas has its own PID gains stored in the PID table. CO2
    uses higher gains because its small target fraction (2%) makes
    it more sensitive to the same absolute error magnitude.

    -- HARDWARE LAYOUT -------------------------------------------
    [O2 Tank]  --[Pipe Analyzer-O2]--[Air-Mix-TurboPump-O2]--+
    [N2 Tank]  --[Pipe Analyzer-N]---[Air-Mix-TurboPump-N]---+--[Pipe Analyzer-Breathable]--> Output
    [CO2 Tank] --[Pipe Analyzer-CO2]-[Air-Mix-TurboPump-CO2]-+

    Required devices (label them exactly as shown):
      - Pipe Analyzer-O2          (source side of O2 pump)
      - Pipe Analyzer-N           (source side of N pump)
      - Pipe Analyzer-CO2         (source side of CO2 pump)
      - Pipe Analyzer-Breathable  (output / mixing pipe)
      - Air-Mix-TurboPump-O2 / Air-Mix-TurboPump-N / Air-Mix-TurboPump-CO2

    -- DIFFERENCES FROM airMixer.lua ----------------------------
    - All three pumps run in parallel every tick (faster fill).
    - No PUMP_FLOW_L_PER_TICK constant needed; no calibration.
    - PID integral compensates source pressure drops automatically.
    - Anti-windup: integral is frozen while pumps are idle.
    - Pressure hysteresis: pumps stop at TARGET_PRESSURE and only
      restart below RESTART_PRESSURE, preventing pump chatter.
    - Derivative kick suppressed: prevErr is reset on pump restart
      so stale idle history does not spike the output.

    -- PID TUNING GUIDE ------------------------------------------
    Start with the defaults. If ratios oscillate (swing past
    target and back), reduce P_GAIN first, then D_GAIN.
    If a steady-state offset persists, increase I_GAIN slowly.

        P_GAIN  -> how hard pumps react to a ratio mismatch
        I_GAIN  -> eliminates persistent offset over time
        D_GAIN  -> braking force to prevent overshoot

    CO2 uses separate gains (P_GAIN_CO2 / I_GAIN_CO2 / D_GAIN_CO2)
    because its 2% target fraction makes the same absolute error
    proportionally much larger than for O2 or N2.
--]]

local LT                  = ic.enums.LogicType

-- -- CONFIG -----------------------------------------------------

-- Target molar fractions (must sum to 1.0)
local TARGET_O2           = 0.30 -- 30.0%  Oxygen
local TARGET_CO2          = 0.02 --  2.0%  Carbon Dioxide
local TARGET_N            = 0.68 -- 68.0%  Nitrogen

-- Stop filling when the output pipe reaches this pressure (kPa).
-- Only restart below RESTART_PRESSURE (hysteresis gap prevents
-- pump chatter when the output is near the target).
local TARGET_PRESSURE     = 40000
local RESTART_PRESSURE    = 38000

-- PID gains for O2 and N2.
-- A P_GAIN of 150 maps a full ratio error of 1.0 to output = 150,
-- which is immediately clamped to 100; at small errors (<0.05)
-- the I term is what drives the pump at steady state.
local P_GAIN              = 150
local I_GAIN              = 30
local D_GAIN              = 5

-- PID gains for CO2.
-- CO2 targets only 2%, so the same absolute error represents a
-- much larger relative deviation. Higher gains keep it tight.
local P_GAIN_CO2          = 200
local I_GAIN_CO2          = 50
local D_GAIN_CO2          = 5

-- Source tank pressure thresholds (kPa).
-- A pump shuts off when its source drops below MIN_SOURCE_PRESSURE and
-- only restarts once pressure recovers above MIN_SOURCE_RESUME.
-- The gap prevents rapid on/off chatter when a tank is nearly empty.
local MIN_SOURCE_PRESSURE = 1000
local MIN_SOURCE_RESUME   = 2000

-- -- DEVICES ----------------------------------------------------
local O2Anal              = ic.find("Pipe Analyzer-O2")
local NAnal               = ic.find("Pipe Analyzer-N")
local CO2Anal             = ic.find("Pipe Analyzer-CO2")
local AirAnal             = ic.find("Pipe Analyzer-Breathable") -- output/mixing pipe

local O2Pump              = ic.find("Air-Mix-TurboPump-O2")
local NPump               = ic.find("Air-Mix-TurboPump-N")
local CO2Pump             = ic.find("Air-Mix-TurboPump-CO2")

-- Validate: print a clear message and halt if a device is missing.
-- Uses an infinite yield loop instead of error() which may not be
-- available in the Stationeers Lua sandbox.
local function requireDevice(dev, label)
    if dev == nil then
        print("HALT: Device not found - check label in-game: " .. label)
        while true do yield() end
    end
end
requireDevice(O2Anal, "Pipe Analyzer-O2")
requireDevice(NAnal, "Pipe Analyzer-N")
requireDevice(CO2Anal, "Pipe Analyzer-CO2")
requireDevice(AirAnal, "Pipe Analyzer-Breathable")
requireDevice(O2Pump, "Air-Mix-TurboPump-O2")
requireDevice(NPump, "Air-Mix-TurboPump-N")
requireDevice(CO2Pump, "Air-Mix-TurboPump-CO2")

-- -- IN-CODE PID ------------------------------------------------

-- Create a new PID state table. Gains are stored per-PID so each
-- gas can be tuned independently.
local function makePID(setpoint, p, i, d)
    return { sp = setpoint, integral = 0, prevErr = 0, p = p, i = i, d = d }
end

-- Compute one PID tick.
-- Pass frozen=true when pumps are off to prevent integral windup.
local function stepPID(pid, measured, frozen)
    local err = pid.sp - measured
    local pd  = pid.p * err + pid.d * (err - pid.prevErr)

    if not frozen then
        pid.integral = pid.integral + err
        -- Anti-windup: only freeze integration when the integral itself
        -- pushes the output past the rail. When P+D alone already saturates,
        -- the integral is not the cause and should keep accumulating so it
        -- has the correct value once the large transient settles.
        local full = pd + pid.i * pid.integral
        if (full > 100 and pd <= 100 and err > 0) or
           (full < 0   and pd >= 0   and err < 0) then
            pid.integral = pid.integral - err
        end
    end

    pid.prevErr = err
    return math.max(0, math.min(100, pd + pid.i * pid.integral))
end

local pidO2  = makePID(TARGET_O2,  P_GAIN,     I_GAIN,     D_GAIN)
local pidN   = makePID(TARGET_N,   P_GAIN,     I_GAIN,     D_GAIN)
local pidCO2 = makePID(TARGET_CO2, P_GAIN_CO2, I_GAIN_CO2, D_GAIN_CO2)

ic.write_id(O2Pump, LT.On, 0)
ic.write_id(NPump, LT.On, 0)
ic.write_id(CO2Pump, LT.On, 0)

-- -- HELPERS ----------------------------------------------------

-- Safe read of pressure and temperature from a source analyzer.
local function readSource(analyzer)
    local p = ic.read_id(analyzer, LT.Pressure) or 0
    local t = ic.read_id(analyzer, LT.Temperature) or 293
    return p, t
end

-- Turn every pump off immediately.
local function stopAllPumps()
    ic.write_id(O2Pump, LT.On, 0)
    ic.write_id(NPump, LT.On, 0)
    ic.write_id(CO2Pump, LT.On, 0)
end

-- Check all pumps for error state (LT.Error = 1 means faulted).
-- Returns a description string if any pump is in error, nil otherwise.
local function pumpFault()
    if ic.read_id(O2Pump, LT.Error) == 1 then return "Air-Mix-TurboPump-O2 is in ERROR" end
    if ic.read_id(NPump, LT.Error) == 1 then return "Air-Mix-TurboPump-N is in ERROR" end
    if ic.read_id(CO2Pump, LT.Error) == 1 then return "Air-Mix-TurboPump-CO2 is in ERROR" end
    return nil
end

-- P/T correction and normalisation.
--
-- The pump delivers moles/tick ~ Setting * P / T.
-- The PID outputs a "desired mole contribution" (0-100).
-- To deliver the right moles regardless of source conditions:
--     Setting ~ desiredContribution * T / P
--
-- After correcting all three gases, normalise so the largest = 100
-- (run the bottleneck pump flat-out, throttle the others).
-- Returns corrected settings for O2, N, CO2 (each 0-100).
-- Returns 0, 0, 0 if all PID outputs are zero.
local function ptCorrectedSettings(rO2, rN, rCO2, pO2, tO2, pN, tN, pCO2, tCO2)
    local cO2  = (pO2 > 0) and rO2 * tO2 / pO2 or 0
    local cN   = (pN > 0) and rN * tN / pN or 0
    local cCO2 = (pCO2 > 0) and rCO2 * tCO2 / pCO2 or 0

    local maxC = math.max(cO2, cN, cCO2)
    if maxC <= 0 then return 0, 0, 0 end

    return cO2 / maxC * 100,
        cN / maxC * 100,
        cCO2 / maxC * 100
end

-- -- LOGGING ----------------------------------------------------

-- Print a bar that fills proportionally (0-100 -> 0-20 chars).
local function bar(value)
    local filled = math.floor(value / 5 + 0.5)
    return string.rep("|", filled) .. string.rep(".", 20 - filled)
end

local function sign(v) return v >= 0 and "+" or "" end

local function logState(outPress, ratioO2, ratioN, ratioCO2,
                        setO2, setN, setCO2,
                        rawO2, rawN, rawCO2,
                        pO2, tO2, pN, tN, pCO2, tCO2,
                        status)
    print("+----------------------------------------------+")
    print(string.format("|  OUTPUT  %7.1f / %7.1f kPa  [%s]",
        outPress, TARGET_PRESSURE, status))
    print("+----------------------------------------------+")
    print("|  Gas   Now     Target  Error   PIDout  Speed")
    print(string.format("|  O2   %5.2f%%  %5.2f%%  %s%.3f  %5.1f   %5.1f%%",
        ratioO2 * 100, TARGET_O2 * 100,
        sign(ratioO2 - TARGET_O2), ratioO2 - TARGET_O2, rawO2, setO2))
    print(string.format("|  N    %5.2f%%  %5.2f%%  %s%.3f  %5.1f   %5.1f%%",
        ratioN * 100, TARGET_N * 100,
        sign(ratioN - TARGET_N), ratioN - TARGET_N, rawN, setN))
    print(string.format("|  CO2  %5.2f%%  %5.2f%%  %s%.3f  %5.1f   %5.1f%%",
        ratioCO2 * 100, TARGET_CO2 * 100,
        sign(ratioCO2 - TARGET_CO2), ratioCO2 - TARGET_CO2, rawCO2, setCO2))
    print("+----------------------------------------------+")
    print("|  Source tanks")
    print(string.format("|  O2   %8.1f kPa  %6.1f K  [%s]", pO2, tO2, bar(setO2)))
    print(string.format("|  N    %8.1f kPa  %6.1f K  [%s]", pN, tN, bar(setN)))
    print(string.format("|  CO2  %8.1f kPa  %6.1f K  [%s]", pCO2, tCO2, bar(setCO2)))
    print("+----------------------------------------------+")
end

-- -- MAIN LOOP --------------------------------------------------

-- Hysteresis state: pumps only restart below RESTART_PRESSURE
-- after having stopped at TARGET_PRESSURE.
local pumpsRunning = false

-- Per-source hysteresis: each flag goes false when its tank drops
-- below MIN_SOURCE_PRESSURE and only returns to true above MIN_SOURCE_RESUME.
local srcOkO2  = true
local srcOkN   = true
local srcOkCO2 = true

-- Active state from the previous tick, used to detect restart transitions
-- and reset PID derivative history to prevent a kick.
local prevActive = false

while true do
    local fault = pumpFault()

    if fault then
        -- Fault: stop everything, reset state, log ---------------
        if prevActive then stopAllPumps() end  -- only on first fault tick
        pumpsRunning = false
        prevActive   = false
        srcOkO2  = true
        srcOkN   = true
        srcOkCO2 = true
        print("+----------------------------------------------+")
        print("|  !! FAULT - ALL PUMPS STOPPED              !!")
        print("|  " .. fault)
        print("|  Fix the issue then restart the script.")
        print("+----------------------------------------------+")
    else
        -- Normal operation ----------------------------------------
        local outPress = ic.read_id(AirAnal, LT.Pressure) or 0
        local ratioO2  = ic.read_id(AirAnal, LT.RatioOxygen) or 0
        local ratioN   = ic.read_id(AirAnal, LT.RatioNitrogen) or 0
        local ratioCO2 = ic.read_id(AirAnal, LT.RatioCarbonDioxide) or 0

        local pO2, tO2   = readSource(O2Anal)
        local pN, tN     = readSource(NAnal)
        local pCO2, tCO2 = readSource(CO2Anal)

        -- Update per-source hysteresis flags.
        if srcOkO2  then srcOkO2  = pO2  >= MIN_SOURCE_PRESSURE
                    else srcOkO2  = pO2  >= MIN_SOURCE_RESUME  end
        if srcOkN   then srcOkN   = pN   >= MIN_SOURCE_PRESSURE
                    else srcOkN   = pN   >= MIN_SOURCE_RESUME  end
        if srcOkCO2 then srcOkCO2 = pCO2 >= MIN_SOURCE_PRESSURE
                    else srcOkCO2 = pCO2 >= MIN_SOURCE_RESUME  end

        -- Hysteresis: stop at TARGET_PRESSURE, only restart below RESTART_PRESSURE.
        if pumpsRunning then
            pumpsRunning = outPress < TARGET_PRESSURE
        else
            pumpsRunning = outPress < RESTART_PRESSURE
        end

        -- All sources must be healthy for any pump to run.
        local allSrcOk = srcOkO2 and srcOkN and srcOkCO2
        local active   = pumpsRunning and allSrcOk

        -- Reset derivative history when resuming from any stopped state,
        -- to avoid a kick from stale error values accumulated while idle.
        if active and not prevActive then
            -- Seed prevErr with the current error so the derivative term
            -- is exactly zero on the first active tick (no kick on resume).
            pidO2.prevErr  = pidO2.sp  - ratioO2
            pidN.prevErr   = pidN.sp   - ratioN
            pidCO2.prevErr = pidCO2.sp - ratioCO2
            ic.write_id(O2Pump,  LT.On, 1)
            ic.write_id(NPump,   LT.On, 1)
            ic.write_id(CO2Pump, LT.On, 1)
        end

        if not active and prevActive then
            stopAllPumps()
        end

        -- Step PIDs. Frozen whenever pumps are not active.
        local rawO2  = stepPID(pidO2,  ratioO2,  not active)
        local rawN   = stepPID(pidN,   ratioN,   not active)
        local rawCO2 = stepPID(pidCO2, ratioCO2, not active)

        -- Always compute corrected settings so the log shows real
        -- values regardless of whether pumps are currently active.
        local setO2, setN, setCO2 = ptCorrectedSettings(
            rawO2, rawN, rawCO2,
            pO2, tO2, pN, tN, pCO2, tCO2
        )

        if active then
            ic.write_id(O2Pump,  LT.Setting, setO2)
            ic.write_id(NPump,   LT.Setting, setN)
            ic.write_id(CO2Pump, LT.Setting, setCO2)
        end

        local srcParts = {}
        if not srcOkO2  then srcParts[#srcParts+1] = "O2"  end
        if not srcOkN   then srcParts[#srcParts+1] = "N"   end
        if not srcOkCO2 then srcParts[#srcParts+1] = "CO2" end
        local srcStatus = #srcParts > 0 and ("LOW:" .. table.concat(srcParts, "+")) or nil
        local status    = active and "FILLING" or srcStatus or "IDLE   "

        logState(outPress, ratioO2, ratioN, ratioCO2,
            setO2, setN, setCO2, rawO2, rawN, rawCO2,
            pO2, tO2, pN, tN, pCO2, tCO2, status)

        prevActive = active
    end

    yield()
end
