#!/usr/bin/env python3
"""Fast, dependency-free validation for repository and Godot source mistakes."""

from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCANNED_EXTENSIONS = {".gd", ".godot", ".tres", ".tscn"}
IGNORED_DIRECTORIES = {".git", ".godot", "__pycache__"}
TEMPORARY_PATTERNS = (
    re.compile(r".*\.tmp$", re.IGNORECASE),
    re.compile(r".*\.tscn\d+$", re.IGNORECASE),
)
FUNCTION_PATTERN = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(", re.MULTILINE)
RESOURCE_PATH_PATTERN = re.compile(r"""["'](res://[^"' \r\n]+)["']""")


@dataclass(frozen=True)
class Problem:
    path: Path
    line: int
    message: str

    def display(self) -> str:
        relative = self.path.relative_to(ROOT).as_posix()
        if os.environ.get("GITHUB_ACTIONS") == "true":
            return f"::error file={relative},line={self.line}::{self.message}"
        return f"{relative}:{self.line}: {self.message}"


def project_files() -> list[Path]:
    return [
        path
        for path in ROOT.rglob("*")
        if path.is_file() and not any(part in IGNORED_DIRECTORIES for part in path.parts)
    ]


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def validate_duplicate_functions(path: Path, text: str) -> list[Problem]:
    declarations: dict[str, int] = {}
    problems: list[Problem] = []
    for match in FUNCTION_PATTERN.finditer(text):
        name = match.group(1)
        current_line = line_number(text, match.start())
        if name in declarations:
            problems.append(
                Problem(
                    path,
                    current_line,
                    f'Function "{name}" duplicates its declaration on line {declarations[name]}.',
                )
            )
        else:
            declarations[name] = current_line
    return problems


def validate_resource_paths(path: Path, text: str) -> list[Problem]:
    problems: list[Problem] = []
    for match in RESOURCE_PATH_PATTERN.finditer(text):
        resource_path = match.group(1)
        if any(marker in resource_path for marker in ("%", "{", "}")):
            continue
        relative = resource_path.removeprefix("res://")
        if not (ROOT / relative).exists():
            problems.append(
                Problem(
                    path,
                    line_number(text, match.start()),
                    f'Resource path does not exist: "{resource_path}".',
                )
            )
    return problems


def validate_temporary_files(files: list[Path]) -> list[Problem]:
    problems: list[Problem] = []
    for path in files:
        relative = path.relative_to(ROOT).as_posix()
        if any(pattern.fullmatch(relative) for pattern in TEMPORARY_PATTERNS):
            problems.append(Problem(path, 1, "Temporary or editor-generated file is committed."))
    return problems


def validate() -> list[Problem]:
    files = project_files()
    problems = validate_temporary_files(files)
    for path in files:
        if path.suffix not in SCANNED_EXTENSIONS:
            continue
        text = path.read_text(encoding="utf-8")
        if path.suffix == ".gd":
            problems.extend(validate_duplicate_functions(path, text))
        problems.extend(validate_resource_paths(path, text))
    return sorted(problems, key=lambda problem: (str(problem.path), problem.line, problem.message))


def main() -> int:
    problems = validate()
    if problems:
        print(f"Project validation failed with {len(problems)} problem(s):")
        for problem in problems:
            print(problem.display())
        return 1
    print("Project validation passed: functions, resource paths, and repository artifacts are valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
