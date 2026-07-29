class_name CommandBar
extends PanelContainer

signal action_requested(action: String)

@onready var next_label: Label = %NextLabel
@onready var blocker_label: Label = %BlockerLabel
@onready var consequence_label: Label = %ConsequenceLabel
@onready var primary_button: Button = %PrimaryButton
@onready var expand_button: Button = %ExpandButton
@onready var checklist: VBoxContainer = %Checklist

var current_action := ""
var expanded := false


func _ready() -> void:
	primary_button.pressed.connect(_on_primary_pressed)
	expand_button.pressed.connect(toggle_expanded)


func display(model: Dictionary) -> void:
	current_action = str(model.get("action", ""))
	next_label.text = "NEXT  ·  " + str(model.get("title", "Review your team"))
	blocker_label.text = _status_icon(str(model.get("status", ""))) + "  " + str(model.get("reason", ""))
	consequence_label.text = str(model.get("consequence", ""))
	tooltip_text = consequence_label.text
	primary_button.text = str(model.get("action_label", "Review"))
	primary_button.disabled = current_action.is_empty()
	primary_button.tooltip_text = "Go to %s" % primary_button.text.trim_suffix(" →")
	_build_checklist(model.get("checks", []) as Array)


func toggle_expanded() -> void:
	expanded = not expanded
	checklist.visible = expanded
	expand_button.text = "Hide  ▴" if expanded else "List  ▾"


func _build_checklist(checks: Array) -> void:
	for child in checklist.get_children():
		child.queue_free()
	for check_value in checks:
		var check := check_value as Dictionary
		var row := Label.new()
		row.text = "%s  %s  ·  %s" % [_status_icon(str(check.get("status", ""))), str(check.get("title", "CHECK")), str(check.get("explanation", ""))]
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.tooltip_text = str(check.get("explanation", ""))
		checklist.add_child(row)
	expand_button.visible = not checks.is_empty()


func _status_icon(status: String) -> String:
	return {RaceReadiness.READY: "✓", RaceReadiness.SUBOPTIMAL: "⚠", RaceReadiness.BLOCKED: "✕"}.get(status, "•")


func _on_primary_pressed() -> void:
	if not current_action.is_empty():
		action_requested.emit(current_action)
