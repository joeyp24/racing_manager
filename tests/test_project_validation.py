"""Regression tests for the dependency-free project validator."""

from pathlib import Path

from tools.validate_project import validate_duplicate_functions, validate_resource_paths


SAMPLE_PATH = Path(__file__).parents[1] / "sample.gd"


def test_duplicate_function_reports_second_declaration_and_original_line():
    source = "func refresh() -> void:\n\tpass\n\nfunc refresh() -> void:\n\tpass\n"

    problems = validate_duplicate_functions(SAMPLE_PATH, source)

    assert len(problems) == 1
    assert problems[0].line == 4
    assert "line 1" in problems[0].message


def test_static_and_instance_functions_cannot_share_a_name():
    source = "static func calculate() -> int:\n\treturn 1\n\nfunc calculate() -> int:\n\treturn 2\n"

    problems = validate_duplicate_functions(SAMPLE_PATH, source)

    assert len(problems) == 1
    assert problems[0].line == 4


def test_missing_literal_resource_path_is_reported():
    source = 'const Missing = preload("res://does/not/exist.gd")\n'

    problems = validate_resource_paths(SAMPLE_PATH, source)

    assert len(problems) == 1
    assert problems[0].line == 1
    assert "does/not/exist.gd" in problems[0].message


def test_dynamic_resource_path_is_ignored():
    source = 'var path := "res://cars/%s.tres" % car_id\n'

    assert validate_resource_paths(SAMPLE_PATH, source) == []
