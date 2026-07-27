extends Control

@onready var team_name_label: Label = %team_name_label
@onready var money_label: Label = %money_label
@onready var cars_owned_label: Label = %cars_owned_label
@onready var garage_value_label: Label = %garage_value_label
@onready var reputation_label: Label = %reputation_label


func _ready() -> void:
	if GameManager.team == null:
		push_error("Dashboard cannot display because GameManager.team is null.")
		return

	if not GameManager.team.changed.is_connected(_on_team_changed):
		GameManager.team.changed.connect(_on_team_changed)

	update_dashboard()


func _exit_tree() -> void:
	if GameManager.team == null:
		return

	if GameManager.team.changed.is_connected(_on_team_changed):
		GameManager.team.changed.disconnect(_on_team_changed)


func _on_team_changed() -> void:
	update_dashboard()


func update_dashboard() -> void:
	var team: Team = GameManager.team

	if team == null:
		return

	var cars_owned: int = get_cars_owned(team)
	var garage_value: int = get_garage_value(team)

	team_name_label.text = "Team: %s" % team.team_name
	money_label.text = "Money: $%s" % String.num_int64(team.money)

	cars_owned_label.text = "Cars Owned: %d / %d" % [
		cars_owned,
		team.cars.size()
	]

	garage_value_label.text = (
		"Garage Value: $%s"
		% String.num_int64(garage_value)
	)

	reputation_label.text = "Reputation: %d" % team.reputation


func get_cars_owned(team: Team) -> int:
	var total: int = 0

	for car in team.cars:
		if car != null:
			total += 1

	return total


func get_garage_value(team: Team) -> int:
	var total_value: int = 0

	for car in team.cars:
		if car != null:
			total_value += car.value

	return total_value
