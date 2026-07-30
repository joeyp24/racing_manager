extends RefCounted
class_name PartCatalog


static func create_standard_part(part_type: String, base_performance_points: int = 8) -> CarPart:
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
	part.base_performance_points = base_performance_points
	part.effect_name = str(effects.get(part_type, "Performance"))
	return part


static func create_store_inventory() -> Array[CarPart]:
	var inventory: Array[CarPart] = []
	var definitions: Array[Dictionary] = [
		{"type": "Engine", "name": "Street V8", "effect": "Power", "value": 8, "base_pp": 13, "price": 3200},
		{"type": "Engine", "name": "Race-Built V8", "effect": "Power", "value": 16, "base_pp": 18, "price": 7200},
		{"type": "Suspension", "name": "Adjustable Coilovers", "effect": "Handling", "value": 9, "base_pp": 12, "price": 2600},
		{"type": "Suspension", "name": "Competition Suspension", "effect": "Handling", "value": 17, "base_pp": 16, "price": 5900},
		{"type": "Brakes", "name": "Slotted Brake Kit", "effect": "Braking", "value": 8, "base_pp": 11, "price": 2100},
		{"type": "Brakes", "name": "Carbon Race Brakes", "effect": "Braking", "value": 18, "base_pp": 15, "price": 5600},
		{"type": "Chassis", "name": "Chassis Bracing", "effect": "Durability", "value": 10, "base_pp": 11, "price": 2400},
		{"type": "Chassis", "name": "Reinforced Spaceframe", "effect": "Durability", "value": 20, "base_pp": 14, "price": 6100},
		{"type": "Drivetrain", "name": "Close-Ratio Gearbox", "effect": "Acceleration", "value": 9, "base_pp": 12, "price": 2800},
		{"type": "Drivetrain", "name": "Sequential Gearbox", "effect": "Acceleration", "value": 18, "base_pp": 17, "price": 6800},
		{"type": "Body", "name": "Aero Splitter Kit", "effect": "Aerodynamics", "value": 7, "base_pp": 12, "price": 2300},
		{"type": "Body", "name": "Wind-Tunnel Bodywork", "effect": "Aerodynamics", "value": 16, "base_pp": 16, "price": 6200}
	]
	for definition in definitions:
		var part := CarPart.new()
		part.part_type = str(definition["type"])
		part.part_name = str(definition["name"])
		part.tier = "Club" if int(definition["base_pp"]) < 15 else "Pro"
		part.effect_name = str(definition["effect"])
		part.effect_value = int(definition["value"])
		part.base_performance_points = int(definition["base_pp"])
		part.purchase_price = int(definition["price"])
		part.sale_price = roundi(part.purchase_price * 0.6)
		inventory.append(part)
	return inventory


static func create_manufactured_part(part_type: String, engineer: StaffMember) -> CarPart:
	var part := create_standard_part(part_type)
	var rating_factor := float(engineer.rating) / 100.0
	var specialty_bonus := 0
	if engineer.specialty == "Advanced manufacturing":
		specialty_bonus = 2
	elif engineer.specialty == "Engines" and part_type == "Engine":
		specialty_bonus = 2
	elif engineer.specialty == "Suspension" and part_type == "Suspension":
		specialty_bonus = 2
	elif engineer.specialty == "Aerodynamics" and part_type == "Body":
		specialty_bonus = 2
	part.part_name = "%s Prototype" % engineer.staff_name.split(" ")[0]
	part.tier = "Pro" if engineer.rating >= 80 else "Club"
	part.effect_value = 5 + roundi(rating_factor * 13.0)
	part.base_performance_points = 10 + roundi(rating_factor * 8.0) + specialty_bonus
	part.purchase_price = get_manufactured_value(part.base_performance_points - 8)
	part.sale_price = roundi(float(part.purchase_price) * 0.6)
	part.condition = 70 + roundi(rating_factor * 30.0)
	part.manufactured_by = engineer.staff_name
	return part


static func get_manufactured_value(performance_bonus: int) -> int:
	return 800 + performance_bonus * 500
