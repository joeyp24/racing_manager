extends RefCounted
class_name CarSpecializationCatalog

const TRACK_TYPES: Array[String] = ["Short Track", "Speedway", "Road Course", "Street Course", "Dirt"]
const TRACK_IDS: Dictionary = {
	"Short Track": "short_track",
	"Speedway": "speedway",
	"Road Course": "road_course",
	"Street Course": "street_course",
	"Dirt": "dirt",
}

const SPECIALIZATIONS: Dictionary = {
	"balanced": {
		"name": "All-Rounder",
		"short_name": "BALANCED",
		"description": "A predictable chassis with a small advantage at every venue.",
		"track_bonuses": {"Short Track":1.0, "Speedway":1.0, "Road Course":1.0, "Street Course":1.0, "Dirt":1.0},
	},
	"short_track": {
		"name": "Short-Track Specialist",
		"short_name": "SHORT TRACK",
		"description": "Built for rotation, braking stability, and repeated restarts.",
		"track_bonuses": {"Short Track":3.5, "Speedway":0.5, "Road Course":0.0, "Street Course":0.0, "Dirt":1.5},
	},
	"speedway": {
		"name": "Speedway Specialist",
		"short_name": "SPEEDWAY",
		"description": "Low drag and high-speed stability reward long full-throttle runs.",
		"track_bonuses": {"Short Track":0.0, "Speedway":3.5, "Road Course":-0.5, "Street Course":-0.5, "Dirt":-0.5},
	},
	"road_course": {
		"name": "Road-Course Specialist",
		"short_name": "ROAD COURSE",
		"description": "Responsive direction changes and braking performance suit technical circuits.",
		"track_bonuses": {"Short Track":0.0, "Speedway":-0.5, "Road Course":3.5, "Street Course":2.0, "Dirt":0.0},
	},
	"street_course": {
		"name": "Street-Course Specialist",
		"short_name": "STREET COURSE",
		"description": "Compliant suspension and traction make the most of narrow temporary circuits.",
		"track_bonuses": {"Short Track":0.0, "Speedway":-0.5, "Road Course":2.0, "Street Course":3.5, "Dirt":0.0},
	},
	"dirt": {
		"name": "Dirt Specialist",
		"short_name": "DIRT",
		"description": "Mechanical grip and forgiving balance excel on loose surfaces.",
		"track_bonuses": {"Short Track":1.5, "Speedway":-0.5, "Road Course":0.0, "Street Course":-0.5, "Dirt":3.5},
	},
}

const TRAITS: Dictionary = {
	"stable_platform": {
		"name": "Stable Platform",
		"description": "Predictable at the limit, reducing incidents and mechanical load.",
		"pace": 0.6, "wear_multiplier": 0.96, "incident_multiplier": 0.88,
		"attributes": {"grip":1.5, "reliability":3.0},
	},
	"aggressive_geometry": {
		"name": "Aggressive Geometry",
		"description": "Fast over one lap, but harder on components and less forgiving.",
		"pace": 2.0, "wear_multiplier": 1.12, "incident_multiplier": 1.10,
		"attributes": {"power":2.0, "aero":1.0, "reliability":-4.0},
	},
	"tyre_friendly": {
		"name": "Tyre Friendly",
		"description": "Protects the tyres and rewards long, controlled race stints.",
		"pace": 0.2, "wear_multiplier": 0.86, "incident_multiplier": 0.96,
		"attributes": {"tyres":6.0, "reliability":1.0},
	},
	"fuel_sipper": {
		"name": "Fuel Sipper",
		"description": "Efficient plumbing extends fuel windows with minimal compromise.",
		"pace": 0.0, "wear_multiplier": 0.96, "incident_multiplier": 1.0,
		"attributes": {"fuel":7.0, "reliability":1.0},
	},
	"lightweight": {
		"name": "Fragile Lightweight",
		"description": "Immediate pace comes with substantially greater wear and failure exposure.",
		"pace": 2.6, "wear_multiplier": 1.15, "incident_multiplier": 1.16,
		"attributes": {"grip":2.0, "reliability":-7.0},
	},
}


static func configure_template(car: Car, template_index: int, series_id: String) -> void:
	if car == null:
		return
	var distribution := SeriesCatalog.get_series(series_id).get("track_type_distribution", {}) as Dictionary
	var ordered_tracks: Array[String] = []
	for track_type in distribution:
		ordered_tracks.append(str(track_type))
	ordered_tracks.sort_custom(func(first: String, second: String) -> bool:
		return float(distribution.get(first, 0.0)) > float(distribution.get(second, 0.0))
	)
	if template_index < ordered_tracks.size():
		car.specialization_id = str(TRACK_IDS.get(ordered_tracks[template_index], "balanced"))
	else:
		car.specialization_id = "balanced"
	var template_traits: Array[String] = ["stable_platform", "tyre_friendly", "aggressive_geometry"]
	car.chassis_trait_id = template_traits[template_index % template_traits.size()]


static func ensure_identity(car: Car) -> void:
	if car == null:
		return
	if not SPECIALIZATIONS.has(car.specialization_id):
		var specialization_ids: Array[String] = ["balanced", "short_track", "speedway", "road_course", "street_course", "dirt"]
		car.specialization_id = specialization_ids[absi(hash("%s:%s:%d" % [car.manufacturer, car.model, car.year])) % specialization_ids.size()]
	if not TRAITS.has(car.chassis_trait_id):
		var trait_ids: Array[String] = ["stable_platform", "aggressive_geometry", "tyre_friendly", "fuel_sipper", "lightweight"]
		car.chassis_trait_id = trait_ids[absi(hash("%s:%s:%s" % [car.name, car.series_id, car.specialization_id])) % trait_ids.size()]


static func get_specialization(specialization_id: String) -> Dictionary:
	return (SPECIALIZATIONS.get(specialization_id, SPECIALIZATIONS["balanced"]) as Dictionary).duplicate(true)


static func get_trait(trait_id: String) -> Dictionary:
	return (TRAITS.get(trait_id, TRAITS["stable_platform"]) as Dictionary).duplicate(true)


static func get_track_bonus(specialization_id: String, track_type: String) -> float:
	var data := get_specialization(specialization_id)
	return float((data.get("track_bonuses", {}) as Dictionary).get(track_type, 0.0))
