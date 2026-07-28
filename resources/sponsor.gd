class_name Sponsor
extends Resource

@export var sponsor_id: String = ""
@export var sponsor_name: String = ""
@export var required_reputation: int = 0
@export var signing_bonus: int = 0
@export var payment_per_race: int = 0
@export_enum("finish_race", "top_15", "top_10_finishes") var objective_type: String = "finish_race"
@export var objective_target: int = 1
@export var objective_bonus: int = 0
@export var contract_length: int = 12


func get_objective_description() -> String:
	match objective_type:
		"finish_race":
			return "Finish any race"
		"top_15":
			return "Finish in the top 15"
		"top_10_finishes":
			return "Score %d top-10 finishes" % objective_target
		_:
			return "Complete the sponsor objective"


func result_advances_objective(finishing_position: int) -> bool:
	match objective_type:
		"finish_race":
			return finishing_position > 0
		"top_15":
			return finishing_position > 0 and finishing_position <= 15
		"top_10_finishes":
			return finishing_position > 0 and finishing_position <= 10
		_:
			return false
