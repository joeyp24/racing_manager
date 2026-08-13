extends Resource
class_name Car

const DAMAGE_COMPONENTS: Array[String] = ["aerodynamics", "suspension", "engine", "brakes", "drivetrain"]
const DAMAGE_LABELS: Dictionary = {
	"aerodynamics": "Aerodynamics",
	"suspension": "Suspension",
	"engine": "Engine",
	"brakes": "Brakes",
	"drivetrain": "Drivetrain"
}

@export var name: String = "Starter Stock Car"
@export var series_id: String = "local_short_track"

@export var manufacturer: String = "Generic Motors"
@export var model: String = "Stock Car"
@export var year: int = 2026

# Compatibility-only input for pre-v8 resources. Runtime car creation and PP
# calculations must never use this value.
@export_storage var legacy_performance: int = 50
@export var condition: int = 100
@export_range(0, 100) var horsepower: int = 50
@export_range(0, 100) var aerodynamic_efficiency: int = 50
@export_range(0, 100) var mechanical_grip: int = 50
@export_range(0, 100) var braking: int = 50
@export_range(0, 100) var tyre_preservation: int = 50
@export_range(0, 100) var fuel_efficiency: int = 50
@export_range(0, 100) var reliability: int = 75

@export var mileage: int = 0

@export var purchase_price: int = 10000
@export var value: int = 7500

@export var installed_parts: Array[CarPart] = []
@export var damage_state: Dictionary = {}
@export var workshop_state: Dictionary = {}
@export var workshop_jobs: Array[Dictionary] = []


func _set(property: StringName, value: Variant) -> bool:
	# Godot forwards the removed `performance` property from old .tres saves here.
	if property == &"performance":
		legacy_performance = int(value)
		return true
	return false


func ensure_standard_parts() -> void:
	ensure_damage_state()
	ensure_workshop_state()
	for part_type in CarPart.PART_TYPES:
		if get_part(part_type) == null:
			installed_parts.append(PartCatalog.create_standard_part(part_type))


func get_part(part_type: String) -> CarPart:
	for part in installed_parts:
		if part != null and part.part_type == part_type:
			return part
	return null


func install_part(new_part: CarPart) -> CarPart:
	if new_part == null or not CarPart.PART_TYPES.has(new_part.part_type):
		return null
	var old_part: CarPart = get_part(new_part.part_type)
	if old_part != null:
		installed_parts.erase(old_part)
	installed_parts.append(new_part)
	emit_changed()
	return old_part


func get_base_performance_points() -> int:
	var total := 0
	for part in installed_parts:
		if part != null:
			total += part.base_performance_points
	return total


func get_total_performance_points(team: Team = null) -> int:
	if team != null:
		return team.calculate_car_performance(self).displayed_points
	var raw_total := 0.0
	for part in installed_parts:
		if part != null:
			raw_total += part.get_condition_adjusted_points()
	return roundi(raw_total)


func get_race_attributes() -> Dictionary:
	ensure_damage_state()
	var attributes := {"power": float(horsepower), "aero": float(aerodynamic_efficiency), "grip": float(mechanical_grip), "braking": float(braking), "tyres": float(tyre_preservation), "fuel": float(fuel_efficiency), "reliability": float(reliability)}
	for part in installed_parts:
		if part == null:
			continue
		var key := part.get_attribute_key()
		if attributes.has(key):
			attributes[key] = clampf(float(attributes[key]) + part.get_effective_attribute_modifier(), 1.0, 100.0)
		attributes["reliability"] = clampf(float(attributes["reliability"]) + part.get_effective_reliability_modifier(), 1.0, 100.0)
	attributes["component_health"] = damage_state.duplicate(true)
	return attributes


func ensure_damage_state() -> void:
	for component in DAMAGE_COMPONENTS:
		damage_state[component] = clampf(float(damage_state.get(component, 100.0)), 0.0, 100.0)


func get_component_health(component: String) -> float:
	ensure_damage_state()
	return float(damage_state.get(component, 100.0))


func get_damage_points() -> float:
	ensure_damage_state()
	var total := 0.0
	for component in DAMAGE_COMPONENTS:
		total += 100.0 - get_component_health(component)
	return total


func get_damage_summary() -> String:
	ensure_damage_state()
	var summaries: Array[String] = []
	for component in DAMAGE_COMPONENTS:
		var health := roundi(get_component_health(component))
		if health < 99:
			summaries.append("%s %d%%" % [str(DAMAGE_LABELS[component]), health])
	return "No component damage" if summaries.is_empty() else "  |  ".join(summaries)


func restore_all_damage() -> void:
	for component in DAMAGE_COMPONENTS:
		damage_state[component] = 100.0
	emit_changed()


func ensure_workshop_state(assume_ready: bool = true) -> void:
	var defaults := {
		"inspection_complete": assume_ready,
		"baseline_setup_complete": assume_ready,
		"shakedown_complete": assume_ready,
		"prepared_race_id": "",
		"prepared_track_type": "",
		"setup_readiness": 55 if assume_ready else 0,
		"scrutineering_risk": 0.0,
		"last_service_day": 0,
		"races_since_service": 0,
		"track_familiarity": {},
	}
	for key in defaults:
		if not workshop_state.has(key):
			workshop_state[key] = defaults[key]
	if not workshop_state.get("track_familiarity") is Dictionary:
		workshop_state["track_familiarity"] = {}


func initialize_unprepared() -> void:
	workshop_jobs.clear()
	workshop_state = {}
	ensure_workshop_state(false)
	emit_changed()


func is_initial_preparation_complete() -> bool:
	ensure_workshop_state()
	return (
		bool(workshop_state.get("inspection_complete", false))
		and bool(workshop_state.get("baseline_setup_complete", false))
		and bool(workshop_state.get("shakedown_complete", false))
	)


func has_active_workshop_job(day: int, blocking_only: bool = true) -> bool:
	for job in workshop_jobs:
		if blocking_only and not bool(job.get("blocking", true)):
			continue
		if int(job.get("start_day", day)) <= day and int(job.get("completion_day", day)) > day:
			return true
	return false


func get_latest_workshop_day() -> int:
	var latest := 0
	for job in workshop_jobs:
		latest = maxi(latest, int(job.get("completion_day", 0)))
	return latest


func has_pending_workshop_job(kind: String, component: String = "", race_id: String = "") -> bool:
	for job in workshop_jobs:
		if str(job.get("kind", "")) != kind:
			continue
		if not component.is_empty() and str(job.get("component", "")) != component:
			continue
		if not race_id.is_empty() and str(job.get("race_id", "")) != race_id:
			continue
		return true
	return false


func is_race_available(day: int) -> bool:
	if not is_initial_preparation_complete() or has_active_workshop_job(day):
		return false
	if condition < 30:
		return false
	ensure_damage_state()
	for component in DAMAGE_COMPONENTS:
		if get_component_health(component) < 35.0:
			return false
	for part_type in CarPart.PART_TYPES:
		var part := get_part(part_type)
		if part == null or part.condition <= 0:
			return false
	return true


func get_preparation_score(race: Race) -> int:
	ensure_workshop_state()
	if not is_initial_preparation_complete():
		return 0
	var score := int(workshop_state.get("setup_readiness", 45))
	if race == null:
		return clampi(score, 0, 100)
	if str(workshop_state.get("prepared_race_id", "")) == race.race_id:
		return 100
	if str(workshop_state.get("prepared_track_type", "")) == race.track_type:
		score = maxi(score, 78)
	var familiarity := workshop_state.get("track_familiarity", {}) as Dictionary
	score += mini(12, int(familiarity.get(race.track_type, 0)) * 3)
	return clampi(score, 0, 92)


func get_preparation_bonus(race: Race) -> float:
	return clampf((float(get_preparation_score(race)) - 55.0) * 0.045, -2.5, 2.5)


func get_scrutineering_risk() -> float:
	ensure_workshop_state()
	var risk := float(workshop_state.get("scrutineering_risk", 0.0))
	if condition < 70:
		risk += float(70 - condition) * 0.004
	for part in installed_parts:
		if part != null and part.condition < 55:
			risk += float(55 - part.condition) * 0.002
	return clampf(risk, 0.0, 0.45)


func apply_workshop_job(job: Dictionary, completion_day: int) -> void:
	ensure_workshop_state()
	match str(job.get("kind", "")):
		"inspection":
			workshop_state["inspection_complete"] = true
		"baseline_setup":
			workshop_state["baseline_setup_complete"] = true
			workshop_state["setup_readiness"] = maxi(55, int(workshop_state.get("setup_readiness", 0)))
		"shakedown":
			workshop_state["shakedown_complete"] = true
			workshop_state["setup_readiness"] = maxi(62, int(workshop_state.get("setup_readiness", 0)))
		"routine_service":
			condition = mini(100, condition + 12)
			for part in installed_parts:
				if part != null:
					part.condition = mini(100, part.condition + 6)
			workshop_state["last_service_day"] = completion_day
			workshop_state["races_since_service"] = 0
			workshop_state["scrutineering_risk"] = maxf(0.0, float(workshop_state.get("scrutineering_risk", 0.0)) - 0.08)
		"patch", "rebuild", "replacement":
			var component := str(job.get("component", "engine"))
			var target := float({"patch": 72.0, "rebuild": 95.0, "replacement": 100.0}.get(str(job.get("kind", "patch")), 72.0))
			damage_state[component] = maxf(get_component_health(component), target)
			condition = mini(100, condition + int({"patch": 5, "rebuild": 12, "replacement": 18}.get(str(job.get("kind", "patch")), 5)))
			if str(job.get("kind", "")) == "patch":
				workshop_state["scrutineering_risk"] = minf(0.45, float(workshop_state.get("scrutineering_risk", 0.0)) + 0.08)
			else:
				workshop_state["scrutineering_risk"] = maxf(0.0, float(workshop_state.get("scrutineering_risk", 0.0)) - 0.06)
		"race_preparation":
			workshop_state["prepared_race_id"] = str(job.get("race_id", ""))
			workshop_state["prepared_track_type"] = str(job.get("track_type", ""))
			workshop_state["setup_readiness"] = 100
	if bool(job.get("rushed", false)):
		workshop_state["scrutineering_risk"] = minf(0.45, float(workshop_state.get("scrutineering_risk", 0.0)) + 0.08)
	emit_changed()


func record_race_use(race: Race, day: int) -> void:
	ensure_workshop_state()
	workshop_state["prepared_race_id"] = ""
	workshop_state["setup_readiness"] = maxi(42, int(workshop_state.get("setup_readiness", 55)) - 18)
	workshop_state["races_since_service"] = int(workshop_state.get("races_since_service", 0)) + 1
	if race != null:
		var familiarity := workshop_state.get("track_familiarity", {}) as Dictionary
		familiarity[race.track_type] = mini(5, int(familiarity.get(race.track_type, 0)) + 1)
		workshop_state["track_familiarity"] = familiarity
	if int(workshop_state.get("races_since_service", 0)) >= 2:
		workshop_state["scrutineering_risk"] = minf(0.45, float(workshop_state.get("scrutineering_risk", 0.0)) + 0.025)
	if int(workshop_state.get("last_service_day", 0)) <= 0:
		workshop_state["last_service_day"] = day
	emit_changed()
