class_name RaceFlowProgress
extends PanelContainer

const STAGE_NAMES: Array[String] = ["Entry", "Practice", "Qualifying", "Race", "Debrief"]

@export_range(0, 4) var current_stage: int = 0

@onready var stage_labels: Array[Label] = [
	%EntryStage,
	%PracticeStage,
	%QualifyingStage,
	%RaceStage,
	%DebriefStage,
]
@onready var context_label: Label = %ContextLabel


func _ready() -> void:
	set_stage(current_stage, context_label.text)


func set_stage(stage: int, context: String = "") -> void:
	current_stage = clampi(stage, 0, STAGE_NAMES.size() - 1)
	for index in range(stage_labels.size()):
		var label := stage_labels[index]
		if index < current_stage:
			label.text = "✓  %s" % STAGE_NAMES[index]
			label.theme_type_variation = &"SuccessLabel"
		elif index == current_stage:
			label.text = "●  %s" % STAGE_NAMES[index]
			label.theme_type_variation = &"BodyStrong"
		else:
			label.text = "○  %s" % STAGE_NAMES[index]
			label.theme_type_variation = &"MutedLabel"
	context_label.text = context
	context_label.visible = not context.is_empty()
