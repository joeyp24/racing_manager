extends Control

@onready var status_label: Label = %status_label
@onready var offers_container: VBoxContainer = %offers_container


func _ready() -> void:
	show_sponsors()


func show_sponsors() -> void:
	for child in offers_container.get_children():
		child.queue_free()

	var team := GameManager.team
	if team == null:
		status_label.text = "No team is currently loaded."
		return

	var active := SponsorCatalog.find_by_id(team.active_sponsor_id)
	if active != null:
		status_label.text = (
			"Active: %s — %d races remaining — Objective %d/%d%s"
			% [
				active.sponsor_name,
				team.sponsor_races_remaining,
				team.sponsor_objective_progress,
				active.objective_target,
				" (complete)" if team.sponsor_objective_completed else ""
			]
		)
	elif team.sponsor_signed_season == team.season_number:
		status_label.text = "Your season contract has ended. New offers arrive next season."
	else:
		status_label.text = "Choose one sponsor for Season %d." % team.season_number

	for sponsor in SponsorCatalog.get_all():
		create_offer(sponsor, team)


func create_offer(sponsor: Sponsor, team: Team) -> void:
	var panel := PanelContainer.new()
	var content := HBoxContainer.new()
	var details := Label.new()
	var sign_button := Button.new()

	panel.add_child(content)
	content.add_child(details)
	content.add_child(sign_button)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.text = (
		"%s\nRequires %d reputation  |  Signing bonus $%s  |  $%s per race\n%s — Bonus $%s  |  %d-race contract"
		% [
			sponsor.sponsor_name,
			sponsor.required_reputation,
			format_number(sponsor.signing_bonus),
			format_number(sponsor.payment_per_race),
			sponsor.get_objective_description(),
			format_number(sponsor.objective_bonus),
			sponsor.contract_length
		]
	)
	sign_button.text = "Sign Contract"
	sign_button.disabled = (
		team.reputation < sponsor.required_reputation
		or team.sponsor_signed_season == team.season_number
		or not team.active_sponsor_id.is_empty()
		or team.is_series_season_complete()
	)
	if team.reputation < sponsor.required_reputation:
		sign_button.text = "Locked"
	sign_button.pressed.connect(sign_sponsor.bind(sponsor))
	offers_container.add_child(panel)


func sign_sponsor(sponsor: Sponsor) -> void:
	var team := GameManager.team
	if (
		team == null
		or sponsor == null
		or team.is_series_season_complete()
		or not team.active_sponsor_id.is_empty()
		or team.sponsor_signed_season == team.season_number
		or team.reputation < sponsor.required_reputation
	):
		return

	team.active_sponsor_id = sponsor.sponsor_id
	team.sponsor_races_remaining = sponsor.contract_length
	team.sponsor_objective_progress = 0
	team.sponsor_objective_completed = false
	team.sponsor_signed_season = team.season_number
	GameManager.add_team_money(sponsor.signing_bonus)
	team.record_finance("Sponsor", sponsor.signing_bonus, "%s signing bonus" % sponsor.sponsor_name)
	GameManager.save_game()
	show_sponsors()


func format_number(number: int) -> String:
	var number_string := str(number)
	var formatted := ""
	while number_string.length() > 3:
		formatted = "," + number_string.right(3) + formatted
		number_string = number_string.left(number_string.length() - 3)
	return number_string + formatted
