# PLog

An iOS workout tracker built for progressive overload. Log your sets per exercise per session and instantly see whether you improved on the last time you trained that exercise.

## Features

- **Train** — the tab opens on today's action: start your plan's next day and the session is created with every exercise and set pre-filled from the same set last time; you only nudge the weights. Or start a blank workout. Sets are edited in place with a big ⊖ / ⊕ stepper (hold to repeat, tap the number to type)
- **Progressive overload at a glance** — every set is compared against the same-numbered set from your last session using estimated one-rep max (Epley formula), so trading weight for reps (or vice versa) is still recognized as progress, and a planned back-off set isn't painted as a regression. An open set shows what it was last time and the smallest step that beats it ("60 × 9 or 62.5 × 7"); a set you haven't filled in shows nothing; bodyweight sets are judged on reps
- **Personal records** — a PR mark on the set that beats your all-time best for that exercise
- **Fast first session** — the first weight you enter on an exercise fills the sets after it
- **Rest timer** — a small timer on today's session: tap to start, hold to choose the length, with an optional alert when rest is over
- **Reps in reserve** — optionally record how close to failure each set went (off by default)
- **Kilograms or pounds** — chosen from your region on first launch and changeable in Settings, with the option to convert what you've already logged
- **Exercises** — a reusable master list of exercises, organized by muscle group, editable in place, with per-exercise history charts. 59 common exercises are included
- **Plans** — build a rotation of day templates (Push, Pull, Legs, …), each pre-filled with target sets × reps per exercise, or start from a ready-made program (Full Body, Upper / Lower, Push / Pull / Legs). A plan shows its weekly sets per muscle group against a 10–30 target, planned and done. Duplicate a plan to tweak a copy without touching the original; only one plan is ever active at a time
- **Progress** — a dashboard of small, wide and large widgets you add, remove, resize and reorder in place: weekly volume, sessions, muscle-group split, best lifts, an activity grid that opens the month calendar, per-exercise progress charts, body weight, and a list of exercises that dipped since last time. Your layout is saved and included in backups
- **Body weight** — log your weight and see the trend, from Settings or the Progress card
- **Settings** — units, the optional training extras, appearance, and JSON export/import of everything (behind the profile button on Train)
- **A short welcome** — first launch offers a program and a weight unit on one screen, or skip it and build your own

## Requirements

- Xcode 16+
- iOS 17.6+ (SwiftData, Swift Charts, `@Observable`, `ContentUnavailableView`)

## Getting started

1. Clone the repo and open `PLog.xcodeproj` in Xcode.
2. Select a development team under **Target → Signing & Capabilities** (the project ships without one configured).
3. Pick an iOS 17+ simulator or device and hit Run.

The project uses `PBXFileSystemSynchronizedRootGroup`, so any Swift file added under `PLog/PLog/` is picked up automatically — no manual target membership needed.

To run the tests from the command line:

```sh
xcodebuild -project PLog.xcodeproj -scheme PLog \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -parallel-testing-enabled NO test
```

## Architecture

PLog is a SwiftUI + SwiftData app following MVVM, with `@Query`-driven read screens and `@Observable` view models for mutation-heavy flows. See [AGENT.md](AGENT.md) for the full project layout, data model, and conventions used throughout the codebase, and [docs/ux-audit.md](docs/ux-audit.md) for the audit and research behind the current feature set.

## License

MIT — see [LICENSE](LICENSE).
