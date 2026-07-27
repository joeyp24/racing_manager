extends Node

# Persistent Player Data
var money: int = 50000
var reputation: int = 100
var current_series: String = "Local Short Track Series"

func _ready() -> void:
	print("GameManager loaded! Starting money: $", money)
