extends Resource
class_name CarPart

const PART_TYPES: Array[String] = [
	"Engine",
	"Suspension",
	"Brakes",
	"Chassis",
	"Drivetrain",
	"Body"
]

@export var part_name: String = "Standard Part"
@export_enum("Engine", "Suspension", "Brakes", "Chassis", "Drivetrain", "Body")
var part_type: String = "Engine"
@export var tier: String = "Standard"
@export var effect_name: String = "Power"
@export var effect_value: int = 0
# The part's contribution before condition and team-wide performance modifiers.
@export var base_performance_points: int = 8
@export var performance_bonus: int = 0
@export var purchase_price: int = 0
@export var sale_price: int = 0
@export_range(0, 100) var condition: int = 100
@export var manufactured_by: String = ""
@export_range(-30, 30) var reliability_modifier: int = 0
@export_range(-20, 20) var tyre_wear_modifier: int = 0
@export_range(-20, 20) var fuel_efficiency_modifier: int = 0


func get_effect_text() -> String:
	var sign_text: String = "+" if effect_value >= 0 else ""
	return "%s %s%d" % [effect_name, sign_text, effect_value]


func get_summary() -> String:
	return "%s · %s · %s · %d%% condition" % [tier, part_name, get_effect_text(), condition]


func get_effective_performance_bonus() -> int:
	return get_conditioned_performance_points() - base_performance_points


func get_conditioned_performance_points() -> int:
	return roundi(float(base_performance_points + performance_bonus) * float(condition) / 100.0)


func get_attribute_key() -> String:
	var normalized := effect_name.to_lower()
	if "power" in normalized or part_type == "Engine": return "power"
	if "aero" in normalized or part_type == "Body": return "aero"
	if "brak" in normalized or part_type == "Brakes": return "braking"
	if "fuel" in normalized: return "fuel"
	if "tyre" in normalized: return "tyres"
	return "grip"


func get_effective_attribute_modifier() -> float:
	return float(effect_value) * float(condition) / 100.0


func get_effective_reliability_modifier() -> float:
	return float(reliability_modifier) * float(condition) / 100.0
