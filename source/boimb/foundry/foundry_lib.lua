--@module foundry_lib
-- Foundry utilities
local foundry_lib = {}

foundry_lib.SILO_BASE_NAME = "SDB Silo-"
foundry_lib.SORTER_BASE_NAME = "Logic Sorter-"
foundry_lib.STACKER_BASE_NAME = "Stacker-"
foundry_lib.SILO_CHUTE_VALVE_BASE_NAME = "Chute Digital Valve-"
foundry_lib.ORES = { "Iron", "Copper", "Silicon", "Gold", "Silver", "Cobalt", "Lead", "Nickel", "Coal", "Uranium" }
foundry_lib.ORES_NOT_MANAGED = { "Oxite", "Nitrice", "Volatiles", "Ice", "ReagentMix" } -- Deal with reagent as gases for now => Not in Silos
function foundry_lib.getSiloName(ore)
	return foundry_lib.SILO_BASE_NAME .. ore
end

function foundry_lib.getSiloValveName(ore)
	return foundry_lib.SILO_CHUTE_VALVE_BASE_NAME .. ore
end

foundry_lib.STATE = {
	HALTED = "HALTED",
	MAINTENANCE = "MAINTENANCE",
	IDLE = "IDLE",
	DELIVERING_MATERIALS = "DELIVERING_MATERIALS",
	MELTING_MATERIALS = "MELTING_MATERIALS",
	CREATING_INGOT = "CREATING_INGOT",
	REQUEST_COMPLETE = "REQUEST_COMPLETE",
}

foundry_lib.INGOT_CATEGORIES = {
	BASIC = "BASIC",
	ALLOY = "ALLOY",
	SUPER_ALLOY = "SUPER_ALLOY",
}

-- Ratios: ores = { [ore] = ratio } — ratios are per-unit, quantities are multiples of orderQty
foundry_lib.INGOTS_RECIPES = {
	IronIngot = {
		ores = { Iron = 1 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.BASIC,
	},
	CopperIngot = {
		ores = { Copper = 1 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.BASIC,
	},
	SiliconIngot = {
		ores = { Silicon = 1 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.BASIC,
	},
	GoldIngot = {
		ores = { Gold = 1 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.BASIC,
	},
	SilverIngot = {
		ores = { Silver = 1 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.BASIC,
	},
	LeadIngot = {
		ores = { Lead = 1 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.BASIC,
	},
	NickelIngot = {
		ores = { Nickel = 1 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.BASIC,
	},
	ConstantanIngot = {
		ores = { Copper = 0.5, Nickel = 0.5 },
		orderQty = 100,
		category = foundry_lib.INGOT_CATEGORIES.ALLOY,
	},
	InvarIngot = {
		ores = { Iron = 0.5, Nickel = 0.5 },
		orderQty = 100,
		category = foundry_lib.INGOT_CATEGORIES.ALLOY,
	},
	SteelIngot = {
		ores = { Iron = 0.75, Coal = 0.25 },
		orderQty = 200,
		category = foundry_lib.INGOT_CATEGORIES.ALLOY,
	},
	ElectrumIngot = {
		ores = { Gold = 0.5, Silver = 0.5 },
		orderQty = 100,
		category = foundry_lib.INGOT_CATEGORIES.ALLOY,
	},
	SolderIngot = {
		ores = { Iron = 0.5, Lead = 0.5 },
		orderQty = 100,
		category = foundry_lib.INGOT_CATEGORIES.ALLOY,
	},
	-- AstroloyIngot = { ores = { Copper = 1, Steel = 2, Cobalt = 1 }, orderQty = 50, category = foundry_lib.INGOT_CATEGORIES.SUPER_ALLOY },
	-- InconelIngot  = { ores = { Gold = 2, Steel = 1, Nickel = 1 },   orderQty = 50, category = foundry_lib.INGOT_CATEGORIES.SUPER_ALLOY },
	WaspaloyIngot = {
		ores = { Silver = 1, Nickel = 1, Lead = 2 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.SUPER_ALLOY,
	},
	HastelloyIngot = {
		ores = { Silver = 2, Nickel = 1, Cobalt = 1 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.SUPER_ALLOY,
	},
	StelliteIngot = {
		ores = { Silver = 1, Silicon = 2, Cobalt = 1 },
		orderQty = 50,
		category = foundry_lib.INGOT_CATEGORIES.SUPER_ALLOY,
	},
}

return foundry_lib
