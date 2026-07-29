extends Control

@onready var project_rows: VBoxContainer = %project_rows
@onready var engineer_rows: VBoxContainer = %engineer_rows
@onready var part_type: OptionButton = %part_type
@onready var status_label: Label = %status_label

func _ready() -> void:
	for type in CarPart.PART_TYPES:
		part_type.add_item(type)
	refresh()

func refresh() -> void:
	clear(project_rows)
	clear(engineer_rows)
	var team: Team = GameManager.team
	if team.engineering_projects.is_empty():
		add_text(project_rows, "No active projects. Assign an engineer below; the part will arrive at the beginning of the next race week.")
	else:
		for project in team.engineering_projects:
			add_text(project_rows, "%s  •  %s development  •  Ready next race week" % [project.get("engineer_name", "Engineer"), project.get("part_type", "Part")])
	var engineers := team.get_engineers()
	if engineers.is_empty():
		add_text(engineer_rows, "No engineers employed. Hire one from the Staff Market in Employees.")
	for engineer in engineers:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s\nRating %d  •  Potential %d  •  %s" % [engineer.staff_name, engineer.rating, engineer.potential, engineer.specialty]
		var button := Button.new()
		button.text = "Assign Part"
		button.disabled = not team.is_engineer_available(engineer) or team.money < team.get_discounted_cost(Team.MANUFACTURING_BASE_COST)
		button.pressed.connect(start_project.bind(engineer))
		row.add_child(label)
		row.add_child(button)
		engineer_rows.add_child(row)

func start_project(engineer: StaffMember) -> void:
	var selected_type := part_type.get_item_text(part_type.selected)
	if GameManager.team.queue_part_project(engineer, selected_type):
		status_label.text = "%s started. Delivery: beginning of next race week." % selected_type
		GameManager.refresh_team_money()
		GameManager.save_game()
	else:
		status_label.text = "Unable to start that project. Check engineer availability and funds."
	refresh()

func add_text(parent: Control, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func clear(parent: Control) -> void:
	for child in parent.get_children():
		child.queue_free()
