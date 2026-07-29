extends Control

@onready var roster_container: VBoxContainer = %roster_container
@onready var summary_label: Label = %summary_label

func _ready() -> void:
	refresh_roster()

func refresh_roster() -> void:
	var team: Team = GameManager.team
	var drivers := team.get_contracted_drivers()
	summary_label.text = "%d / %d team drivers • Ratings and long-term potential" % [drivers.size(), team.get_driver_roster_limit()]
	for child in roster_container.get_children():
		child.queue_free()
	if drivers.is_empty():
		var empty := Label.new()
		empty.text = "No drivers are under contract. Visit Driver Hiring from the Employees section."
		roster_container.add_child(empty)
		return
	for driver in drivers:
		roster_container.add_child(create_driver_card(driver))

func create_driver_card(driver: Driver) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(0, 150)
	var content := VBoxContainer.new()
	var heading := Label.new()
	heading.theme_type_variation = &"SectionTitle"
	heading.text = "%s  •  %s" % [driver.driver_name, driver.archetype]
	var ratings := Label.new()
	ratings.text = "SKILL  %d     CONSISTENCY  %d     AGGRESSION  %d     POTENTIAL  %d" % [driver.skill, driver.consistency, driver.aggression, driver.potential]
	ratings.add_theme_font_size_override("font_size", 18)
	var details := Label.new()
	details.theme_type_variation = &"MutedLabel"
	details.text = "Age %d  •  Development %s  •  %d starts / %d wins / %d podiums  •  $%s per race" % [driver.age, driver.get_development_rate(), driver.career_starts, driver.career_wins, driver.career_podiums, format_number(driver.salary)]
	content.add_child(heading)
	content.add_child(ratings)
	content.add_child(details)
	card.add_child(content)
	return card

func format_number(number: int) -> String:
	var value := str(number)
	var formatted := ""
	while value.length() > 3:
		formatted = "," + value.right(3) + formatted
		value = value.left(value.length() - 3)
	return value + formatted
