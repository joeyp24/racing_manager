"""Source-level contracts for the compact gamewide UI hierarchy."""

from pathlib import Path
import re


ROOT = Path(__file__).parents[1]
PAGES = ROOT / "scenes/pages"


def test_theme_uses_the_compact_type_scale():
    theme = (ROOT / "ui/motorsport_theme.tres").read_text(encoding="utf-8")
    expected = {
        "PageTitle/font_sizes/font_size": 22,
        "StatValue/font_sizes/font_size": 20,
        "SectionTitle/font_sizes/font_size": 15,
        "CardTitle/font_sizes/font_size": 14,
        "BodyStrong/font_sizes/font_size": 13,
        "MutedLabel/font_sizes/font_size": 11,
        "EyebrowLabel/font_sizes/font_size": 11,
    }
    for property_name, size in expected.items():
        assert f"{property_name} = {size}" in theme


def test_primary_management_pages_use_page_titles():
    page_scenes = (
        "championship/championship.tscn",
        "dashboard/dashboard.tscn",
        "dealership/dealership.tscn",
        "departments/departments.tscn",
        "driver_market/driver_market.tscn",
        "drivers/drivers.tscn",
        "engineering/engineering.tscn",
        "finances/finances.tscn",
        "garage/garage.tscn",
        "offseason/offseason.tscn",
        "race_calendar/race_calendar.tscn",
        "race_entry/race_entry.tscn",
        "race_results/race_results.tscn",
        "race_teams/race_teams.tscn",
        "reputation/reputation.tscn",
        "scouting/scouting.tscn",
        "shop/shop.tscn",
        "sponsors/sponsors.tscn",
        "staff/staff.tscn",
        "world_series/world_series.tscn",
    )
    for relative_path in page_scenes:
        text = (PAGES / relative_path).read_text(encoding="utf-8")
        assert 'theme_type_variation = &"PageTitle"' in text, relative_path


def test_page_scenes_do_not_bypass_the_type_scale():
    oversized = re.compile(r"theme_override_font_sizes/font_size = (2[3-9]|[3-9][0-9])")
    for scene in PAGES.rglob("*.tscn"):
        assert not oversized.search(scene.read_text(encoding="utf-8")), scene


def test_compact_ui_tokens_are_available_to_dynamic_pages():
    tokens = (ROOT / "ui/ui_tokens.gd").read_text(encoding="utf-8")
    for name in (
        "PAGE_MARGIN",
        "CARD_PADDING_HORIZONTAL",
        "CARD_PADDING_VERTICAL",
        "CONTROL_HEIGHT",
        "COMPACT_ROW_HEIGHT",
    ):
        assert f"const {name}" in tokens


def test_management_shell_exposes_persistent_operating_context():
    shell = (ROOT / "scenes/home/home.tscn").read_text(encoding="utf-8")
    for metric in (
        "ScheduleMetric",
        "FinanceMetric",
        "ChampionshipMetric",
        "ReputationMetric",
        "BoardMetric",
        "AttentionMetric",
    ):
        assert f'name="{metric}"' in shell
    assert 'parent="Layout/RightSide/OuterMargin/Stack" instance=ExtResource("2_command")' in shell


def test_management_navigation_is_grouped_by_player_intent():
    shell = (ROOT / "scenes/home/home.tscn").read_text(encoding="utf-8")
    for group in ("RACE DESK", "TEAM", "DEVELOPMENT", "BUSINESS", "WORLD"):
        assert f'text = "{group}"' in shell


def test_status_metrics_support_mouse_and_keyboard_activation():
    component = (ROOT / "ui/components/status_metric.gd").read_text(encoding="utf-8")
    assert 'event.is_action_pressed("ui_accept")' in component
    assert "signal activated" in component


def test_management_decisions_share_the_comparison_drawer():
    component_path = "res://ui/components/decision_comparison_drawer.tscn"
    decision_pages = (
        "dealership/dealership.tscn",
        "shop/shop.tscn",
        "driver_market/driver_market.tscn",
        "staff/staff.tscn",
        "sponsors/sponsors.tscn",
        "engineering/engineering.tscn",
        "departments/departments.tscn",
    )
    for relative_path in decision_pages:
        text = (PAGES / relative_path).read_text(encoding="utf-8")
        assert component_path in text, relative_path
        assert 'name="DecisionComparisonDrawer"' in text, relative_path


def test_comparison_model_always_exposes_financial_consequences():
    model = (ROOT / "scripts/decision_comparison_model.gd").read_text(encoding="utf-8")
    for field in (
        '"upfront"',
        '"recurring"',
        '"cash_after"',
        '"season_end_after"',
        '"reserve"',
    ):
        assert field in model
    assert 'risk_level = "blocked"' in model
    assert 'risk_level = "warning"' in model


def test_comparison_drawer_supports_keyboard_dismissal():
    drawer = (ROOT / "ui/components/decision_comparison_drawer.gd").read_text(encoding="utf-8")
    assert 'event.is_action_pressed("ui_cancel")' in drawer


def test_management_shell_hosts_global_decision_outcomes():
    shell = (ROOT / "scenes/home/home.tscn").read_text(encoding="utf-8")
    manager = (ROOT / "scripts/game_manager.gd").read_text(encoding="utf-8")
    assert "res://ui/components/decision_outcome_receipt.tscn" in shell
    assert 'name="DecisionOutcomeReceipt"' in shell
    assert "signal decision_outcome_reported" in manager
    assert "func report_decision_outcome" in manager
    assert "func consume_decision_outcome" in manager


def test_phase_three_decisions_report_success_and_failure():
    decision_scripts = (
        "dealership/dealership.gd",
        "shop/shop.gd",
        "driver_market/driver_market.gd",
        "staff/staff.gd",
        "sponsors/sponsors.gd",
        "engineering/engineering.gd",
        "departments/departments.gd",
    )
    for relative_path in decision_scripts:
        text = (PAGES / relative_path).read_text(encoding="utf-8")
        assert "GameManager.report_decision_outcome" in text, relative_path
        assert '"status": "error"' in text or '"status":"error"' in text, relative_path


def test_outcome_receipt_is_actionable_and_keyboard_dismissible():
    component = (ROOT / "ui/components/decision_outcome_receipt.gd").read_text(encoding="utf-8")
    assert "signal action_requested" in component
    assert 'event.is_action_pressed("ui_cancel")' in component
    assert 'call_deferred("grab_focus")' in component
