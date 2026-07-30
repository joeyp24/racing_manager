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
