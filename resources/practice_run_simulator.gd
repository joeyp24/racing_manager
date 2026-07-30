class_name PracticeRunSimulator
extends RefCounted

const RUN_LIMIT := 3
const DEFAULT_TYRE_SETS := {"Soft": 2, "Medium": 2, "Hard": 2, "Intermediate": 1, "Wet": 1}
const DEFAULT_SETUP := {
	"aero_balance": 0,
	"suspension": 0,
	"gearing": 0,
	"tyre_pressure": 0,
	"brake_bias": 0
}
const AXIS_LABELS := {
	"aero_balance": "aero balance",
	"suspension": "suspension",
	"gearing": "gearing",
	"tyre_pressure": "tyre pressure",
	"brake_bias": "brake bias"
}


static func get_ideal_setup(race: Race) -> Dictionary:
	var setup := DEFAULT_SETUP.duplicate()
	setup["aero_balance"] = clampi(roundi((race.handling_demand - race.power_demand) * 3.0), -2, 2)
	setup["gearing"] = clampi(roundi((race.power_demand - race.handling_demand) * 3.0), -2, 2)
	setup["suspension"] = {
		"Short Track": 1,
		"Speedway": -1,
		"Road Course": 1,
		"Street Course": 2
	}.get(race.track_type, 0)
	setup["tyre_pressure"] = clampi(roundi((0.9 - race.tyre_wear_factor) * 2.0 - race.heat_factor), -2, 2)
	setup["brake_bias"] = 1 if race.track_type in ["Road Course", "Street Course"] else 0
	return setup


static func apply_adjustment(setup: Dictionary, axis: String, delta: int) -> Dictionary:
	var adjusted := DEFAULT_SETUP.duplicate()
	adjusted.merge(setup, true)
	if adjusted.has(axis):
		adjusted[axis] = clampi(int(adjusted[axis]) + delta, -2, 2)
	return adjusted


static func simulate_run(
	race: Race,
	driver: Driver,
	staff_quality: float,
	setup: Dictionary,
	compound: String,
	run_number: int,
	seed: int
) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var ideal := get_ideal_setup(race)
	var setup_loss := 0.0
	var largest_axis := ""
	var largest_error := 0
	for axis in DEFAULT_SETUP:
		var error := absi(int(setup.get(axis, 0)) - int(ideal[axis]))
		setup_loss += float(error) * _axis_weight(axis, race)
		if error > largest_error:
			largest_error = error
			largest_axis = axis
	var compound_delta: float = float({"Soft": -0.34, "Medium": 0.0, "Hard": 0.26, "Intermediate":0.18, "Wet":0.36}.get(compound, 0.0))
	var compound_wear: float = float({"Soft": 8.5, "Medium": 5.5, "Hard": 3.5, "Intermediate":4.5, "Wet":3.8}.get(compound, 5.5))
	var wet_tyre := compound in ["Intermediate", "Wet"]
	if race.weather == "Wet":
		compound_delta += (-0.85 if compound == "Wet" else (-0.45 if compound == "Intermediate" else 1.55))
	elif race.weather == "Mixed":
		compound_delta += (-0.55 if compound == "Intermediate" else (0.20 if compound == "Wet" else 0.45))
	elif wet_tyre:
		compound_delta += 1.25 if compound == "Intermediate" else 2.10
	var driver_pace := float(driver.race_pace + driver.qualifying_pace) * 0.5
	var base_lap := 35.5 + float(race.difficulty) * 0.035 - (driver_pace - 50.0) * 0.025
	var feedback_quality := clampf(
		float(driver.car_feedback) * 0.58
		+ float(driver.consistency) * 0.17
		+ staff_quality * 0.25
		+ float(run_number - 1) * 5.0,
		15.0,
		98.0
	)
	var noise_limit := lerpf(0.65, 0.08, feedback_quality / 100.0)
	var lap_time := base_lap + setup_loss + float(compound_delta) + random.randf_range(-noise_limit, noise_limit)
	var feedback := _build_feedback(random, setup, ideal, largest_axis, feedback_quality)
	return {
		"run": run_number,
		"compound": compound,
		"lap_time": lap_time,
		"setup_loss": setup_loss,
		"feedback_quality": feedback_quality,
		"feedback": feedback,
		"guidance": _build_guidance(setup, ideal, feedback_quality),
		"tyre_wear": float(compound_wear) * race.tyre_wear_factor * lerpf(1.15, 0.72, float(driver.tyre_management) / 100.0),
		"setup": setup.duplicate(true)
	}


static func setup_score(race: Race, setup: Dictionary) -> float:
	var ideal := get_ideal_setup(race)
	var loss := 0.0
	for axis in DEFAULT_SETUP:
		loss += float(absi(int(setup.get(axis, 0)) - int(ideal[axis]))) * _axis_weight(axis, race)
	return clampf(100.0 - loss * 22.0, 0.0, 100.0)


static func _axis_weight(axis: String, race: Race) -> float:
	match axis:
		"aero_balance":
			return 0.12 + race.handling_demand * 0.12
		"gearing":
			return 0.12 + race.power_demand * 0.12
		"suspension":
			return 0.14 + race.handling_demand * 0.08
		"tyre_pressure":
			return 0.12 + race.tyre_wear_factor * 0.06
		"brake_bias":
			return 0.10 + (0.08 if race.track_type in ["Road Course", "Street Course"] else 0.02)
	return 0.12


static func _build_feedback(
	random: RandomNumberGenerator,
	setup: Dictionary,
	ideal: Dictionary,
	largest_axis: String,
	quality: float
) -> String:
	if largest_axis.is_empty():
		return "The car feels balanced. Focus on confirming long-run consistency."
	var actual_delta := int(ideal[largest_axis]) - int(setup.get(largest_axis, 0))
	var reported_delta := actual_delta
	if random.randf() > quality / 100.0:
		reported_delta = -actual_delta if random.randf() < 0.65 else 0
	var direction := "increase" if reported_delta > 0 else ("reduce" if reported_delta < 0 else "hold")
	var confidence := "high" if quality >= 78.0 else ("medium" if quality >= 52.0 else "low")
	return "%s confidence: %s %s." % [confidence.capitalize(), direction, AXIS_LABELS[largest_axis]]


static func _build_guidance(setup: Dictionary, ideal: Dictionary, quality: float) -> String:
	var suggestions: Array[String] = []
	for axis in DEFAULT_SETUP:
		var delta := int(ideal[axis]) - int(setup.get(axis, 0))
		if delta == 0:
			continue
		suggestions.append("%s %s" % ["increase" if delta > 0 else "reduce", AXIS_LABELS[axis]])
	if suggestions.is_empty():
		return "Setup window found; use the final run to verify tyre behavior."
	var visible_count := 1 if quality < 55.0 else mini(2, suggestions.size())
	return "Engineer guidance: %s." % " and ".join(suggestions.slice(0, visible_count))
