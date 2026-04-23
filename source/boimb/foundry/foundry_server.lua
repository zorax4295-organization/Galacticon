--------------------------------------------------------------------
--- SERVER Managing relation between Silos and Foundry
--- SERVER Housing name : IC Housing-ServerFoundry
--------------------------------------------------------------------
local foundry = require("foundry_lib")
-- TODO: Handle silos are busy with a proper way. basically, see if chutes are full.

local LT = ic.enums.LogicType

local STATE = foundry.STATE
-- Forward-declared so state closures can call it
local transition
local furnace
-- TODO: Maybe store all devices here to avoid "hammering find"

-------------------------------
-- PERSISTENCE
-------------------------------
local missingDevices = {}
local currentState = STATE.HALTED
local lastEvent = ""
local currentRequest
local maintenance = 0

function serialize()
	return util.json.encode({
		currentRequest = currentRequest,
		currentState = currentState,
		missingDevices = missingDevices,
		lastEvent = lastEvent,
		maintenance = maintenance,
	})
end

function deserialize(blob)
	if type(blob) ~= "string" then
		return
	end
	local ok, data = pcall(util.json.decode, blob)
	if ok and type(data) == "table" then
		currentRequest = data.currentRequest
		currentState = data.currentState or STATE.HALTED
		missingDevices = data.missingDevices or {}
		lastEvent = data.lastEvent or "RECOVERY"
		maintenance = data.maintenance or 0
		print(string.format("[SERVER] deserialize: state=%s lastEvent=%s", currentState, lastEvent))
	else
		print("[SERVER] deserialize: failed to decode blob")
	end
end

-------------------------------

-------------------------------
-- HARDWARE HELPERS
-------------------------------

-- Check if all needed devices are there. Returns true if OK, false if KO
local function checkDevices()
	missingDevices = {}
	-- check for Silos
	for _, value in ipairs(foundry.ORES) do
		local siloName = foundry.getSiloName(value)
		local silo = ic.find(siloName)
		if silo == nil then
			print(string.format("[SERVER] checkDevices: MISSING silo %s", siloName))
			missingDevices[#missingDevices + 1] = siloName
		end

		local valveName = foundry.getSiloValveName(value)
		local valve = ic.find(valveName)
		if valve == nil then
			print(string.format("[SERVER] checkDevices: MISSING valve %s", valveName))
			missingDevices[#missingDevices + 1] = valveName
		end
	end
	furnace = ic.find("Furnace")
	if furnace == nil then
		print("[SERVER] checkDevices: MISSING Furnace")
		missingDevices[#missingDevices + 1] = "Furnace"
	end
	return #missingDevices == 0
end

local function safetyShutdown()
	print("[SERVER] safetyShutdown: closing all valves and furnace")
	for _, value in ipairs(foundry.ORES) do
		local valve = ic.find(foundry.getSiloValveName(value))
		if valve ~= nil then
			ic.write_id(valve, LT.Lock, 0)
			ic.write_id(valve, LT.On, 0)
			ic.write_id(valve, LT.Open, 0)
			ic.write_id(valve, LT.Setting, 1)
		end
	end
	furnace = ic.find("Furnace")
	if furnace ~= nil then
		ic.write_id(furnace, LT.On, 0)
		ic.write_id(furnace, LT.SettingInput, 0)
		ic.write_id(furnace, LT.SettingOutput, 100)
		ic.write_id(furnace, LT.Open, 0)
	end
end

local function initDevices()
	print("[SERVER] initDevices: initializing silos, valves, furnace")
	for _, value in ipairs(foundry.ORES) do
		local silo = ic.find(foundry.getSiloName(value))
		if silo ~= nil then
			ic.write_id(silo, LT.On, 1)
			ic.write_id(silo, LT.Lock, 1)
			ic.write_id(silo, LT.Open, 1)
		end
		local valve = ic.find(foundry.getSiloValveName(value))
		if valve ~= nil then
			ic.write_id(valve, LT.Lock, 1)
			ic.write_id(valve, LT.On, 1)
			ic.write_id(valve, LT.Open, 0)
			ic.write_id(valve, LT.Setting, 0)
		end
	end
	furnace = ic.find("Furnace")
	if furnace ~= nil then
		ic.write_id(furnace, LT.On, 1)
		ic.write_id(furnace, LT.SettingInput, 0)
		ic.write_id(furnace, LT.SettingOutput, 0)
		ic.write_id(furnace, LT.Open, 0)
	end
end

-------------------------------
-- FOUNDRY — STATE MACHINE
-------------------------------
-- States:
--   HALTED          : missing devices, script paused
--   MAINTENANCE     : manual override, all chutes valves off/unlocked
--   IDLE            : waiting for incoming request
--   NEW_REQUEST     : check materials availability
--   DELIVERING_MATERIALS: delivers materials to furnace
--   MELTING_MATERIALS: all materials in furnace, waiting for OK temp and pressure
--   CREATING_INGOT: Temp and Pressure OK, delivering ingot
--   REQUEST_COMPLETE: Ingots delivered
-------------------------------

local states = {
	[STATE.HALTED] = {
		enter = function()
			print("[SERVER] ENTERING STATE HALTED")
			safetyShutdown()
			print("[SERVER] [SAFETY] Script halted. Missing devices:")
			for _, name in ipairs(missingDevices) do
				print(string.format("[SERVER]   - %s", name))
			end
		end,
		tick = function()
			if checkDevices() then
				return STATE.IDLE, "All devices found — resuming"
			end
			sleep(4)
		end,
		exit = function()
			print("[SERVER] LEAVING STATE HALTED")
		end,
	},
	[STATE.MAINTENANCE] = {
		enter = function()
			print("[SERVER] ENTERING STATE MAINTENANCE")
			safetyShutdown()
		end,
		tick = function()
			if maintenance == 0 then
				return STATE.IDLE, "Back to normal"
			end
			sleep(4)
		end,
		exit = function()
			print("[SERVER] LEAVING STATE MAINTENANCE")
		end,
	},
	[STATE.IDLE] = {
		enter = function()
			print("[SERVER] ENTERING STATE IDLE")
			initDevices()
		end,
		tick = function(currentRequest)
			if not (checkDevices()) then
				local missingDevicesList = ""
				for _, value in ipairs(missingDevices) do
					missingDevicesList = missingDevicesList == "" and value
							or string.format("%s, %s", missingDevicesList, value)
				end
				return STATE.HALTED, string.format("Devices are missing: %s", missingDevicesList)
			end
			if maintenance == 1 then
				return STATE.MAINTENANCE, "Enter maintenance mode"
			end
			if currentRequest ~= nil then
				print(string.format("[SERVER] IDLE: got request channel=%d, totalOres=%s", currentRequest.channel,
					tostring(currentRequest.totalOres)))
				local listOfMaterials = ""
				for key, value in pairs(currentRequest.ores) do
					listOfMaterials = listOfMaterials == "" and string.format("%d %s", value, key)
							or string.format("%s, %d %s", listOfMaterials, value, key)
				end
				return STATE.DELIVERING_MATERIALS,
						string.format("Delivering materials for request %d: %s", currentRequest.channel, listOfMaterials)
			end
			sleep(4)
		end,
		exit = function()
			print("[SERVER] LEAVING STATE IDLE")
		end,
	},
	[STATE.DELIVERING_MATERIALS] = {
		enter = function()
			print("[SERVER] ENTERING STATE DELIVERING_MATERIALS")
			for key, value in pairs(currentRequest.ores) do
				local valve = ic.find(foundry.getSiloValveName(key))
				if valve ~= nil then
					local setting = value / 50
					print(string.format("[SERVER] DELIVERING: opening valve %s setting=%.2f (qty=%d)", key, setting,
						value))
					ic.write_id(valve, LT.Setting, setting)
					ic.write_id(valve, LT.Open, 1)
				else
					print(string.format("[SERVER] DELIVERING: ERROR valve not found for %s", key))
				end
			end
		end,
		tick = function(currentRequest)
			local isAnyValveOpen = false
			for key, _ in pairs(currentRequest.ores) do
				local valve = ic.find(foundry.getSiloValveName(key))
				if valve then
					local open = ic.read_id(valve, LT.Open) == 1
					if open then
						print(string.format("[SERVER] DELIVERING tick: valve %s still open", key))
					end
					isAnyValveOpen = isAnyValveOpen or open
				else
					print(string.format("[SERVER] DELIVERING tick: valve %s not found", key))
				end
			end
			if not isAnyValveOpen then
				print("[SERVER] DELIVERING tick: all valves closed, materials delivered")
				return STATE.MELTING_MATERIALS, "All materials out of silos"
			end
		end,
		exit = function()
			print("[SERVER] LEAVING STATE DELIVERING_MATERIALS")
		end,
	},
	[STATE.MELTING_MATERIALS] = {
		enter = function()
			print(string.format("[SERVER] ENTERING STATE MELTING_MATERIALS (waiting for reagents=%s)",
				tostring(currentRequest.totalOres)))
		end,
		tick = function(currentRequest)
			-- TODO: Handle Furnace temp and pressure
			print('Furnace: ', furnace)
			local reagents = ic.read_id(furnace, LT.Reagents)
			print(string.format("[SERVER] MELTING tick: reagents=%d expected=%d", reagents, currentRequest.totalOres))
			if reagents == currentRequest.totalOres then
				print("[SERVER] MELTING: reagents match totalOres, transitioning to CREATING_INGOT")
				return STATE.CREATING_INGOT, "All ores in furnace. Waiting for good temp and pressure"
			end
			sleep(4)
		end,
		exit = function()
			print("[SERVER] LEAVING STATE MELTING_MATERIALS")
		end,
	},
	[STATE.CREATING_INGOT] = {
		enter = function()
			print(string.format("[SERVER] ENTERING STATE CREATING_INGOT (recipeHash=%s totalOres=%s)",
				tostring(currentRequest.recipeHash), tostring(currentRequest.totalOres)))
		end,
		tick = function(currentRequest)
			-- TODO: Handle Furnace temp and pressure
			local reagents    = ic.read_id(furnace, LT.Reagents)
			local recipeHash  = ic.read_id(furnace, LT.RecipeHash)
			local furnaceOpen = ic.read_id(furnace, LT.Open)
			print(string.format("[SERVER] CREATING tick: reagents=%d recipeHash=%s (expected=%s) open=%d",
				reagents, tostring(recipeHash), tostring(currentRequest.recipeHash), furnaceOpen))
			if reagents == 0 then
				print("[SERVER] CREATING: reagents=0, all ingots delivered")
				if furnaceOpen ~= 0 then
					ic.write_id(furnace, LT.Open, 0)
				end
				return STATE.REQUEST_COMPLETE, "All ingots delivered"
			end
			if recipeHash == currentRequest.recipeHash and reagents == currentRequest.totalOres then
				print("[SERVER] CREATING: conditions met, opening furnace")
				ic.write_id(furnace, LT.Open, 1)
			else
				if recipeHash ~= currentRequest.recipeHash then
					print(string.format("[SERVER] CREATING: recipeHash mismatch (got %s want %s), keeping closed",
						tostring(recipeHash), tostring(currentRequest.recipeHash)))
				else
					print(string.format("[SERVER] CREATING: reagents mismatch (got %.1f want %.1f), keeping closed",
						reagents, currentRequest.totalOres))
				end
				if furnaceOpen ~= 0 then
					ic.write_id(furnace, LT.Open, 0)
				end
			end
			sleep(2)
		end,
		exit = function()
			print("[SERVER] LEAVING STATE CREATING_INGOT")
		end,
	},
	[STATE.REQUEST_COMPLETE] = {
		enter = function()
			print("[SERVER] ENTERING STATE REQUEST_COMPLETE")
		end,
		tick = function()
			print("[SERVER] REQUEST_COMPLETE: clearing request, returning to IDLE")
			currentRequest = nil
			return STATE.IDLE, "Ingots delivered"
		end,
		exit = function()
			print("[SERVER] LEAVING STATE REQUEST_COMPLETE")
		end,
	},
}

transition = function(newState, reason)
	local s = states[currentState]
	if s and s.exit then s.exit() end
	lastEvent = reason or newState
	currentState = newState
	print(string.format("[SERVER] TRANSITION → state=%s  reason=%s", newState, lastEvent))
	s = states[currentState]
	if s and s.enter then s.enter() end
	ic.net.publish("foundry/state", { state = currentState })
end

----------------
-- DEFS
----------------

local function getOreStock(ore)
	local silo = ic.find(foundry.getSiloName(ore))
	if silo == nil then
		print(string.format("[SERVER] getOreStock: silo not found for %s", ore))
		return 0
	end
	local slots = ic.read_id(silo, LT.Quantity)
	return slots * 50
end

----------------
-- SERVER
----------------

ic.net.register("get_status", function(payload, fromId, fromName)
	print(string.format("[SERVER] get_status request from %s → returning state=%s", tostring(fromName), currentState))
	return currentState
end)

ic.net.register("get_ores_stock", function(payload, fromId, fromName)
	print(string.format("[SERVER] get_ores_stock request from %s", tostring(fromName)))
	local stock = {}
	for _, value in ipairs(foundry.ORES) do
		stock[value] = getOreStock(value)
	end
	return stock
end)

ic.net.register("request_ingot", function(payload, fromId, fromName)
	print(string.format("[SERVER] request_ingot from %s: ingot=%s quantity=%s",
		tostring(fromName), tostring(payload and payload.ingot), tostring(payload and payload.quantity)))

	if currentState ~= STATE.IDLE then
		print(string.format("[SERVER] request_ingot: REJECTED — not IDLE (state=%s)", currentState))
		return { code = 500, message = "Foundry not ready" }
	end

	if payload.ingot == nil or payload.quantity == nil then
		print("[SERVER] request_ingot: REJECTED — missing ingot or quantity in payload")
		return { code = 500, message = "Ingot or Quantity Missing" }
	end

	if foundry.INGOTS_RECIPES[payload.ingot] == nil then
		print(string.format("[SERVER] request_ingot: REJECTED — unknown ingot '%s'", payload.ingot))
		return { code = 500, message = "Unknown Ingot " .. payload.ingot }
	end

	local recipe = foundry.INGOTS_RECIPES[payload.ingot]
	local quantity = payload.quantity
	if math.fmod(quantity, recipe.orderQty) > 0 then
		print(string.format("[SERVER] request_ingot: REJECTED — qty %d not multiple of orderQty %d", quantity,
			recipe.orderQty))
		return {
			code = 500,
			message = string.format("%s must be order by multiple of %d ", payload.ingot, recipe.orderQty),
		}
	end

	local neededOres = {}
	local totalOres = 0
	print(string.format("[SERVER] request_ingot: computing neededOres for %d x %s", quantity,
		payload.ingot))
	for key, value in pairs(recipe.ores) do
		neededOres[key] = math.floor(value * quantity)
		totalOres = math.floor(totalOres + neededOres[key])
		print(string.format("[SERVER]   ore=%s ratio=%.2f needed=%d", key, value, neededOres[key]))
	end
	print(string.format("[SERVER]   totalOres=%.1f", totalOres))

	local missingOres = {}
	for key, value in pairs(neededOres) do
		local silo = ic.find(foundry.getSiloName(key))
		if silo == nil then
			print(string.format("[SERVER] request_ingot: REJECTED — silo missing for ore '%s'", key))
			return { code = 500, message = "Silo for " .. key .. " is Missing" }
		end
		local available = ic.read_id(silo, LT.Quantity) * 50
		print(string.format("[SERVER]   silo %s: available=%d needed=%d", key, available, value))
		if available < value then
			missingOres[key] = value - available
			print(string.format("[SERVER]   => INSUFFICIENT: missing %.1f %s", missingOres[key], key))
		end
	end

	if next(missingOres) ~= nil then
		local missingOresList = "Missing"
		for key, value in pairs(missingOres) do
			missingOresList = string.format("%s %d %s", missingOresList, value, key)
		end
		print(string.format("[SERVER] request_ingot: REJECTED — %s", missingOresList))
		return { code = 500, message = missingOresList }
	end

	local channel = math.floor(math.random(1, 100000))
	local recipeHash = hash("Item" .. payload.ingot)
	currentRequest = {
		ores = neededOres,
		channel = channel,
		recipeHash = recipeHash,
		totalOres = totalOres,
	}
	print("[SERVER] request_ingot: ACCEPTED ")
	return { code = 200, message = channel }
end)

----------------
-- INIT
----------------
print("[SERVER] starting up, checking devices...")
checkDevices()
transition(#missingDevices > 0 and STATE.HALTED or STATE.IDLE, "Script started")

while true do
	local nextState, reason = states[currentState].tick(currentRequest)
	if nextState then
		transition(nextState, reason)
	end
end
