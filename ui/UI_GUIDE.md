# Compact Motorsport UI

The interface uses a dense, scan-first system designed for the 1152 × 648
reference viewport. New screens should reuse the global theme and `UITokens`
instead of adding one-off font sizes and spacing values.

## Type hierarchy

| Role | Theme variation | Size |
| --- | --- | ---: |
| Page name | `PageTitle` | 22 |
| Major number | `StatValue` | 20 |
| Section heading | `SectionTitle` | 15 |
| Card or entity name | `CardTitle` | 14 |
| Strong body copy | `BodyStrong` | 13 |
| Body copy | default `Label` | 13 |
| Metadata or help | `MutedLabel` | 11 |
| Category or status eyebrow | `EyebrowLabel` | 11 |

Use the condensed display font for short headings and important values. Use
the regular font for descriptions. Reserve uppercase for short category
labels, statuses, and navigation groups.

## Spacing

Use the constants in `ui/ui_tokens.gd`:

- 4 px for tightly related content
- 6–8 px within a control group
- 10 px horizontal and 8 px vertical card padding
- 12 px between sections and around pages
- 16 px only when a major visual break is required

## Components

- `CardPanel` presents a compact record or grouped controls.
- `HeroPanel` is reserved for the single most important decision on a page.
- `TopbarPanel` contains persistent global status.
- `status_metric` presents one clickable career signal with a value, context,
  and optional progress. The management shell uses it for schedule, finance,
  championship, reputation, board confidence, and pending decisions.
- `CommandBar` is the full-width decision surface below the status strip. It
  presents readiness, the recommended next action, its consequence, and one
  primary route forward.
- `readiness_row` presents a status, explanation, and corrective action.
- `decision_comparison_drawer` is the commitment point for management choices.
  It compares the current benchmark with the candidate, shows immediate and
  per-race cash effects, projects season-end cash, flags reserve risk, and keeps
  the final action available only when eligibility and funds allow it. Buying,
  hiring, sponsorship, engineering, and facility flows should route through it.
- `decision_outcome_receipt` closes that loop from the persistent management
  shell. It confirms success or failure, shows the realized cash effect and new
  balance, refreshes cockpit context, and offers a direct route to the affected
  car, person, contract, project, or facility. Report outcomes through
  `GameManager.report_decision_outcome` so receipts survive page navigation.

Prefer rows and aligned columns over prose-heavy cards. Keep primary actions
at 36 px high and ordinary controls near 32 px. Do not add scene-level font
overrides when a named theme variation describes the role.

The automated UI contracts enforce the typography scale and page-title
hierarchy. The Godot smoke test loads and instantiates every scene under
`scenes/` and `ui/components/`.
