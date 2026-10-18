# PLog

An iOS workout tracker built for progressive overload. Log your sets per exercise per session and instantly see whether you improved on the last time you trained that exercise.

## Features

- **Train** — the tab opens on today's action: start your plan's next day and the session is created with every exercise and set pre-filled from the same set last time; you only nudge the weights. Or start a blank workout. Sets are edited in place with a big ⊖ / ⊕ stepper (hold to repeat, tap the number to type)
- **Progressive overload at a glance** — every set is compared against the same-numbered set from your last session using estimated one-rep max (Epley formula), so trading weight for reps (or vice versa) is still recognized as progress, and a planned back-off set isn't painted as a regression
- **Exercises** — a reusable master list of exercises, organized by muscle group, editable in place, with per-exercise history charts
- **Plans** — build a rotation of day templates (Push, Pull, Legs, …), each pre-filled with target sets × reps per exercise; start a plan to begin logging against it and end it when the program is over. Duplicate a plan to tweak a copy without touching the original; only one plan is ever active at a time
- **Progress** — a dashboard of small, wide and large widgets you add, remove, resize and reorder in place: weekly volume, sessions, muscle-group split, best lifts, an activity grid that opens the month calendar, per-exercise progress charts, and a list of exercises that dipped since last time. Best Lifts expands into a searchable view of any exercise's progress. Your layout is saved and included in backups
- **Settings** — body weight, light/dark/system appearance, and JSON export/import of everything (behind the profile button on Train)
- **Starter content** — first launch seeds an exercise library and two sample plans (Push / Pull / Legs, Upper / Lower) so you can try it immediately

## Requirements

- Xcode 16+
- iOS 17.0+ (SwiftData, Swift Charts, `@Observable`, `ContentUnavailableView`)

## Getting started

1. Clone the repo and open `PLog.xcodeproj` in Xcode.
2. Select a development team under **Target → Signing & Capabilities** (the project ships without one configured).
3. Pick an iOS 17+ simulator or device and hit Run.

The project uses `PBXFileSystemSynchronizedRootGroup`, so any Swift file added under `PLog/PLog/` is picked up automatically — no manual target membership needed.

## Architecture

PLog is a SwiftUI + SwiftData app following MVVM, with `@Query`-driven read screens and `@Observable` view models for mutation-heavy flows. See [AGENT.md](AGENT.md) for the full project layout, data model, and conventions used throughout the codebase.

## License

MIT — see [LICENSE](LICENSE).
