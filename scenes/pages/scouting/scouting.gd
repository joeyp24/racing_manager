extends Control

@onready var candidates: VBoxContainer = %candidates


func _ready() -> void:
	var level := GameManager.team.get_department_level("scouting")
	if level <= 0:
		return
	var uncertainty := 12 - (level * 2)
	for driver in GameManager.team.drivers:
		if driver == null or driver.is_player_driver:
			continue
		var label := Label.new()
		var current_ability := driver.get_overall_rating()
		var potential_overall := driver.get_potential_overall()
		var low := maxi(current_ability, potential_overall - uncertainty)
		var high := mini(99, potential_overall + uncertainty)
		var estimate := str(potential_overall) if uncertainty == 2 else "%d–%d" % [low, high]
		label.text = "%s  •  Age %d  •  %d OVR  •  Potential estimate: %s\nIndividual attribute ceilings require a detailed scouting report." % [driver.driver_name, driver.age, current_ability, estimate]
		candidates.add_child(label)
