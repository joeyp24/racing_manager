extends Control

const TERMS := [
	["Consistency", "Reduces the size of random lap-time and race-result swings. A consistent driver is less likely to deliver an unexpectedly poor result."],
	["Aggression", "Adds overtaking pace, but aggressive race plans increase variance, incident exposure and component wear."],
	["Setup bonus", "Pace earned during practice by matching the car setup to the circuit. It is added directly to the race score."],
	["Department bonuses", "Permanent team-wide modifiers created by Headquarters upgrades. Engineering improves parts and reliability; other departments affect drivers, setup, sponsors and operations."],
	["Tyres", "Every series currently uses one standard race tyre. Worn tyres lose pace non-linearly, so pit timing and conservation still matter."],
	["Condition", "The health of a car or part. Low condition reduces effective performance and raises the risk that preparation checks block an entry."],
	["Strategy variance", "How widely a result can move around its expected value. Conservative narrows the range; aggressive widens it in exchange for pace."],
	["Staff ratings", "Role-specific attributes feed visible race effects: setup, reliability, repairs, incident prevention, restarts and pit-stop execution."],
]

@onready var terms_container: VBoxContainer = %terms_container


func _ready() -> void:
	for term in TERMS:
		var title := Label.new()
		title.text = str(term[0]).to_upper()
		title.theme_type_variation = &"SectionTitle"
		var explanation := Label.new()
		explanation.text = str(term[1])
		explanation.theme_type_variation = &"MutedLabel"
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		terms_container.add_child(title)
		terms_container.add_child(explanation)
