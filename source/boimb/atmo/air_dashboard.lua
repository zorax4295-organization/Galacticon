-------------------------------
-- AIR DASHBOARD
-- Displays the state of the air recycle system.
-- Reads the current state code from a Memory chip named "Air Recycle State"
-- (written each tick by air_recycle.lua).
-- Reads pressures and gas ratios directly from sensors on the network.
-------------------------------

local LT                     = ic.enums.LogicType
local LBM                    = ic.enums.LogicBatchMethod

-------------------------------
-- SENSOR CONFIG (must match air_recycle.lua)
-------------------------------

local GAS_SENSOR_PREFAB_HASH = hash("StructureGasSensor")
local GAS_SENSOR_NAME_HASH   = hash("Gas Sensor-Base")
local STATE_MEMORY_NAME      = "Air Recycle State"

local HYSTERESIS             = 0.05
local MAX_WASTE_PRESSURE     = 40000
local WASTE_RESUME_PRESSURE  = 20000
local MIN_BASE_AIR_PRESSURE  = 80
local MAX_BASE_AIR_PRESSURE  = 90
local WASTE_ANALYSER_NAME    = "Pipe Analyzer-Base Waste Buffer"

local GASES                  = {
  { shortName = "O2",  longName = "Oxygen",        expected = 0.3,  isToxic = false },
  { shortName = "CO2", longName = "CarbonDioxide", expected = 0.02, isToxic = false },
  { shortName = "N",   longName = "Nitrogen",      expected = 0.68, isToxic = false },
  { shortName = "H2",  longName = "Hydrogen",      expected = 0,    isToxic = true },
  { shortName = "CH4", longName = "Methane",       expected = 0,    isToxic = true },
  { shortName = "POL", longName = "Pollutant",     expected = 0,    isToxic = true },
  { shortName = "N2O", longName = "NitrousOxide",  expected = 0,    isToxic = true },
}

-------------------------------
-- STATE CODE MAPPING (must match air_recycle.lua)
-------------------------------

local STATE_INFO             = {
  [0] = { name = "HALTED", bg = "#374151", fg = "#F9FAFB" },
  [1] = { name = "NOMINAL", bg = "#14532D", fg = "#86EFAC" },
  [2] = { name = "CO2 FILTRATION", bg = "#164E63", fg = "#67E8F9" },
  [3] = { name = "FULL FILTRATION", bg = "#1E3A8A", fg = "#93C5FD" },
  [4] = { name = "MAINTENANCE", bg = "#4C1D95", fg = "#C4B5FD" },
  [5] = { name = "DEPRESSURIZING", bg = "#78350F", fg = "#FCD34D" },
  [6] = { name = "WASTE FULL", bg = "#7C2D12", fg = "#FDBA74" },
  [7] = { name = "PANIC — BLOCKED", bg = "#7F1D1D", fg = "#FCA5A5" },
  [8] = { name = "!! PANIC !!", bg = "#991B1B", fg = "#FFFFFF" },
}

-------------------------------
-- SCREEN SETUP
-------------------------------

local surface                = ss.ui.surface("main")
ss.ui.activate("main")
surface:clear()

local W          = surface:size().w
local H          = surface:size().h

-- Layout constants
local PAD        = 12
local HDR_H      = 56
local SEC_HDR_H  = 28
local ROW_H      = 30
local COL_LEFT_W = math.floor(W * 0.42)

-------------------------------
-- BUILD UI SKELETON
-------------------------------

-- Background
surface:element({
  id    = "bg",
  type  = "panel",
  rect  = { unit = "px", x = 0, y = 0, w = W, h = H },
  style = { bg = "#0F172A" },
})

-- Header panel
local headerPanel = surface:element({
  id    = "header_panel",
  type  = "panel",
  rect  = { unit = "px", x = 0, y = 0, w = W, h = HDR_H },
  style = { bg = "#1E293B" },
})
headerPanel:element({
  id    = "header_title",
  type  = "label",
  rect  = { unit = "px", x = PAD, y = 0, w = 200, h = HDR_H },
  props = { text = "AIR RECYCLE" },
  style = { font_size = 22, align = "left", color = "#94A3B8" },
})
local stateLabel = headerPanel:element({
  id    = "state_label",
  type  = "label",
  rect  = { unit = "px", x = 200, y = 0, w = W - 400, h = HDR_H },
  props = { text = "..." },
  style = { font_size = 26, align = "center", color = "#FFFFFF" },
})
local timeLabel = headerPanel:element({
  id    = "time_label",
  type  = "label",
  rect  = { unit = "px", x = W - 200, y = 0, w = 200 - PAD, h = HDR_H },
  props = { text = "" },
  style = { font_size = 16, align = "right", color = "#94A3B8" },
})

-- Separator line
surface:element({
  id = "sep_h",
  type = "line",
  props = { x1 = 0, y1 = HDR_H, x2 = W, y2 = HDR_H },
  style = { color = "#334155", thickness = 2 },
})

-- Vertical separator between columns
surface:element({
  id = "sep_v",
  type = "line",
  props = { x1 = COL_LEFT_W, y1 = HDR_H, x2 = COL_LEFT_W, y2 = H },
  style = { color = "#334155", thickness = 2 },
})

-------------------------------
-- LEFT COLUMN — PRESSURES
-------------------------------

local leftY = HDR_H + PAD

surface:element({
  id    = "press_hdr",
  type  = "label",
  rect  = { unit = "px", x = PAD, y = leftY, w = COL_LEFT_W - PAD * 2, h = SEC_HDR_H },
  props = { text = "PRESSURES" },
  style = { font_size = 16, align = "left", color = "#64748B" },
})
leftY = leftY + SEC_HDR_H

-- Base pressure row
surface:element({
  id    = "base_lbl",
  type  = "label",
  rect  = { unit = "px", x = PAD, y = leftY, w = 120, h = ROW_H },
  props = { text = "Base" },
  style = { font_size = 18, align = "left", color = "#CBD5E1" },
})
local basePressureLabel = surface:element({
  id    = "base_val",
  type  = "label",
  rect  = { unit = "px", x = PAD + 120, y = leftY, w = 100, h = ROW_H },
  props = { text = "—" },
  style = { font_size = 18, align = "right", color = "#FFFFFF" },
})
local basePressureStatus = surface:element({
  id    = "base_status",
  type  = "label",
  rect  = { unit = "px", x = PAD + 230, y = leftY, w = COL_LEFT_W - PAD * 2 - 230, h = ROW_H },
  props = { text = "" },
  style = { font_size = 16, align = "left", color = "#86EFAC" },
})
leftY = leftY + ROW_H

surface:element({
  id    = "base_range",
  type  = "label",
  rect  = { unit = "px", x = PAD, y = leftY, w = COL_LEFT_W - PAD * 2, h = ROW_H - 8 },
  props = { text = string.format("  range  %d – %d kPa", MIN_BASE_AIR_PRESSURE, MAX_BASE_AIR_PRESSURE) },
  style = { font_size = 13, align = "left", color = "#475569" },
})
leftY = leftY + ROW_H + PAD

-- Waste pressure row
surface:element({
  id    = "waste_lbl",
  type  = "label",
  rect  = { unit = "px", x = PAD, y = leftY, w = 120, h = ROW_H },
  props = { text = "Waste" },
  style = { font_size = 18, align = "left", color = "#CBD5E1" },
})
local wastePressureLabel = surface:element({
  id    = "waste_val",
  type  = "label",
  rect  = { unit = "px", x = PAD + 120, y = leftY, w = 100, h = ROW_H },
  props = { text = "—" },
  style = { font_size = 18, align = "right", color = "#FFFFFF" },
})
local wastePressureStatus = surface:element({
  id    = "waste_status",
  type  = "label",
  rect  = { unit = "px", x = PAD + 230, y = leftY, w = COL_LEFT_W - PAD * 2 - 230, h = ROW_H },
  props = { text = "" },
  style = { font_size = 16, align = "left", color = "#86EFAC" },
})
leftY = leftY + ROW_H
surface:element({
  id    = "waste_range",
  type  = "label",
  rect  = { unit = "px", x = PAD, y = leftY, w = COL_LEFT_W - PAD * 2, h = ROW_H - 8 },
  props = { text = string.format("  full at %d kPa  |  resume at %d kPa", MAX_WASTE_PRESSURE, WASTE_RESUME_PRESSURE) },
  style = { font_size = 13, align = "left", color = "#475569" },
})

-------------------------------
-- RIGHT COLUMN — GAS RATIOS
-------------------------------

local rightX = COL_LEFT_W + PAD
local rightW = W - COL_LEFT_W - PAD * 2
local rightY = HDR_H + PAD

surface:element({
  id    = "gas_hdr",
  type  = "label",
  rect  = { unit = "px", x = rightX, y = rightY, w = rightW, h = SEC_HDR_H },
  props = { text = "GAS RATIOS" },
  style = { font_size = 16, align = "left", color = "#64748B" },
})
rightY          = rightY + SEC_HDR_H

-- Column headers
local colGasW   = 60
local colValW   = 90
local colRangeW = 180
local colStatW  = rightW - colGasW - colValW - colRangeW

surface:element({
  id    = "ghdr_gas",
  type  = "label",
  rect  = { unit = "px", x = rightX, y = rightY, w = colGasW, h = SEC_HDR_H - 4 },
  props = { text = "GAS" },
  style = { font_size = 13, align = "left", color = "#475569" },
})
surface:element({
  id    = "ghdr_val",
  type  = "label",
  rect  = { unit = "px", x = rightX + colGasW, y = rightY, w = colValW, h = SEC_HDR_H - 4 },
  props = { text = "RATIO" },
  style = { font_size = 13, align = "right", color = "#475569" },
})
surface:element({
  id    = "ghdr_range",
  type  = "label",
  rect  = { unit = "px", x = rightX + colGasW + colValW, y = rightY, w = colRangeW, h = SEC_HDR_H - 4 },
  props = { text = "RANGE" },
  style = { font_size = 13, align = "center", color = "#475569" },
})
surface:element({
  id    = "ghdr_stat",
  type  = "label",
  rect  = { unit = "px", x = rightX + colGasW + colValW + colRangeW, y = rightY, w = colStatW, h = SEC_HDR_H - 4 },
  props = { text = "STATUS" },
  style = { font_size = 13, align = "left", color = "#475569" },
})
rightY                = rightY + SEC_HDR_H - 4

-- Gas rows (created once, updated each tick via references)
local gasValueLabels  = {}
local gasStatusLabels = {}

for i, g in ipairs(GASES) do
  local y = rightY + (i - 1) * ROW_H

  surface:element({
    id    = "g_name_" .. i,
    type  = "label",
    rect  = { unit = "px", x = rightX, y = y, w = colGasW, h = ROW_H },
    props = { text = g.shortName },
    style = { font_size = 17, align = "left", color = "#CBD5E1" },
  })

  gasValueLabels[i] = surface:element({
    id    = "g_val_" .. i,
    type  = "label",
    rect  = { unit = "px", x = rightX + colGasW, y = y, w = colValW, h = ROW_H },
    props = { text = "—" },
    style = { font_size = 17, align = "right", color = "#FFFFFF" },
  })

  local rangeText
  if g.isToxic then
    rangeText = "must be 0"
  else
    local v = g.expected * HYSTERESIS
    rangeText = string.format("%.1f%% – %.1f%%", (g.expected - v) * 100, (g.expected + v) * 100)
  end
  surface:element({
    id    = "g_range_" .. i,
    type  = "label",
    rect  = { unit = "px", x = rightX + colGasW + colValW, y = y, w = colRangeW, h = ROW_H },
    props = { text = rangeText },
    style = { font_size = 13, align = "center", color = "#475569" },
  })

  gasStatusLabels[i] = surface:element({
    id    = "g_stat_" .. i,
    type  = "label",
    rect  = { unit = "px", x = rightX + colGasW + colValW + colRangeW, y = y, w = colStatW, h = ROW_H },
    props = { text = "" },
    style = { font_size = 16, align = "left", color = "#86EFAC" },
  })
end

-------------------------------
-- RIGHT COLUMN — GAS CHART
-------------------------------
local gasValuesHistory = {
  N = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  O2 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  CO2 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
}
local CHART_CONFIGS = {
  { key = "N",   color = "#000000", bg = "#10FFFFFF" },  -- cyan,  has the shared background
  { key = "O2",  color = "#5C66F8", bg = "#00000000" },  -- green, transparent overlay
  { key = "CO2", color = "#898989", bg = "#00000000" },  -- amber, transparent overlay
}
local chartRect = { unit = "px", x = rightX, y = rightY + (#GASES + 1) * ROW_H, w = rightW, h = 120 }
local gasCharts = {}
for _, cfg in ipairs(CHART_CONFIGS) do
  gasCharts[cfg.key] = surface:element({
    id    = "gas_chart_" .. cfg.key,
    type  = "sparkline",
    rect  = chartRect,
    props = { data = gasValuesHistory[cfg.key], min = 0, max = 100 },
    style = { bg = cfg.bg, thickness = 2, line_color = cfg.color },
  })
end

-------------------------------
-- UPDATE HELPERS
-------------------------------

local function updateState(stateCode)
  local info = STATE_INFO[stateCode] or STATE_INFO[0]
  stateLabel:set_props({ text = info.name })
  stateLabel:set_style({ color = info.fg })
end

local function updatePressures(basePressure, wastePressure)
  basePressureLabel:set_props({ text = string.format("%.1f kPa", basePressure) })
  if basePressure < MIN_BASE_AIR_PRESSURE then
    basePressureStatus:set_props({ text = "LOW" })
    basePressureStatus:set_style({ color = "#FCD34D" })
  elseif basePressure > MAX_BASE_AIR_PRESSURE then
    basePressureStatus:set_props({ text = "HIGH" })
    basePressureStatus:set_style({ color = "#FB923C" })
  else
    basePressureStatus:set_props({ text = "OK" })
    basePressureStatus:set_style({ color = "#86EFAC" })
  end

  wastePressureLabel:set_props({ text = string.format("%.0f kPa", wastePressure) })
  if wastePressure >= MAX_WASTE_PRESSURE then
    wastePressureStatus:set_props({ text = "FULL" })
    wastePressureStatus:set_style({ color = "#F87171" })
  elseif wastePressure >= WASTE_RESUME_PRESSURE then
    wastePressureStatus:set_props({ text = "HIGH" })
    wastePressureStatus:set_style({ color = "#FB923C" })
  else
    wastePressureStatus:set_props({ text = "OK" })
    wastePressureStatus:set_style({ color = "#86EFAC" })
  end
end

local function updateGases()
  for i, g in ipairs(GASES) do
    local ratioName = string.format("Ratio%s", g.longName)
    local measured  = ic.batch_read_name(GAS_SENSOR_PREFAB_HASH, GAS_SENSOR_NAME_HASH, LT[ratioName], LBM.Average)
    gasValueLabels[i]:set_props({ text = string.format("%.2f%%", measured * 100) })
    -- update last value on gasValuesHistory
    local values = gasValuesHistory[g.shortName]
    if values ~= nil then
      table.remove(values, 1)
      values[#values + 1] = measured * 100
      if gasCharts[g.shortName] then
        gasCharts[g.shortName]:set_props({ data = values })
      end
    end
    local statusText, statusColor
    if g.isToxic then
      if measured > 0 then
        statusText  = "!! TOXIC !!"
        statusColor = "#F87171"
      else
        statusText  = "OK"
        statusColor = "#86EFAC"
      end
    else
      local variance = g.expected * HYSTERESIS
      if measured > g.expected + variance then
        statusText  = "HIGH"
        statusColor = "#FB923C"
      elseif measured < g.expected - variance then
        statusText  = "LOW"
        statusColor = "#FCD34D"
      else
        statusText  = "OK"
        statusColor = "#86EFAC"
      end
    end

    gasStatusLabels[i]:set_props({ text = statusText })
    gasStatusLabels[i]:set_style({ color = statusColor })
  end
end


-------------------------------
-- MAIN LOOP
-------------------------------

local stateMem = ic.find(STATE_MEMORY_NAME)
local wasteAnal = ic.find(WASTE_ANALYSER_NAME)

while true do
  sleep(1)

  -- Re-find memory chip if not connected yet
  if not stateMem then stateMem = ic.find(STATE_MEMORY_NAME) end
  if not wasteAnal then wasteAnal = ic.find(WASTE_ANALYSER_NAME) end
  local stateCode     = stateMem and ic.read_id(stateMem, LT.Setting) or 0

  local basePressure  = ic.batch_read_name(GAS_SENSOR_PREFAB_HASH, GAS_SENSOR_NAME_HASH, LT.Pressure, LBM.Average)
  local wastePressure = wasteAnal and ic.read_id(wasteAnal, LT.Pressure) or 0

  updateState(stateCode)
  updatePressures(basePressure, wastePressure)
  updateGases()
  timeLabel:set_props({ text = util.clock_time("HH:MM") })
  surface:commit()
end
