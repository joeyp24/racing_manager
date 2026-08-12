class_name DecisionOutcomeReceipt
extends PanelContainer

signal action_requested(scene_path: String)

const STATUS_COLORS := {
	"success": Color("42d483"),
	"error": Color("ff626f"),
	"info": Color("6ca8ff"),
}

@onready var status_bar: ColorRect = %StatusBar
@onready var status_icon: Label = %StatusIcon
@onready var eyebrow: Label = %Eyebrow
@onready var title: Label = %Title
@onready var message: Label = %Message
@onready var detail: Label = %Detail
@onready var finance_receipt: PanelContainer = %FinanceReceipt
@onready var cash_effect: Label = %CashEffect
@onready var balance: Label = %Balance
@onready var dismiss_button: Button = %DismissButton
@onready var action_button: Button = %ActionButton
@onready var close_button: Button = %CloseButton
@onready var timer: Timer = %Timer

var current_action_path := ""
var current_duration := 8.0
var entrance_tween: Tween = null


func _ready() -> void:
	dismiss_button.pressed.connect(hide_receipt)
	close_button.pressed.connect(hide_receipt)
	action_button.pressed.connect(_on_action_pressed)
	timer.timeout.connect(hide_receipt)
	mouse_entered.connect(timer.stop)
	mouse_exited.connect(_restart_timer)


func display(model: Dictionary, reduced_motion: bool = false) -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	var status := str(model.get("status", "info"))
	status_bar.color = STATUS_COLORS.get(status, STATUS_COLORS.info)
	status_icon.text = {"success": "✓", "error": "!", "info": "i"}.get(status, "i")
	status_icon.theme_type_variation = _status_variation(status)
	eyebrow.text = str(model.get("eyebrow", "TEAM UPDATE"))
	title.text = str(model.get("title", "Update complete"))
	message.text = str(model.get("message", "The team state has been updated."))
	detail.text = str(model.get("detail", ""))
	detail.visible = not detail.text.is_empty()
	finance_receipt.visible = bool(model.get("show_finance", false))
	cash_effect.text = str(model.get("cash_effect", "$0"))
	cash_effect.theme_type_variation = _cash_variation(int(model.get("cash_delta", 0)))
	balance.text = str(model.get("balance_text", "$0"))
	current_action_path = str(model.get("action_path", ""))
	action_button.text = str(model.get("action_label", "View update"))
	action_button.visible = not current_action_path.is_empty() and not action_button.text.is_empty()
	visible = true
	if entrance_tween != null and entrance_tween.is_valid():
		entrance_tween.kill()
	if not reduced_motion:
		modulate.a = 0.0
		entrance_tween = create_tween()
		entrance_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		entrance_tween.tween_property(self, "modulate:a", 1.0, 0.14)
	else:
		modulate.a = 1.0
	current_duration = float(model.get("duration", 8.0))
	timer.start(current_duration)
	if previous_focus != null and not previous_focus.is_visible_in_tree():
		(action_button if action_button.visible else dismiss_button).call_deferred("grab_focus")


func hide_receipt() -> void:
	timer.stop()
	visible = false
	current_action_path = ""
	if action_button.has_focus() or dismiss_button.has_focus() or close_button.has_focus():
		get_viewport().gui_release_focus()


func _restart_timer() -> void:
	if visible and timer.is_stopped():
		timer.start(current_duration)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_receipt()
		get_viewport().set_input_as_handled()


func _on_action_pressed() -> void:
	if current_action_path.is_empty():
		return
	var target := current_action_path
	hide_receipt()
	action_requested.emit(target)


func _status_variation(status: String) -> StringName:
	return {"success": &"SuccessLabel", "error": &"DangerLabel", "info": &"InfoLabel"}.get(status, &"InfoLabel")


func _cash_variation(amount: int) -> StringName:
	if amount > 0:
		return &"SuccessLabel"
	if amount < 0:
		return &"WarningLabel"
	return &"MutedLabel"
