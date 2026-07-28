class_name SponsorCatalog
extends RefCounted

const SPONSOR_PATHS: Array[String] = [
	"res://resources/sponsors/local_auto_parts.tres",
	"res://resources/sponsors/apex_fuel.tres",
	"res://resources/sponsors/victory_performance.tres"
]


static func get_all() -> Array[Sponsor]:
	var sponsors: Array[Sponsor] = []
	for path in SPONSOR_PATHS:
		var sponsor := load(path) as Sponsor
		if sponsor != null:
			sponsors.append(sponsor)
	return sponsors


static func find_by_id(sponsor_id: String) -> Sponsor:
	for sponsor in get_all():
		if sponsor.sponsor_id == sponsor_id:
			return sponsor
	return null
