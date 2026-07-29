class_name ReadinessRow
extends PanelContainer

signal action_requested(action: String)

@onready var status_label: Label = %status_label
@onready var title_label: Label = %title_label
@onready var explanation_label: Label = %explanation_label
@onready var threshold_label: Label = %threshold_label
@onready var action_button: Button = %action_button


func _ready() -> void:
	action_button.pressed.connect(_on_action_pressed)


func setup(check: Dictionary) -> void:
	var status := str(check.get("status", RaceReadiness.READY))
	status_label.text = {RaceReadiness.READY: "READY", RaceReadiness.SUBOPTIMAL: "WARNING", RaceReadiness.BLOCKED: "BLOCKED"}.get(status, "READY")
	status_label.modulate = {RaceReadiness.READY: Color("43d68a"), RaceReadiness.SUBOPTIMAL: Color("ffb547"), RaceReadiness.BLOCKED: Color("ff667a")}.get(status, Color.WHITE)
	title_label.text = str(check.get("title", "READINESS"))
	explanation_label.text = str(check.get("explanation", ""))
	threshold_label.text = str(check.get("threshold", ""))
	threshold_label.visible = not threshold_label.text.is_empty()
	action_button.text = str(check.get("action_label", "Review"))
	action_button.set_meta("action", str(check.get("action", "")))
	action_button.visible = not str(check.get("action", "")).is_empty()


func _on_action_pressed() -> void:
	action_requested.emit(str(action_button.get_meta("action", "")))
