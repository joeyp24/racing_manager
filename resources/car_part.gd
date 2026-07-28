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


func get_effect_text() -> String:
	var sign_text: String = "+" if effect_value >= 0 else ""
	return "%s %s%d" % [effect_name, sign_text, effect_value]


func get_summary() -> String:
	return "%s · %s · %s" % [tier, part_name, get_effect_text()]
