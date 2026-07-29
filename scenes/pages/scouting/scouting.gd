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
		var current_ability: int = (driver.skill + driver.consistency + driver.aggression) / 3
		var low := maxi(current_ability, driver.potential - uncertainty)
		var high := mini(100, driver.potential + uncertainty)
		var estimate := str(driver.potential) if uncertainty == 2 else "%d–%d" % [low, high]
		label.text = "%s  •  Age %d  •  Current %d  •  Potential estimate: %s" % [driver.driver_name, driver.age, current_ability, estimate]
		candidates.add_child(label)
