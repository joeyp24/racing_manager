extends RefCounted
class_name PointsSystemCatalog

const SYSTEMS := {
	"short_track": {"points":[50,45,41,38,36,34,32,30,28,26,24,22,20,18,16,14,12,10,8,6], "participation":2, "pole":1, "fastest_lap":1, "stage":0},
	"national": {"points":[40,35,34,33,32,31,30,29,28,27,26,25,24,23,22,21,20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1], "participation":1, "pole":1, "fastest_lap":1, "stage":1},
	"cup": {"points":[40,35,34,33,32,31,30,29,28,27,26,25,24,23,22,21,20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1], "participation":1, "pole":0, "fastest_lap":1, "stage":1}
}

static func calculate(system_id: String, result: Dictionary) -> int:
	var system: Dictionary = SYSTEMS.get(system_id, SYSTEMS["short_track"])
	var position := maxi(1, int(result.get("position", 1)))
	var table: Array = system.points
	var points := int(table[position - 1]) if position <= table.size() else int(system.participation)
	if bool(result.get("pole", false)): points += int(system.pole)
	if bool(result.get("fastest_lap", false)): points += int(system.fastest_lap)
	points += maxi(0, int(result.get("stage_wins", 0))) * int(system.stage)
	return points

static func standings_before(a: Dictionary, b: Dictionary) -> bool:
	# Points, wins, podiums, then best finish provide a stable championship tie-break.
	for key in ["points", "wins", "podiums"]:
		if int(a.get(key, 0)) != int(b.get(key, 0)):
			return int(a.get(key, 0)) > int(b.get(key, 0))
	return int(a.get("best_finish", 999)) < int(b.get("best_finish", 999))
