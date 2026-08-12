class_name DecisionComparisonDrawer
extends PanelContainer

signal action_requested(context: Dictionary)

@onready var eyebrow: Label = %Eyebrow
@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var current_heading: Label = %CurrentHeading
@onready var candidate_heading: Label = %CandidateHeading
@onready var metric_rows: VBoxContainer = %MetricRows
@onready var upfront_value: Label = %UpfrontValue
@onready var recurring_value: Label = %RecurringValue
@onready var cash_after_value: Label = %CashAfterValue
@onready var season_end_value: Label = %SeasonEndValue
@onready var reserve_label: Label = %ReserveLabel
@onready var risk_label: Label = %RiskLabel
@onready var recommendation_label: Label = %RecommendationLabel
@onready var primary_button: Button = %PrimaryButton
@onready var close_button: Button = %CloseButton
@onready var cancel_button: Button = %CancelButton
@onready var review_scroll: ScrollContainer = %ReviewScroll

var current_context: Dictionary = {}


func _ready() -> void:
	close_button.pressed.connect(hide_comparison)
	cancel_button.pressed.connect(hide_comparison)
	primary_button.pressed.connect(_on_primary_pressed)


func display(model: Dictionary) -> void:
	review_scroll.scroll_vertical = 0
	current_context = model.get("context", {}) as Dictionary
	eyebrow.text = str(model.get("eyebrow", "DECISION REVIEW"))
	title.text = str(model.get("title", "Compare options"))
	subtitle.text = str(model.get("subtitle", "Review the trade-offs before committing."))
	current_heading.text = str(model.get("current_title", "CURRENT"))
	candidate_heading.text = str(model.get("candidate_title", "CANDIDATE"))
	_build_metrics(model.get("metrics", []) as Array)
	var finance := model.get("finance", {}) as Dictionary
	upfront_value.text = str(finance.get("upfront", "$0"))
	recurring_value.text = str(finance.get("recurring", "No change"))
	cash_after_value.text = str(finance.get("cash_after", "$0"))
	season_end_value.text = str(finance.get("season_end_after", "$0"))
	reserve_label.text = "Recommended reserve  ·  %s" % str(finance.get("reserve", "$0"))
	var risk_level := str(model.get("risk_level", "safe"))
	risk_label.text = "%s  ·  %s" % [_risk_heading(risk_level), str(model.get("risk", "Review this decision."))]
	risk_label.theme_type_variation = _risk_variation(risk_level)
	recommendation_label.text = "RECOMMENDATION\n%s" % str(model.get("recommendation", "Choose the option that best fits the team plan."))
	primary_button.text = str(model.get("action_label", "Confirm decision"))
	primary_button.disabled = not bool(model.get("action_enabled", true))
	primary_button.tooltip_text = str(model.get("disabled_reason", "")) if primary_button.disabled else str(model.get("action_tooltip", "Commit this decision."))
	visible = true
	if primary_button.disabled:
		close_button.grab_focus()
	else:
		primary_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_comparison()
		get_viewport().set_input_as_handled()


func hide_comparison() -> void:
	visible = false
	current_context.clear()


func _build_metrics(metrics: Array) -> void:
	for child in metric_rows.get_children():
		child.queue_free()
	for value in metrics:
		var metric := value as Dictionary
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 30.0
		var metric_label := _cell(str(metric.get("label", "Metric")), 112.0, &"MutedLabel")
		var current_value := _cell(str(metric.get("current", "—")), 96.0, &"BodyStrong")
		var candidate_value := _cell(str(metric.get("candidate", "—")), 96.0, &"BodyStrong")
		var delta := _cell(str(metric.get("delta", "")), 82.0, _impact_variation(int(metric.get("impact", DecisionComparisonModel.NEUTRAL))))
		row.add_child(metric_label)
		row.add_child(current_value)
		row.add_child(candidate_value)
		row.add_child(delta)
		var detail := str(metric.get("detail", ""))
		if not detail.is_empty():
			row.tooltip_text = detail
		metric_rows.add_child(row)


func _cell(text_value: String, width: float, variation: StringName) -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = width
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = text_value
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.theme_type_variation = variation
	return label


func _impact_variation(impact: int) -> StringName:
	match impact:
		DecisionComparisonModel.IMPROVES:
			return &"SuccessLabel"
		DecisionComparisonModel.WORSENS:
			return &"DangerLabel"
		DecisionComparisonModel.WARNING:
			return &"WarningLabel"
	return &"MutedLabel"


func _risk_heading(level: String) -> String:
	return {"safe": "WITHIN PLAN", "warning": "CHECK RISK", "blocked": "BLOCKED"}.get(level, "REVIEW")


func _risk_variation(level: String) -> StringName:
	return {"safe": &"SuccessLabel", "warning": &"WarningLabel", "blocked": &"DangerLabel"}.get(level, &"InfoLabel")


func _on_primary_pressed() -> void:
	if primary_button.disabled:
		return
	var context := current_context.duplicate()
	hide_comparison()
	action_requested.emit(context)
