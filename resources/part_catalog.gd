extends RefCounted
class_name PartCatalog


static func create_standard_part(part_type: String) -> CarPart:
	var effects: Dictionary = {
		"Engine": "Power",
		"Suspension": "Handling",
		"Brakes": "Braking",
		"Chassis": "Durability",
		"Drivetrain": "Acceleration",
		"Body": "Aerodynamics"
	}
	var part := CarPart.new()
	part.part_type = part_type
	part.part_name = "Factory %s" % part_type
	part.tier = "Standard"
	part.effect_name = str(effects.get(part_type, "Performance"))
	return part


static func create_store_inventory() -> Array[CarPart]:
	var inventory: Array[CarPart] = []
	var definitions: Array[Dictionary] = [
		{"type": "Engine", "name": "Street V8", "effect": "Power", "value": 8, "bonus": 5, "price": 3200},
		{"type": "Engine", "name": "Race-Built V8", "effect": "Power", "value": 16, "bonus": 10, "price": 7200},
		{"type": "Suspension", "name": "Adjustable Coilovers", "effect": "Handling", "value": 9, "bonus": 4, "price": 2600},
		{"type": "Suspension", "name": "Competition Suspension", "effect": "Handling", "value": 17, "bonus": 8, "price": 5900},
		{"type": "Brakes", "name": "Slotted Brake Kit", "effect": "Braking", "value": 8, "bonus": 3, "price": 2100},
		{"type": "Brakes", "name": "Carbon Race Brakes", "effect": "Braking", "value": 18, "bonus": 7, "price": 5600},
		{"type": "Chassis", "name": "Chassis Bracing", "effect": "Durability", "value": 10, "bonus": 3, "price": 2400},
		{"type": "Chassis", "name": "Reinforced Spaceframe", "effect": "Durability", "value": 20, "bonus": 6, "price": 6100},
		{"type": "Drivetrain", "name": "Close-Ratio Gearbox", "effect": "Acceleration", "value": 9, "bonus": 4, "price": 2800},
		{"type": "Drivetrain", "name": "Sequential Gearbox", "effect": "Acceleration", "value": 18, "bonus": 9, "price": 6800},
		{"type": "Body", "name": "Aero Splitter Kit", "effect": "Aerodynamics", "value": 7, "bonus": 4, "price": 2300},
		{"type": "Body", "name": "Wind-Tunnel Bodywork", "effect": "Aerodynamics", "value": 16, "bonus": 8, "price": 6200}
	]
	for definition in definitions:
		var part := CarPart.new()
		part.part_type = str(definition["type"])
		part.part_name = str(definition["name"])
		part.tier = "Club" if int(definition["bonus"]) < 7 else "Pro"
		part.effect_name = str(definition["effect"])
		part.effect_value = int(definition["value"])
		part.performance_bonus = int(definition["bonus"])
		part.purchase_price = int(definition["price"])
		part.sale_price = roundi(part.purchase_price * 0.6)
		inventory.append(part)
	return inventory


static func create_manufactured_part(part_type: String, engineer: StaffMember) -> CarPart:
	var part := create_standard_part(part_type)
	var rating_factor := float(engineer.rating) / 100.0
	part.part_name = "%s Prototype" % engineer.staff_name.split(" ")[0]
	part.tier = "Pro" if engineer.rating >= 80 else "Club"
	part.effect_value = 5 + roundi(rating_factor * 13.0)
	part.performance_bonus = 2 + roundi(rating_factor * 8.0)
	part.purchase_price = get_manufactured_value(part.performance_bonus)
	part.sale_price = roundi(float(part.purchase_price) * 0.6)
	part.condition = 70 + roundi(rating_factor * 30.0)
	part.manufactured_by = engineer.staff_name
	return part


static func get_manufactured_value(performance_bonus: int) -> int:
	return 800 + performance_bonus * 500
