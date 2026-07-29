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
@export var performance_bonus: int = 0
@export var purchase_price: int = 0
@export var sale_price: int = 0
@export_range(0, 100) var condition: int = 100
@export var manufactured_by: String = ""


func get_effect_text() -> String:
	var sign_text: String = "+" if effect_value >= 0 else ""
	return "%s %s%d" % [effect_name, sign_text, effect_value]


func get_summary() -> String:
	return "%s · %s · %s · %d%% condition" % [tier, part_name, get_effect_text(), condition]


func get_effective_performance_bonus() -> int:
	return roundi(float(performance_bonus) * float(condition) / 100.0)
