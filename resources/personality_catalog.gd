extends RefCounted
class_name PersonalityCatalog

## A small authored voice library. Ratings decide which voice a driver uses,
## while stable hashing keeps repeated careers consistent without repeating the
## same line after every result.
const PROFILES: Dictionary = {
	"veteran": {
		"name":"Old Hand", "tagline":"Measured, proud and difficult to rattle.",
		"win":["I have waited long enough for that one. Let the crew enjoy it.", "Experience only matters if you still know when to attack. Today we did."],
		"success":["That was a proper team result. We made the race come to us.", "The car talked to me all afternoon and we listened."],
		"failure":["I have had worse Sundays. Give me a car I can trust and we will answer.", "No excuses. We know where the time went, so now we earn it back."],
		"team_order":["I followed the call. I expect the same clarity next time.", "The team asked and I delivered, but nobody should mistake patience for surrender."],
		"renewed":["This team still feels like unfinished business.", "I am staying because I still believe our best day is ahead."],
		"released":["I wanted to finish what we started. Now they get to race against me.", "I have closed this chapter before. The next team gets everything I have left."],
		"signed":["I did not come here for a farewell tour. I came here to win."]
	},
	"firebrand": {
		"name":"Firebrand", "tagline":"Fast, confrontational and never short of an opinion.",
		"win":["That is what happens when they finally let me race. More of that.", "We took the race away from them. I want the next one too."],
		"success":["I left nothing in the car. If they want to beat us, they had better work.", "That was fun. Put someone in front of me again."],
		"failure":["We were too slow and I am not going to dress it up. Fix it.", "I can take losing. I cannot take standing still."],
		"team_order":["I heard the order. I did not agree with it.", "I played the team game today. Do not make a habit of asking."],
		"renewed":["They promised me a car worth fighting with. I intend to hold them to it."],
		"released":["Good. I would rather beat them than wait for them."],
		"signed":["Give me a number, a fast car and room to work."]
	},
	"analyst": {
		"name":"The Analyst", "tagline":"Technical, precise and happiest with a clear explanation.",
		"win":["The final stint was exactly what the model predicted. The execution made it real.", "We won this in the debrief room before we won it on track."],
		"success":["The balance improved every run. That progress is more important than the headline.", "The numbers make sense. There is another step available if we keep working."],
		"failure":["The result is frustrating, but the cause is clear. That means it is fixable.", "We lost the rear platform after the stop. I want that trace in the morning."],
		"team_order":["The instruction was logical, even if it cost my race. I need to understand the longer plan."],
		"renewed":["The technical direction convinced me. Now we need to deliver it."],
		"released":["The decision does not match the data, but I will find a team that does."],
		"signed":["Show me the development plan and I will help make it faster."]
	},
	"loyalist": {
		"name":"Team Heart", "tagline":"Loyal, collaborative and protective of the crew.",
		"win":["Look at those people on the wall. This belongs to every one of them.", "We kept believing in each other. That is why this win feels different."],
		"success":["We did this together. The crew never stopped giving me a car to fight with.", "It was not perfect, but nobody on this team quit."],
		"failure":["Do not blame one person. We win and lose as the same team.", "We will be back in the shop together tomorrow and we will put this right."],
		"team_order":["If the team needs it, I will do it. I know they will remember that."],
		"renewed":["This is my racing family. Leaving never felt like the right answer."],
		"released":["I gave this team everything. Walking away hurts more than I expected."],
		"signed":["I want to build something people here can be proud of."]
	},
	"showman": {
		"name":"Showstopper", "tagline":"Charismatic, ambitious and alive for the big moment.",
		"win":["Save that picture. You are going to see it for a long time.", "The crowd came for a show and we gave them the ending."],
		"success":["That was worth the price of a ticket. We are getting close.", "Give the fans one more lap and I might have found another place."],
		"failure":["Not the ending anyone wanted, but nobody will forget the comeback.", "A quiet loss is still a loss. We will make the response loud."],
		"team_order":["I made the call look good. Now the team owes me a chance to make headlines."],
		"renewed":["Same colors, bigger expectations. Let us make this the team everyone watches."],
		"released":["Their announcement will trend today. My next win will last longer."],
		"signed":["This team wanted a star. Now let us give them something to celebrate."]
	},
	"ice_cold": {
		"name":"Ice Cold", "tagline":"Composed, private and clinical under pressure.",
		"win":["Good race. Good calls. We start again next week.", "The job was to win. We did the job."],
		"success":["Clean execution. There is more pace to find.", "We took what the race offered and nothing less."],
		"failure":["It happened. We diagnose it, correct it and move on.", "Emotion will not recover the points. Work will."],
		"team_order":["Order understood and completed. The championship will decide whether it was correct."],
		"renewed":["The terms are settled. My focus returns to driving."],
		"released":["Decision noted. I will answer it on track."],
		"signed":["I am here to deliver results, not promises."]
	},
	"underdog": {
		"name":"True Grit", "tagline":"Restless, resilient and determined to prove a point.",
		"win":["They counted us out before the weekend. I hope they kept the notes.", "That one is for everyone who said we did not belong here."],
		"success":["We made them notice us today. Next time we make them chase us.", "Every position mattered. We are building something the big teams cannot buy."],
		"failure":["We have climbed out of deeper holes than this. I am not going anywhere.", "It hurts because we care. We turn that into work."],
		"team_order":["I did what the team needed. My own chance will come."],
		"renewed":["They believed before the results arrived. I remember that."],
		"released":["I have spent my career proving people wrong. Add one more name to the list."],
		"signed":["I only needed one team to believe. Now we prove them right."]
	}
}


static func assign_identity(driver) -> String:
	if driver == null:
		return "underdog"
	if str(driver.personality_id).is_empty() or not PROFILES.has(str(driver.personality_id)):
		driver.personality_id = _derive_identity(driver)
	var profile := PROFILES[str(driver.personality_id)] as Dictionary
	driver.personality_tagline = str(profile.tagline)
	return str(driver.personality_id)


static func get_profile(driver) -> Dictionary:
	var identity := assign_identity(driver)
	return (PROFILES.get(identity, PROFILES.underdog) as Dictionary).duplicate(true)


static func get_personality_name(driver) -> String:
	return str(get_profile(driver).name)


static func reaction(driver, event: String, context: Dictionary = {}) -> String:
	if driver == null:
		return ""
	var profile := get_profile(driver)
	var lines := profile.get(event, profile.get("success", [])) as Array
	if lines.is_empty():
		return ""
	var stable_key := "%s|%s|%s|%s" % [driver.driver_id, event, context.get("season", 0), context.get("event", "")]
	var quote := str(lines[absi(hash(stable_key)) % lines.size()])
	quote = quote.replace("{team}", str(context.get("team", driver.team_name)))
	quote = quote.replace("{race}", str(context.get("race", "the race")))
	driver.last_reaction = quote
	return quote


static func build_season_summary(team) -> Dictionary:
	if team == null:
		return {}
	var driver = team.get_active_driver()
	if driver == null:
		return {"headline":"A season without a settled lead driver", "narrative":"The team reached the finish, but its next identity will be decided in the contract window.", "driver_story":"No lead driver completed the season.", "rivalry_story":"No rivalry defined the campaign."}
	assign_identity(driver)
	var series := SeriesCatalog.get_series(team.current_series_id)
	var sample_count := mini(int(series.get("season_length", 12)), driver.race_history.size())
	var wins := 0
	var podiums := 0
	var finish_total := 0
	var best_gain := -999
	var defining_race := "the season finale"
	for index in sample_count:
		var race := driver.race_history[index] as Dictionary
		var finish := int(race.get("finish", 0))
		if finish > 0:
			finish_total += finish
			wins += 1 if finish == 1 else 0
			podiums += 1 if finish <= 3 else 0
		var gain := int(race.get("positions_gained", 0))
		if gain > best_gain:
			best_gain = gain
			defining_race = str(race.get("race_name", defining_race))
	var average_finish := float(finish_total) / float(maxi(1, sample_count))
	var position := maxi(1, int(team.last_season_position))
	var headline := "%s finishes P%d after a season of steady progress" % [team.team_name, position]
	if position == 1:
		headline = "%s turns a full season into a championship" % team.team_name
	elif wins > 0 and driver.age >= 34:
		headline = "%s's veteran refuses to fade" % team.team_name
	elif wins > 0:
		headline = "%s finds its breakthrough" % team.team_name
	elif position >= 8:
		headline = "%s reaches the finish with a rebuild ahead" % team.team_name
	var driver_story := "%s, the %s, delivered %d win%s and %d podium%s with an average finish of %.1f." % [driver.driver_name, get_personality_name(driver).to_lower(), wins, "" if wins == 1 else "s", podiums, "" if podiums == 1 else "s", average_finish]
	if driver.age >= 34 and wins > 0:
		driver_story = "%s was supposed to be entering the twilight of a career. Instead, the %d-year-old won %d race%s and gave the team its defining memory." % [driver.driver_name, driver.age, wins, "" if wins == 1 else "s"]
	elif wins == 1 and driver.career_wins == 1:
		driver_story = "%s earned a first career victory and changed the way the paddock sees both driver and team." % driver.driver_name
	var rival_story := "No single opponent came to define the season."
	var featured_id := str(team.career_state.get("featured_rival_id", ""))
	var rival := (team.career_state.get("rivalries", {}) as Dictionary).get(featured_id, {}) as Dictionary
	if not rival.is_empty():
		rival_story = "%s became the recurring measuring stick: %d meetings, %d wins for your driver and an intensity of %d/100." % [str(rival.get("name", "A rival")), int(rival.get("encounters", (rival.get("history", []) as Array).size())), int(rival.get("player_wins", rival.get("defeats", 0))), int(rival.get("intensity", 0))]
	var narrative := "The team finished P%d with %d win%s. The defining charge came at %s, where %s gained %+d positions." % [position, wins, "" if wins == 1 else "s", defining_race, driver.driver_name, best_gain]
	if sample_count == 0:
		narrative = "The season is complete, but the surviving timing records are incomplete. The people and decisions that shaped it still carry into next year."
	return {"headline":headline, "narrative":narrative, "driver_story":driver_story, "rivalry_story":rival_story, "reaction":reaction(driver, "success", {"season":team.current_season_year, "event":"season_summary", "team":team.team_name})}


static func _derive_identity(driver) -> String:
	if int(driver.age) >= 34:
		return "veteran"
	if int(driver.aggression) >= 70 and int(driver.professionalism) < 68:
		return "firebrand"
	if int(driver.car_feedback) >= 67 or int(driver.coachability) >= 75:
		return "analyst"
	if int(driver.loyalty) >= 68 or int(driver.teamwork) >= 75:
		return "loyalist"
	if int(driver.marketability) >= 72:
		return "showman"
	if int(driver.composure) >= 72 and int(driver.pressure_tolerance) >= 66:
		return "ice_cold"
	return "underdog"
