extends RefCounted
class_name TrackPresentationCatalog

## Venue presentation data is deliberately separate from race balance. Every
## calendar venue receives a stable geometry, corner set and camera identity,
## while race resources remain free to tune lap count and difficulty.

const SHAPES: Dictionary = {
	"paperclip": [[0.23,0.18],[0.42,0.12],[0.70,0.14],[0.86,0.27],[0.88,0.68],[0.72,0.83],[0.43,0.87],[0.18,0.76],[0.13,0.38],[0.23,0.18]],
	"tri_oval": [[0.18,0.21],[0.48,0.11],[0.82,0.24],[0.90,0.52],[0.71,0.83],[0.35,0.87],[0.10,0.62],[0.18,0.21]],
	"d_oval": [[0.18,0.16],[0.52,0.11],[0.82,0.20],[0.91,0.47],[0.80,0.75],[0.48,0.87],[0.18,0.79],[0.10,0.48],[0.18,0.16]],
	"egg_oval": [[0.22,0.13],[0.62,0.11],[0.87,0.27],[0.91,0.58],[0.68,0.86],[0.31,0.82],[0.11,0.60],[0.12,0.30],[0.22,0.13]],
	"bullring": [[0.27,0.16],[0.66,0.15],[0.86,0.32],[0.84,0.67],[0.61,0.84],[0.25,0.79],[0.12,0.56],[0.14,0.31],[0.27,0.16]],
	"road_sweep": [[0.12,0.27],[0.37,0.12],[0.73,0.16],[0.89,0.35],[0.69,0.49],[0.88,0.72],[0.58,0.87],[0.35,0.67],[0.12,0.76],[0.21,0.48],[0.12,0.27]],
	"road_switchback": [[0.17,0.18],[0.53,0.11],[0.83,0.25],[0.63,0.41],[0.88,0.61],[0.62,0.84],[0.39,0.65],[0.13,0.80],[0.20,0.51],[0.08,0.34],[0.17,0.18]],
	"road_boot": [[0.11,0.23],[0.43,0.10],[0.82,0.19],[0.88,0.43],[0.69,0.55],[0.77,0.83],[0.49,0.88],[0.42,0.61],[0.16,0.78],[0.09,0.46],[0.11,0.23]],
	"street_harbor": [[0.14,0.16],[0.73,0.13],[0.86,0.31],[0.62,0.42],[0.87,0.59],[0.72,0.83],[0.29,0.79],[0.12,0.62],[0.31,0.47],[0.10,0.34],[0.14,0.16]]
}

const VENUE_NAMES: Array[String] = [
	"Pine Ridge", "Copper Valley", "Great Lakes", "Atlantic Shores",
	"Rocky Mountain", "Gulf Coast", "Prairie State", "Capital City",
	"Lone Star", "Pacific Crest", "Bluegrass", "North Woods",
	"Desert Sun", "River Bend", "Coastal Plains", "Empire State",
	"Cascade", "Heartland", "Bayfront", "Appalachian",
	"New England", "High Plains", "Golden State", "Motor City",
	"Ozark", "Carolina", "Lake Erie", "Front Range",
	"Puget Sound", "Allegheny", "Sonoran", "Tidewater",
	"Twin Cities", "Mojave", "Smoky Mountain", "Metro Finale"
]

const CORNER_WORDS: Array[String] = [
	"Bend", "Sweep", "Esses", "Hairpin", "Loop", "Rise", "Cut", "Carousel"
]

const CAMERA_STYLES: Array[String] = [
	"Low banking cam", "High grandstand cam", "Backstretch tracking cam",
	"Corner-entry crane", "Infield tower cam", "Pit-exit chase cam"
]


static func get_profile(race: Race) -> Dictionary:
	if race == null:
		return {}
	var venue := race.track_name.trim_suffix(" Raceway")
	var venue_index := VENUE_NAMES.find(venue)
	if venue_index < 0:
		venue_index = absi(hash(race.track_name)) % VENUE_NAMES.size()
	var shape_keys: Array[String] = []
	if race.is_oval():
		shape_keys.assign(["paperclip", "tri_oval", "d_oval", "egg_oval", "bullring"])
	else:
		shape_keys.assign(["road_sweep", "road_switchback", "road_boot", "street_harbor"])
	var shape_id := shape_keys[venue_index % shape_keys.size()]
	var points := _individualize_points(SHAPES[shape_id] as Array, venue_index, race.is_oval())
	var corner_count := 4 if race.is_oval() else clampi(points.size() - 3, 5, 8)
	var corners: Array[Dictionary] = []
	for index in corner_count:
		var progress := fposmod(0.08 + float(index) / float(corner_count), 1.0)
		var corner_name := "Turn %d" % (index + 1)
		if not race.is_oval():
			corner_name = "%s %s" % [venue.split(" ")[index % venue.split(" ").size()], CORNER_WORDS[(venue_index + index) % CORNER_WORDS.size()]]
		corners.append({
			"name": corner_name,
			"progress": progress,
			"passing": index == (venue_index % corner_count) or index == ((venue_index + 2) % corner_count),
			"banking": _corner_banking(race, venue_index, index)
		})
	var pit_entry := fposmod(0.70 + float(venue_index % 7) * 0.025, 1.0)
	var sectors: Array[Dictionary] = []
	for sector_index in 3:
		sectors.append({"name":"S%d" % (sector_index + 1), "progress":fposmod(float(sector_index) / 3.0 + float(venue_index % 5) * 0.012, 1.0)})
	var caution_locations: Array[Dictionary] = []
	for corner in corners:
		if bool(corner.get("passing", false)) or int(corner.get("banking", 0)) >= 20:
			caution_locations.append({"name":str(corner.get("name", "Incident zone")), "progress":float(corner.get("progress", 0.0)), "risk":"High" if bool(corner.get("passing", false)) else "Medium"})
	if caution_locations.size() > 3:
		caution_locations.resize(3)
	return {
		"venue_id": venue.to_snake_case(),
		"shape_id": shape_id,
		"points": points,
		"corners": corners,
		"sectors": sectors,
		"passing_zones": corners.filter(func(corner: Dictionary) -> bool: return bool(corner.get("passing", false))),
		"caution_locations": caution_locations,
		"pit_entry": pit_entry,
		"pit_exit": fposmod(pit_entry + (0.16 if race.is_oval() else 0.11), 1.0),
		"grooves": 3 if race.is_oval() else 2,
		"banking_summary": _banking_summary(race, venue_index),
		"camera_style": CAMERA_STYLES[venue_index % CAMERA_STYLES.size()],
		"camera_focus": float((venue_index * 17) % 100) / 100.0,
		"accent": Color.from_hsv(float((venue_index * 31) % 360) / 360.0, 0.34, 0.78)
	}


static func _individualize_points(source: Array, venue_index: int, is_oval: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	var scale_x := 0.91 + float((venue_index * 7) % 15) / 100.0
	var scale_y := 0.89 + float((venue_index * 11) % 17) / 100.0
	var skew := (float((venue_index * 13) % 11) - 5.0) * 0.008
	var reverse := venue_index % 4 == 3 and not is_oval
	var working := source.duplicate(true)
	if reverse:
		working.reverse()
	for value in working:
		var raw := value as Array
		var centered := Vector2(float(raw[0]) - 0.5, float(raw[1]) - 0.5)
		centered.x = centered.x * scale_x + centered.y * skew
		centered.y *= scale_y
		result.append(Vector2(clampf(centered.x + 0.5, 0.05, 0.95), clampf(centered.y + 0.5, 0.05, 0.95)))
	return result


static func _corner_banking(race: Race, venue_index: int, corner_index: int) -> int:
	if race.is_oval():
		return 8 + ((venue_index * 3 + corner_index * 5) % 24)
	return 1 + ((venue_index + corner_index * 2) % 7)


static func _banking_summary(race: Race, venue_index: int) -> String:
	if race.is_oval():
		return "Progressive %d-%d deg banking" % [10 + venue_index % 8, 22 + venue_index % 10]
	return "%d deg max camber, %d m elevation change" % [2 + venue_index % 6, 8 + (venue_index * 7) % 46]
