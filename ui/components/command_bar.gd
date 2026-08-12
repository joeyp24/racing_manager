class_name CommandBar
extends PanelContainer

signal action_requested(action: String)

@onready var next_label: Label = %NextLabel
@onready var blocker_label: Label = %BlockerLabel
@onready var consequence_label: Label = %ConsequenceLabel
@onready var status_label: Label = %StatusLabel
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
	var status := str(model.get("status", ""))
	next_label.text = "NEXT ACTION  ·  " + _destination_name(current_action).to_upper()
	blocker_label.text = str(model.get("title", "Review your team"))
	consequence_label.text = "%s  ·  %s" % [str(model.get("reason", "")), str(model.get("consequence", ""))]
	status_label.text = "%s  %s" % [_status_icon(status), _status_name(status)]
	status_label.theme_type_variation = _status_variation(status)
	tooltip_text = consequence_label.text
	primary_button.text = str(model.get("action_label", "Review"))
	primary_button.disabled = current_action.is_empty()
	primary_button.tooltip_text = "Go to %s" % _destination_name(current_action)
	_build_checklist(model.get("checks", []) as Array)


func toggle_expanded() -> void:
	expanded = not expanded
	checklist.visible = expanded
	expand_button.text = "HIDE READINESS  ▴" if expanded else "READINESS  ▾"


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
	if not checks.is_empty() and not expanded:
		expand_button.text = "READINESS %d  ▾" % checks.size()


func _status_icon(status: String) -> String:
	return {RaceReadiness.READY: "✓", RaceReadiness.SUBOPTIMAL: "!", RaceReadiness.BLOCKED: "×"}.get(status, "•")


func _status_name(status: String) -> String:
	return {RaceReadiness.READY: "READY", RaceReadiness.SUBOPTIMAL: "ATTENTION", RaceReadiness.BLOCKED: "BLOCKED"}.get(status, "REVIEW")


func _status_variation(status: String) -> StringName:
	return {RaceReadiness.READY: &"SuccessLabel", RaceReadiness.SUBOPTIMAL: &"WarningLabel", RaceReadiness.BLOCKED: &"DangerLabel"}.get(status, &"InfoLabel")


func _destination_name(action: String) -> String:
	return {
		"dashboard": "Dashboard", "calendar": "Race Calendar", "championship": "Championship",
		"offseason": "Offseason", "drivers": "Drivers", "driver_market": "Driver Market",
		"engineering": "Engineering", "garage": "Garage", "dealership": "Marketplace",
		"staff": "Staff", "finances": "Finances", "sponsors": "Sponsors",
		"reputation": "Team Standing", "race_entry": "Race Entry",
		"race_results": "Race Report", "continue_weekend": "Race Weekend",
	}.get(action, "Team HQ")


func _on_primary_pressed() -> void:
	if not current_action.is_empty():
		action_requested.emit(current_action)
