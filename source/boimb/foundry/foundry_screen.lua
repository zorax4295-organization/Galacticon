local foundry = require("foundry_lib")

-------------------------------
-- SCREEN SETUP
-------------------------------

local surface = ss.ui.surface("main")
ss.ui.activate("main")

local W = surface:size().w
local H = surface:size().h


-------------------------------
-- INGOT LIST (declaration order)
-------------------------------

local INGOTS           = {
	"IronIngot",
	"CopperIngot",
	"SiliconIngot",
	"GoldIngot",
	"SilverIngot",
	"LeadIngot",
	"NickelIngot",
	"ConstantanIngot",
	"InvarIngot",
	"SteelIngot",
	"ElectrumIngot",
	"SolderIngot",
	"WaspaloyIngot",
	"HastelloyIngot",
	"StelliteIngot",
}

-------------------------------
-- LAYOUT CONSTANTS
-------------------------------

local COLS             = 5
local PAD              = 8
local HDR_H            = 48
local TAB_W            = math.floor(W / 2)

-- Shared card inner gap (between icon→name and name→qty)
local CARD_GAP         = 4

-- Ore tab: fixed card size, does not need to fill the screen
local ORE_CARD_W       = math.floor((W - PAD * (COLS + 1)) / COLS)
local ORE_CARD_H       = 200
local ORE_ICON_SZ      = 120
local ORE_NAME_H       = 22
local ORE_AMT_H        = 22

-- Ingot tab: same card dimensions as ore tab, scrollable
local ING_CARD_W       = ORE_CARD_W
local ING_CARD_H       = ORE_CARD_H
local ING_ICON_SZ      = ORE_ICON_SZ
local ING_NAME_H       = ORE_NAME_H
local ING_AMT_H        = ORE_AMT_H

-- Category grouping
local CAT_HDR_H        = 32
local CATEGORY_ORDER   = {
	foundry.INGOT_CATEGORIES.BASIC,
	foundry.INGOT_CATEGORIES.ALLOY,
	foundry.INGOT_CATEGORIES.SUPER_ALLOY,
}
local CATEGORY_LABELS  = {
	[foundry.INGOT_CATEGORIES.BASIC]       = "BASIC INGOTS",
	[foundry.INGOT_CATEGORIES.ALLOY]       = "ALLOYS",
	[foundry.INGOT_CATEGORIES.SUPER_ALLOY] = "SUPER ALLOYS",
}

local STATE_OVERLAY    = {
	[foundry.STATE.HALTED]               = { title = "HALTED", msg = "Check device connections" },
	[foundry.STATE.MAINTENANCE]          = { title = "MAINTENANCE", msg = "Foundry is in maintenance mode" },
	[foundry.STATE.DELIVERING_MATERIALS] = { title = "BUSY", msg = "Delivering materials to furnace" },
	[foundry.STATE.MELTING_MATERIALS]    = { title = "BUSY", msg = "Melting materials" },
	[foundry.STATE.CREATING_INGOT]       = { title = "BUSY", msg = "Creating ingots" },
	[foundry.STATE.REQUEST_COMPLETE]     = { title = "BUSY", msg = "Finalizing request" },
}

-- Toast
local TOAST_W          = 400
local TOAST_H          = 40
local TOAST_X          = math.floor((W - TOAST_W) / 2)
local TOAST_Y          = H - TOAST_H - PAD * 2
local TOAST_DURATION   = 4

-- Modal
local MODAL_W          = 340
local MODAL_H          = 296
local MODAL_X          = math.floor((W - MODAL_W) / 2)
local MODAL_Y          = math.floor((H - MODAL_H) / 2)
local MODAL_ICON_SZ    = 56
local QTY_H            = 64
local QTY_ARROW_W      = 64
local QTY_LABEL_W      = MODAL_W - PAD * 2 - QTY_ARROW_W * 2
local ACT_BTN_W        = math.floor((MODAL_W - PAD * 3) / 2)
local ACT_BTN_H        = 48

-------------------------------
-- ICON MAPS
-------------------------------

local ORE_ICONS        = {
	Iron = "IronOre",
	Copper = "CopperOre",
	Gold = "GoldOre",
	Silver = "SilverOre",
	Lead = "LeadOre",
	Cobalt = "CobaltOre",
	Nickel = "NickelOre",
	Silicon = "SiliconOre",
	Coal = "CoalOre",
	Uranium = "UraniumOre",
}

local INGOT_ICONS      = {
	IronIngot = "IronIngot",
	CopperIngot = "CopperIngot",
	SiliconIngot = "SiliconIngot",
	GoldIngot = "GoldIngot",
	SilverIngot = "SilverIngot",
	NickelIngot = "NickelIngot",
	LeadIngot = "LeadIngot",
	ConstantanIngot = "ConstantanIngot",
	InvarIngot = "InvarIngot",
	SteelIngot = "SteelIngot",
	ElectrumIngot = "ElectrumIngot",
	SolderIngot = "SolderIngot",
	WaspaloyIngot = "WaspaloyIngot",
	HastelloyIngot = "HastelloyIngot",
	StelliteIngot = "StelliteIngot",
}

-------------------------------
-- SHARED STATE
-------------------------------

local REFRESH_INTERVAL = 5
local elapsed          = 0
local oreStock         = {}
local oreAmountLabels  = {}
local maxOrderLabels   = {}
local activeTab        = "ores"
local mode             = "grid" -- "grid" | "modal", relevant only in ingots tab
local selectedIngot    = nil
local selectedQty      = nil
local qtyLabel         = nil
local toastRemaining   = 0
local serverState      = nil -- nil = not yet received

-------------------------------
-- FORWARD DECLARATIONS
-------------------------------

local buildOreGridUI
local buildIngotGridUI
local buildIngotModalUI

-------------------------------
-- HELPERS
-------------------------------

local function drawBackground()
	surface:element({
		id = "bg",
		type = "panel",
		rect = { unit = "px", x = 0, y = 0, w = W, h = H },
		style = { bg = "#0F172A" },
	})
end

local function drawTabs()
	surface:element({
		id = "tab_ores",
		type = "button",
		rect = { unit = "px", x = 0, y = 0, w = TAB_W, h = HDR_H },
		props = { text = "ORE STOCK" },
		style = {
			font_size = 20,
			align = "center",
			bg = activeTab == "ores" and "#1E3A5F" or "#1E293B",
			color = activeTab == "ores" and "#60A5FA" or "#475569",
		},
		on_click = function(_player)
			if activeTab == "ores" then return end
			print("[SCREEN] tab click: switching to ores")
			activeTab = "ores"
			mode = "grid"
			buildOreGridUI()
		end,
	})
	surface:element({
		id = "tab_ingots",
		type = "button",
		rect = { unit = "px", x = TAB_W, y = 0, w = W - TAB_W, h = HDR_H },
		props = { text = "INGOT ORDERS" },
		style = {
			font_size = 20,
			align = "center",
			bg = activeTab == "ingots" and "#1E3A5F" or "#1E293B",
			color = activeTab == "ingots" and "#60A5FA" or "#475569",
		},
		on_click = function(_player)
			if activeTab == "ingots" then return end
			print(string.format("[SCREEN] tab click: switching to ingots (serverState=%s)", tostring(serverState)))
			activeTab = "ingots"
			mode = "grid"
			buildIngotGridUI()
		end,
	})
end

local function drawIngotOverlay()
	if serverState == foundry.STATE.IDLE then return end
	local info    = serverState and STATE_OVERLAY[serverState]
	local title   = info and info.title or "CONNECTING"
	local msg     = info and info.msg or "Waiting for foundry status..."
	local centerY = math.floor((H + HDR_H) / 2)
	print(string.format("[SCREEN] drawIngotOverlay: serverState=%s title=%s", tostring(serverState), title))
	surface:element({
		id       = "ingot_overlay",
		type     = "panel",
		rect     = { unit = "px", x = 0, y = HDR_H, w = W, h = H - HDR_H },
		style    = { bg = "#0F172AD0" },
		on_click = function(_player) end,
	})
	surface:element({
		id    = "ingot_overlay_title",
		type  = "label",
		rect  = { unit = "px", x = 0, y = centerY - 32, w = W, h = 24 },
		props = { text = title },
		style = { font_size = 14, align = "center", color = "#60A5FA" },
	})
	surface:element({
		id    = "ingot_overlay_msg",
		type  = "label",
		rect  = { unit = "px", x = PAD * 4, y = centerY - 8, w = W - PAD * 8, h = 32 },
		props = { text = msg },
		style = { font_size = 22, align = "center", color = "#FFFFFF" },
	})
end

local function showToast(msg, isError)
	print(string.format("[SCREEN] showToast: isError=%s msg=%s", tostring(isError), msg))
	toastRemaining = TOAST_DURATION
	local toast = surface:element({
		id    = "toast",
		type  = "panel",
		rect  = { unit = "px", x = TOAST_X, y = TOAST_Y, w = TOAST_W, h = TOAST_H },
		style = { bg = isError and "#7F1D1D" or "#14532D" },
	})
	toast:element({
		id    = "toast_msg",
		type  = "label",
		rect  = { unit = "px", x = PAD, y = 0, w = TOAST_W - PAD * 2, h = TOAST_H },
		props = { text = msg },
		style = { font_size = 14, align = "center", color = "#FFFFFF" },
	})
	surface:commit()
end

-- "StelliteIngot" -> "Stellite"
local function ingotLabel(ingot)
	return ingot:gsub("Ingot", "")
end

-- Max orderable quantity for an ingot given current ore stock.
-- Always a multiple of recipe.orderQty.
local function calcMaxOrder(ingot)
	local recipe = foundry.INGOTS_RECIPES[ingot]
	local orderQty = recipe.orderQty
	local maxBatches = math.huge
	for ore, ratio in pairs(recipe.ores) do
		local stock = oreStock[ore] or 0
		local batchesFromOre = math.floor(stock / (ratio * orderQty))
		if batchesFromOre < maxBatches then
			maxBatches = batchesFromOre
		end
	end
	if maxBatches == math.huge then maxBatches = 0 end
	return maxBatches * orderQty
end

-------------------------------
-- ORE GRID (read-only, panel cards)
-------------------------------

buildOreGridUI = function()
	print("[SCREEN] buildOreGridUI")
	surface:clear()
	oreAmountLabels = {}

	drawBackground()
	drawTabs()

	for i, ore in ipairs(foundry.ORES) do
		local col = (i - 1) % COLS
		local row = math.floor((i - 1) / COLS)
		local cx = PAD + col * (ORE_CARD_W + PAD)
		local cy = HDR_H + PAD + row * (ORE_CARD_H + PAD)

		local card = surface:element({
			id = "card_" .. ore,
			type = "panel",
			rect = { unit = "px", x = cx, y = cy, w = ORE_CARD_W, h = ORE_CARD_H },
			style = { bg = "#1E293B" },
		})

		card:element({
			id = "icon_" .. ore,
			type = "icon",
			rect = {
				unit = "px",
				x = math.floor((ORE_CARD_W - ORE_ICON_SZ) / 2),
				y = PAD,
				w = ORE_ICON_SZ,
				h = ORE_ICON_SZ,
			},
			props = { name = ss.ui.icons.prefab[ORE_ICONS[ore]] },
		})

		card:element({
			id = "name_" .. ore,
			type = "label",
			rect = { unit = "px", x = 0, y = PAD + ORE_ICON_SZ + CARD_GAP, w = ORE_CARD_W, h = ORE_NAME_H },
			props = { text = ore },
			style = { font_size = 22, align = "center", color = "#94A3B8" },
		})

		oreAmountLabels[ore] = card:element({
			id = "amt_" .. ore,
			type = "label",
			rect = {
				unit = "px",
				x = 0,
				y = PAD + ORE_ICON_SZ + CARD_GAP + ORE_NAME_H + CARD_GAP,
				w = ORE_CARD_W,
				h = ORE_AMT_H,
			},
			props = { text = oreStock[ore] and tostring(oreStock[ore]) or "—" },
			style = { font_size = 17, align = "center", color = "#FFFFFF" },
		})
	end

	surface:commit()
end

-------------------------------
-- INGOT GRID (scrollable, clickable)
-------------------------------

buildIngotGridUI = function()
	print(string.format("[SCREEN] buildIngotGridUI: serverState=%s", tostring(serverState)))
	surface:clear()
	maxOrderLabels = {}

	drawBackground()
	drawTabs()

	local groups = {}
	for _, cat in ipairs(CATEGORY_ORDER) do
		local g = { cat = cat, ingots = {} }
		for _, ingot in ipairs(INGOTS) do
			if foundry.INGOTS_RECIPES[ingot].category == cat then
				g.ingots[#g.ingots + 1] = ingot
			end
		end
		if #g.ingots > 0 then
			groups[#groups + 1] = g
		end
	end

	local contentH = PAD
	for _, g in ipairs(groups) do
		contentH = contentH + CAT_HDR_H + PAD
		contentH = contentH + math.ceil(#g.ingots / COLS) * (ING_CARD_H + PAD)
	end

	local scroll = surface:element({
		id = "scroll_area",
		type = "scrollview",
		rect = { unit = "px", x = 0, y = HDR_H, w = W, h = H - HDR_H },
		props = { content_height = tostring(contentH) },
		style = { bg = "#0F172A", scrollbar_bg = "#1E293B", scrollbar_handle = "#475569" },
	})

	local y = PAD
	for _, g in ipairs(groups) do
		scroll:element({
			id = "cat_hdr_" .. tostring(g.cat),
			type = "label",
			rect = { unit = "px", x = PAD, y = y, w = W - PAD * 2, h = CAT_HDR_H },
			props = { text = CATEGORY_LABELS[g.cat] },
			style = { font_size = 15, align = "left", color = "#60A5FA" },
		})
		y = y + CAT_HDR_H + PAD

		for j, ingot in ipairs(g.ingots) do
			local col = (j - 1) % COLS
			local row = math.floor((j - 1) / COLS)
			local cx = PAD + col * (ING_CARD_W + PAD)
			local cy = y + row * (ING_CARD_H + PAD)
			local recipe = foundry.INGOTS_RECIPES[ingot]
			local maxOrder = calcMaxOrder(ingot)

			scroll:element({
				id = "card_" .. ingot,
				type = "button",
				rect = { unit = "px", x = cx, y = cy, w = ING_CARD_W, h = ING_CARD_H },
				style = { bg = "#1E293B", color = "#1E293B" },
				on_click = function(_player)
					print(string.format("[SCREEN] card click: ingot=%s orderQty=%d maxOrder=%d serverState=%s",
						ingot, recipe.orderQty, calcMaxOrder(ingot), tostring(serverState)))
					selectedIngot = ingot
					selectedQty = recipe.orderQty
					mode = "modal"
					buildIngotModalUI()
				end,
			})

			scroll:element({
				id = "icon_" .. ingot,
				type = "icon",
				rect = {
					unit = "px",
					x = cx + math.floor((ING_CARD_W - ING_ICON_SZ) / 2),
					y = cy + PAD,
					w = ING_ICON_SZ,
					h = ING_ICON_SZ,
				},
				props = { name = ss.ui.icons.prefab[INGOT_ICONS[ingot]] },
			})

			scroll:element({
				id = "name_" .. ingot,
				type = "label",
				rect = { unit = "px", x = cx, y = cy + PAD + ING_ICON_SZ + CARD_GAP, w = ING_CARD_W, h = ING_NAME_H },
				props = { text = ingotLabel(ingot) },
				style = { font_size = 22, align = "center", color = "#94A3B8" },
			})

			maxOrderLabels[ingot] = scroll:element({
				id = "max_" .. ingot,
				type = "label",
				rect = {
					unit = "px",
					x = cx,
					y = cy + PAD + ING_ICON_SZ + CARD_GAP + ING_NAME_H + CARD_GAP,
					w = ING_CARD_W,
					h = ING_AMT_H,
				},
				props = { text = maxOrder > 0 and (tostring(maxOrder) .. " MAX") or "—" },
				style = { font_size = 17, align = "center", color = "#FFFFFF" },
			})
		end

		y = y + math.ceil(#g.ingots / COLS) * (ING_CARD_H + PAD)
	end

	drawIngotOverlay()
	surface:commit()
end

-------------------------------
-- INGOT MODAL
-------------------------------

buildIngotModalUI = function()
	print(string.format("[SCREEN] buildIngotModalUI: ingot=%s qty=%d serverState=%s",
		selectedIngot, selectedQty, tostring(serverState)))
	surface:clear()

	local recipe = foundry.INGOTS_RECIPES[selectedIngot]
	local orderQty = recipe.orderQty
	local maxOrder = calcMaxOrder(selectedIngot)
	print(string.format("[SCREEN] modal: orderQty=%d maxOrder=%d", orderQty, maxOrder))

	drawBackground()
	drawTabs()

	surface:element({
		id = "dim",
		type = "panel",
		rect = { unit = "px", x = 0, y = HDR_H, w = W, h = H - HDR_H },
		style = { bg = "#0f172a96" },
	})

	local modal = surface:element({
		id = "modal",
		type = "panel",
		rect = { unit = "px", x = MODAL_X, y = MODAL_Y, w = MODAL_W, h = MODAL_H },
		style = { bg = "#1E293B" },
	})

	modal:element({
		id = "modal_icon",
		type = "icon",
		rect = {
			unit = "px",
			x = math.floor((MODAL_W - MODAL_ICON_SZ) / 2),
			y = PAD,
			w = MODAL_ICON_SZ,
			h = MODAL_ICON_SZ,
		},
		props = { name = ss.ui.icons.prefab[INGOT_ICONS[selectedIngot]] },
	})

	modal:element({
		id = "modal_name",
		type = "label",
		rect = { unit = "px", x = 0, y = PAD + MODAL_ICON_SZ + 4, w = MODAL_W, h = 24 },
		props = { text = ingotLabel(selectedIngot) },
		style = { font_size = 20, align = "center", color = "#FFFFFF" },
	})

	local maxText = maxOrder > 0 and ("step " .. tostring(orderQty) .. "  |  max " .. tostring(maxOrder))
			or ("step " .. tostring(orderQty) .. "  |  max unknown")
	modal:element({
		id = "modal_max",
		type = "label",
		rect = { unit = "px", x = 0, y = PAD + MODAL_ICON_SZ + 4 + 24, w = MODAL_W, h = 20 },
		props = { text = maxText },
		style = { font_size = 13, align = "center", color = "#64748B" },
	})

	local qtyY = PAD + MODAL_ICON_SZ + 4 + 24 + 20 + PAD

	qtyLabel = modal:element({
		id    = "qty_label",
		type  = "label",
		rect  = { unit = "px", x = PAD + QTY_ARROW_W, y = qtyY, w = QTY_LABEL_W, h = QTY_H },
		props = { text = tostring(selectedQty) },
		style = { font_size = 32, align = "center", color = "#FFFFFF" },
	})

	modal:element({
		id = "btn_dec",
		type = "button",
		rect = { unit = "px", x = PAD, y = qtyY, w = QTY_ARROW_W, h = QTY_H },
		props = { text = "v" },
		style = { font_size = 28, bg = "#334155", color = "#FFFFFF" },
		on_click = function(_player)
			if selectedQty <= orderQty then
				print(string.format("[SCREEN] btn_dec: already at minimum qty=%d", selectedQty))
				return
			end
			selectedQty = selectedQty - orderQty
			print(string.format("[SCREEN] btn_dec: qty → %d", selectedQty))
			qtyLabel:set_props({ text = tostring(selectedQty) })
			surface:commit()
		end,
	})

	modal:element({
		id = "btn_inc",
		type = "button",
		rect = { unit = "px", x = MODAL_W - PAD - QTY_ARROW_W, y = qtyY, w = QTY_ARROW_W, h = QTY_H },
		props = { text = "^" },
		style = { font_size = 28, bg = "#334155", color = "#FFFFFF" },
		on_click = function(_player)
			if maxOrder > 0 and selectedQty + orderQty > maxOrder then
				print(string.format("[SCREEN] btn_inc: capped at maxOrder=%d", maxOrder))
				return
			end
			selectedQty = selectedQty + orderQty
			print(string.format("[SCREEN] btn_inc: qty → %d", selectedQty))
			qtyLabel:set_props({ text = tostring(selectedQty) })
			surface:commit()
		end,
	})

	local btnY = qtyY + QTY_H + PAD

	modal:element({
		id = "btn_order",
		type = "button",
		rect = { unit = "px", x = PAD, y = btnY, w = ACT_BTN_W, h = ACT_BTN_H },
		props = { text = "ORDER" },
		style = { font_size = 20, bg = "#15803D", color = "#FFFFFF" },
		on_click = function(_player)
			local orderedIngot = selectedIngot
			local orderedQty   = selectedQty
			print(string.format("[SCREEN] btn_order: submitting ingot=%s qty=%d serverState=%s",
				orderedIngot, orderedQty, tostring(serverState)))
			ic.net.request(
				"IC Housing-ServerFoundry",
				"request_ingot",
				{ ingot = orderedIngot, quantity = orderedQty },
				function(ok, payload, err)
					print(string.format("[SCREEN] request_ingot callback: ok=%s err=%s payload=%s",
						tostring(ok), tostring(err), tostring(payload and payload.code)))
					if ok and payload and payload.code == 200 then
						print(string.format("[SCREEN] order confirmed: channel=%s", tostring(payload.message)))
						showToast(string.format("Order placed: %d x %s", orderedQty, orderedIngot), false)
					elseif ok and payload then
						print(string.format("[SCREEN] order rejected by server: %s", tostring(payload.message)))
						showToast(payload.message or "Order failed", true)
					else
						print(string.format("[SCREEN] order network error: %s", tostring(err)))
						showToast("Request failed: " .. tostring(err), true)
					end
				end
			)
			mode = "grid"
			buildIngotGridUI()
		end,
	})

	modal:element({
		id = "btn_cancel",
		type = "button",
		rect = { unit = "px", x = PAD * 2 + ACT_BTN_W, y = btnY, w = ACT_BTN_W, h = ACT_BTN_H },
		props = { text = "X  Cancel" },
		style = { font_size = 20, bg = "#7F1D1D", color = "#FFFFFF" },
		on_click = function(_player)
			print("[SCREEN] btn_cancel: closing modal")
			mode = "grid"
			buildIngotGridUI()
		end,
	})

	surface:commit()
end

-------------------------------
-- DATA REFRESH
-------------------------------

local function refreshOreStock()
	print("[SCREEN] refreshOreStock: requesting get_ores_stock")
	ic.net.request("IC Housing-ServerFoundry", "get_ores_stock", nil, function(ok, payload, err)
		if not ok then
			print(string.format("[SCREEN] get_ores_stock failed: %s", tostring(err)))
			return
		end
		print("[SCREEN] get_ores_stock: received stock data")
		oreStock = payload
		if mode ~= "grid" then
			print(string.format("[SCREEN] get_ores_stock: skipping UI update (mode=%s)", mode))
			return
		end
		if activeTab == "ores" then
			for ore, amount in pairs(oreStock) do
				if oreAmountLabels[ore] then
					oreAmountLabels[ore]:set_props({ text = tostring(amount) })
				end
			end
			surface:commit()
		elseif activeTab == "ingots" then
			for _, ingot in ipairs(INGOTS) do
				if maxOrderLabels[ingot] then
					local maxOrder = calcMaxOrder(ingot)
					maxOrderLabels[ingot]:set_props({
						text = maxOrder > 0 and (tostring(maxOrder) .. " MAX") or "—",
					})
				end
			end
			surface:commit()
		end
	end)
end

-------------------------------
-- INIT + TICK
-------------------------------
print("[SCREEN] subscribing to foundry/state and fetching initial status...")
ic.net.subscribe("foundry/state", function(topic, payload, fromId, fromName, retained)
	serverState = payload.state
	print(string.format("[SCREEN] foundry/state received: state=%s from=%s",
		serverState, fromName))

	if activeTab ~= "ingots" then return end
	if mode == "modal" then
		print("[SCREEN] foundry/state: closing modal due to state change")
		mode = "grid"
	end
	buildIngotGridUI()
end)


ic.net.request("IC Housing-ServerFoundry", "get_status", nil, function(ok, payload, err)
	print(string.format("[SCREEN] get_status callback: %s", util.json.encode({ ok = ok, payload = payload, error = err })))

	if ok then
		serverState = payload
		print(string.format("[SCREEN] initial serverState set to %s", serverState))
	else
		print("[SCREEN] get_status failed, serverState remains nil")
	end
end)

buildOreGridUI()

function tick(dt)
	elapsed = elapsed + dt
	if elapsed >= REFRESH_INTERVAL then
		elapsed = 0
		refreshOreStock()
	end
	if toastRemaining > 0 then
		toastRemaining = toastRemaining - dt
		if toastRemaining <= 0 then
			toastRemaining = 0
			print("[SCREEN] toast expired, rebuilding current view")
			if mode == "modal" then
				buildIngotModalUI()
			elseif activeTab == "ingots" then
				buildIngotGridUI()
			else
				buildOreGridUI()
			end
		end
	end
end
