extends RefCounted
class_name DepartmentCatalog

const MAX_LEVEL: int = 5
const BONUS_PER_LEVEL: float = 2.5

const DEPARTMENTS: Dictionary = {
	"engineering": {
		"name": "Engineering Department",
		"description": "Improves all car parts and makes repairs more effective.",
		"purchase_cost": 7500,
		"upgrade_costs": [12000, 20000, 32000, 50000]
	},
	"wind_tunnel": {
		"name": "Wind Tunnel Department",
		"description": "Adds an extra performance boost to body parts.",
		"purchase_cost": 9000,
		"upgrade_costs": [14000, 23000, 36000, 55000]
	},
	"driver_development": {
		"name": "Driver Development Department",
		"description": "Boosts driver race performance and season development.",
		"purchase_cost": 8000,
		"upgrade_costs": [13000, 21000, 34000, 52000]
	},
	"simulator": {
		"name": "Simulator Department",
		"description": "Improves preparation and provides a crew-chief performance boost.",
		"purchase_cost": 7000,
		"upgrade_costs": [11000, 18000, 29000, 45000]
	},
	"accounting": {
		"name": "Accounting Department",
		"description": "Reduces the cost of cars, parts, contracts, repairs, and HQ upgrades.",
		"purchase_cost": 10000,
		"upgrade_costs": [16000, 26000, 40000, 60000]
	},
	"marketing": {
		"name": "Marketing Department",
		"description": "Increases the number of fans earned after every race.",
		"purchase_cost": 6500,
		"upgrade_costs": [10000, 17000, 27000, 42000]
	},
	"scouting": {
		"name": "Scouting Department",
		"description": "Unlocks Scouting and makes driver potential estimates more accurate.",
		"purchase_cost": 8500,
		"upgrade_costs": [13500, 22000, 35000, 54000]
	},
	"cheating": {
		"name": "Secret Department",
		"description": "Boosts car speed, but creates an increasing risk of costly race penalties.",
		"purchase_cost": 25000,
		"upgrade_costs": [40000, 65000, 95000, 140000]
	}
}


static func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for department_id in DEPARTMENTS:
		ids.append(str(department_id))
	return ids


static func get_data(department_id: String) -> Dictionary:
	return DEPARTMENTS.get(department_id, {}) as Dictionary


static func get_bonus(level: int) -> float:
	return clampi(level, 0, MAX_LEVEL) * BONUS_PER_LEVEL


static func get_base_cost(department_id: String, current_level: int) -> int:
	var data := get_data(department_id)
	if data.is_empty() or current_level >= MAX_LEVEL:
		return 0
	if current_level == 0:
		return int(data.get("purchase_cost", 0))
	var upgrade_costs: Array = data.get("upgrade_costs", [])
	return int(upgrade_costs[current_level - 1])
