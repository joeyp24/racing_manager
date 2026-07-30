extends RefCounted
class_name TeamCatalog

## Stable, fictional organizations shared by the team browser and race simulation.
## Each organization fields multiple cars, as in a NASCAR-style team structure.

const TEAM_IDENTITIES: Dictionary = {
	"local_short_track": [
		["Pine Ridge Motorsports", "Hickory, NC", 1987, 6, "A family-owned short-track institution known for patient driver development."],
		["Red Clay Racing", "Athens, GA", 2008, 1, "A hard-nosed independent operation built in southeastern bullrings."],
		["Ironwood Competition", "Knoxville, TN", 1999, 3, "Former fabricators who turned a two-bay shop into regular contenders."],
		["County Line Autosport", "Florence, SC", 2018, 0, "A young volunteer-backed team chasing its first title."],
		["Bluebird Raceworks", "Roanoke, VA", 1976, 9, "Old-school racers with more than four decades of local victories."],
		["Mason Creek Racing", "Macon, GA", 2012, 0, "A small team whose clever setups routinely upset bigger shops."],
		["Copperhead Motorsports", "Bristol, TN", 1994, 4, "Aggressive racers with a loyal regional following."]
	],
	"regional_short_track": [
		["Carolina Forge Racing", "Concord, NC", 1995, 5, "A respected multi-car ladder team with its own chassis program."],
		["Volunteer State Motorsports", "Nashville, TN", 2004, 2, "A sponsor-savvy organization that gives prospects their first break."],
		["Magnolia Speedworks", "Jackson, MS", 2011, 1, "Late-model specialists famous for long-run pace."],
		["Shenandoah Competition", "Winchester, VA", 1989, 7, "A disciplined veteran team with deep short-track roots."],
		["Palmetto Racing Group", "Columbia, SC", 2015, 0, "An ambitious new shop investing heavily in engineering."],
		["Great Lakes Autosport", "Toledo, OH", 2001, 3, "Northern short-track champions expanding beyond home territory."],
		["Ozark Mountain Racing", "Springfield, MO", 2009, 1, "A resourceful independent team used to winning on tight budgets."],
		["Tidewater Motorsports", "Norfolk, VA", 1997, 2, "Smooth, consistent race execution is the hallmark of this team."]
	],
	"national_short_track": [
		["Keystone Performance", "Harrisburg, PA", 1984, 8, "A national short-track powerhouse with a celebrated driver academy."],
		["Summit Ridge Racing", "Denver, CO", 1998, 4, "High-altitude testing helped build a technically adventurous program."],
		["Heartland Competition", "Des Moines, IA", 1991, 6, "A steady title threat backed by generations of Midwest racers."],
		["Gulf Coast Motorsports", "Mobile, AL", 2006, 2, "Known for tire management and a relaxed but effective culture."],
		["Empire State Racing", "Albany, NY", 2010, 1, "A rapidly growing organization bringing northeastern talent south."],
		["Blackwater Race Engineering", "Richmond, VA", 2003, 3, "Engineering-led and meticulous, especially on abrasive tracks."],
		["Prairie Wind Autosport", "Wichita, KS", 2014, 0, "An underdog team with a knack for finding overlooked drivers."],
		["Allegheny Motorsports", "Pittsburgh, PA", 1996, 2, "Tough cars and relentless pit crews define this blue-collar shop."],
		["Lone Star Short Track", "Fort Worth, TX", 2000, 5, "Texas champions now measuring themselves against the nation."],
		["Granite State Racing", "Loudon, NH", 1982, 7, "A historic northern operation entering a new competitive era."]
	],
	"continental_east_west": [
		["Atlantic Coast Racing", "Mooresville, NC", 1988, 5, "A polished eastern development team with national ambitions."],
		["Pacific Crest Motorsports", "Bakersfield, CA", 1993, 6, "West-coast stalwarts with exceptional road-course preparation."],
		["Sierra Gold Racing", "Sacramento, CA", 2007, 2, "An energetic prospect pipeline backed by technology partners."],
		["Appalachian Performance", "Asheville, NC", 2002, 3, "Setup specialists who excel on technical short tracks."],
		["Desert Sun Autosport", "Phoenix, AZ", 2013, 1, "Heat-tested equipment and bold strategy make this team dangerous."],
		["Chesapeake Racing", "Annapolis, MD", 1999, 4, "A methodical east-coast organization renowned for reliability."],
		["Cascade Competition", "Portland, OR", 2005, 2, "Versatile racers equally comfortable on ovals and road courses."],
		["Liberty Bell Motorsports", "Philadelphia, PA", 2016, 0, "A modern, data-first team still hunting a breakthrough season."]
	],
	"continental_national": [
		["American Vanguard Racing", "Charlotte, NC", 1981, 11, "One of the country's premier development organizations."],
		["Frontier Motorsports", "Oklahoma City, OK", 1990, 5, "Independent in spirit but equipped like a factory operation."],
		["Union Works Racing", "Indianapolis, IN", 1997, 4, "A precision-focused team drawing talent from several disciplines."],
		["Southern Crown Autosport", "Atlanta, GA", 2001, 3, "Commercially powerful and always capable of signing star drivers."],
		["Northstar Competition", "Minneapolis, MN", 1986, 7, "Cold-weather ingenuity produced a durable national contender."],
		["Mesa Verde Racing", "Albuquerque, NM", 2008, 1, "A lean western program respected for strategic gambles."],
		["Foundry Lane Motorsports", "Detroit, MI", 1994, 5, "Manufacturing expertise gives this team exceptionally strong cars."],
		["Bluegrass Racing Group", "Louisville, KY", 2004, 2, "A close-knit outfit with a growing driver development stable."],
		["Capital City Competition", "Raleigh, NC", 2011, 1, "Young engineers and veteran racers share an ambitious shop."],
		["Golden Gate Autosport", "San Jose, CA", 1999, 3, "Technology investment powers a versatile coast-to-coast program."]
	],
	"national_truck": [
		["High Country Truck Racing", "Denver, CO", 1996, 4, "A factory-supported truck specialist built around rugged reliability."],
		["Workhorse Motorsports", "Greensboro, NC", 1989, 8, "The benchmark multi-truck organization for nearly two decades."],
		["Red River Racing", "Shreveport, LA", 2003, 3, "Late-braking, aggressive drivers thrive in this lively team."],
		["Timberline Competition", "Boise, ID", 2009, 1, "A remote but innovative operation with excellent pit crews."],
		["Steel City Truck Works", "Pittsburgh, PA", 1998, 5, "Durability and disciplined execution keep this team in title fights."],
		["Sunbelt Motorsports", "Tampa, FL", 2006, 2, "A modern academy team offering young drivers national exposure."],
		["Route 66 Racing", "Tulsa, OK", 1992, 6, "A fan favorite with a proud independent streak."],
		["Lake Effect Autosport", "Cleveland, OH", 2012, 0, "An improving midfield team seeking its first championship."],
		["Cumberland Truck Racing", "Lexington, KY", 2000, 3, "Veteran leadership makes this one of the paddock's steadiest teams."],
		["Silver Spur Competition", "Fort Worth, TX", 2015, 1, "Big ambition and fearless strategy characterize this Texas newcomer."],
		["Badlands Motorsports", "Rapid City, SD", 2005, 2, "A small-market team that routinely outperforms its budget."],
		["Port City Racing", "Wilmington, NC", 1997, 4, "Strong superspeedway equipment anchors a balanced program."]
	],
	"national_grand": [
		["Velocity Racing Alliance", "Mooresville, NC", 1985, 9, "A manufacturer flagship with a deep technical partnership network."],
		["Heritage Motorsports", "Kannapolis, NC", 1972, 15, "A storied organization balancing tradition with modern engineering."],
		["Pinnacle Competition", "Concord, NC", 1994, 7, "Championship expectations follow every car from this elite shop."],
		["Midwestern Racing Group", "Indianapolis, IN", 1988, 6, "Methodical development and versatile drivers fuel consistent success."],
		["Coastal Plains Autosport", "Savannah, GA", 2002, 3, "Long-run speed makes this team a threat late in races."],
		["Rocky Mountain Racing", "Colorado Springs, CO", 1999, 4, "An engineering-forward western alternative to Carolina teams."],
		["Commonwealth Motorsports", "Richmond, VA", 1991, 5, "An established contender with an exceptional sponsor portfolio."],
		["Crossroads Racing", "Memphis, TN", 2007, 2, "A hungry rising team unafraid to promote young prospects."],
		["Great Plains Performance", "Omaha, NE", 2004, 1, "Efficient operations let this independent fight larger rivals."],
		["Seaboard Competition", "Baltimore, MD", 1996, 4, "Detail-oriented preparation has made reliability its signature."],
		["Motor City Autosport", "Detroit, MI", 1980, 10, "Factory connections and decades of history support a proud team."],
		["Evergreen Racing", "Seattle, WA", 2010, 1, "A progressive team building a national presence from the northwest."],
		["Peachtree Motorsports", "Atlanta, GA", 2001, 3, "A commercially polished organization capable of surprise wins."]
	],
	"premier_cup": [
		["Crownline Motorsports", "Charlotte, NC", 1968, 18, "A dynasty whose championship banners define the modern era."],
		["Titan Racing Enterprises", "Concord, NC", 1984, 12, "A four-car superteam with factory resources and relentless standards."],
		["Legacy Performance Group", "Mooresville, NC", 1975, 14, "Generations of star drivers have carried this famous badge."],
		["Apex National Racing", "Huntersville, NC", 1990, 8, "Advanced simulation and engineering power a perennial contender."],
		["Victory Lane Motorsports", "Kannapolis, NC", 1987, 7, "Race-day execution makes this veteran organization a weekly threat."],
		["Patriot Racing Company", "Richmond, VA", 1998, 4, "A fiercely independent multi-car operation with loyal supporters."],
		["Blue Ridge Competition", "Asheville, NC", 2003, 3, "A growing team mixing veteran leadership with academy prospects."],
		["Centennial Autosport", "Indianapolis, IN", 1995, 5, "Cross-discipline expertise produces exceptional road-course speed."],
		["Southern Star Racing", "Nashville, TN", 2006, 2, "Entertainment-industry backing supports an ambitious race program."],
		["Great American Motorsports", "Dallas, TX", 1982, 9, "A proud, aggressive organization with national reach."],
		["Mountain State Racing", "Charleston, WV", 2009, 1, "The grid's determined underdog, famous for stretching every dollar."],
		["Atlantic Union Racing", "Wilmington, NC", 2000, 3, "Superspeedway expertise and sharp strategy deliver regular upsets."],
		["North Carolina Racing Co.", "Statesville, NC", 1979, 11, "An old guard team revitalized by a new technical department."],
		["Keystone Cup Racing", "Allentown, PA", 2012, 1, "A young northern organization challenging the southern establishment."]
	]
}

const RATING_OFFSETS: Array[int] = [12, 8, 5, 2, 0, -2, -5, -8, -11, 6, -6, 3, -3, -9]


static func get_teams(series_id: String) -> Array[Dictionary]:
	var identities: Array = TEAM_IDENTITIES.get(series_id, [])
	var series := SeriesCatalog.get_series(series_id)
	var teams: Array[Dictionary] = []
	if identities.is_empty() or series.is_empty():
		return teams
	var base_rating := int(series.car_rating)
	var field_size := int(series.maximum_field_size)
	for index in identities.size():
		var identity: Array = identities[index]
		var overall := clampi(base_rating + RATING_OFFSETS[index % RATING_OFFSETS.size()], 35, 99)
		var team_id := "%s_team_%02d" % [series_id, index + 1]
		teams.append({
			"team_id": team_id, "series_id": series_id, "team_name": str(identity[0]),
			"hometown": str(identity[1]), "founded": int(identity[2]), "championships": int(identity[3]),
			"history": str(identity[4]), "overall_rating": overall,
			"equipment_rating": clampi(overall + ((index * 3) % 7) - 3, 1, 99),
			"engineering_rating": clampi(overall + ((index * 5) % 9) - 4, 1, 99),
			"pit_crew_rating": clampi(overall + ((index * 7) % 11) - 5, 1, 99),
			"strategy_rating": clampi(overall + ((index * 2) % 9) - 4, 1, 99),
			"driver_count": field_size / identities.size() + (1 if index < field_size % identities.size() else 0)
		})
	return teams


static func get_team(series_id: String, team_id: String) -> Dictionary:
	for team in get_teams(series_id):
		if str(team.team_id) == team_id:
			return team
	return {}

