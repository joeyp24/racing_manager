# First-hour playtest protocol

Automated checks can verify routing and economy contracts, but they cannot tell us whether a new player understands the game. Run this protocol with at least 10 people who have not worked on the project.

## Session

Give each tester a clean Club-difficulty save and only this instruction:

> Build a team, finish the first race, and prepare the car for the next event. Think aloud when you are unsure.

Do not explain the interface unless the tester is blocked for more than three minutes. Record the intervention and the screen where it happened.

## Measures

The career save records an elapsed time, cash balance, and race count for every guided-opening milestone under `career_state.first_hour.milestones`:

- team identity completed
- driver signed
- car purchased
- sponsor signed
- practice completed
- strategy committed
- first race completed
- first repair completed or upgrade installed

Also record:

- whether the tester could explain the four dashboard questions in their own words
- every attempt to navigate away from a committed weekend
- every term or number that required explanation
- whether the race-outcome story matched what the tester believed happened
- ending cash and whether the tester could explain the change
- the first upgrade they wanted and why

## Targets

- At least 80% finish the opening without developer intervention.
- Median completion time is 35–60 minutes.
- At least 80% can identify the next required action from the dashboard.
- No tester can restart a committed weekend by opening another management page.
- At least 70% correctly identify one position gain and one loss from the outcome story.
- No more than 10% believe a normal bad result made the career unrecoverable.

After every five sessions, group issues by frequency and severity. Fix repeated comprehension failures before adding more tutorial copy or simulation systems.
