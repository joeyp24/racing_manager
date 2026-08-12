class_name StatusMetric
extends PanelContainer

signal activated

@onready var eyebrow_label: Label = %EyebrowLabel
@onready var value_label: Label = %ValueLabel
@onready var detail_label: Label = %DetailLabel
@onready var progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))


func display(eyebrow: String, value: String, detail: String, value_variation: StringName = &"BodyStrong") -> void:
	eyebrow_label.text = eyebrow
	value_label.text = value
	value_label.theme_type_variation = value_variation
	detail_label.text = detail
	tooltip_text = "%s\n%s" % [value, detail]


func set_progress(value: float, maximum: float) -> void:
	progress_bar.visible = maximum > 0.0
	progress_bar.max_value = maxf(1.0, maximum)
	progress_bar.value = clampf(value, 0.0, progress_bar.max_value)


func _gui_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var accepted: bool = event.is_action_pressed("ui_accept")
	if clicked or accepted:
		activated.emit()
		accept_event()


func _set_hovered(hovered: bool) -> void:
	theme_type_variation = &"StatusMetricHoverPanel" if hovered else &"StatusMetricPanel"
