# PLog — Agent Reference

iOS workout tracker for progressive overload. Lets the user log sets per exercise per session and see whether they improved versus the last time they did the same exercise. Workout plans (Push/Pull/Legs-style day templates) can be started/ended and stamp out pre-filled sessions. Four tabs: Train (today's workout + the session log), Progress (analytics dashboard; the month calendar is pushed from it), Plans, Exercises. Settings is a sheet behind the profile button on Train.

---

## Build & Run

**Do not run `xcodebuild` directly.** Use the `BuildProject` MCP tool to build, and `XcodeRefreshCodeIssuesInFile` for fast per-file diagnostics without a full build.

Before pushing any code change, run `XcodeRefreshCodeIssuesInFile` on every file you touched. Only use `BuildProject` to confirm the full target compiles.

The build currently fails on **code signing** (no development team is selected). This is a project setting the user must configure in Xcode → Target → Signing & Capabilities. It is not a code error. Every Swift file compiles cleanly — confirm this with `XcodeRefreshCodeIssuesInFile` when making changes.

The deployment target is set to **iOS 17.0** (updated in `project.pbxproj`). All APIs used are iOS 17+: SwiftData, Swift Charts, `@Observable`, `ContentUnavailableView`.

---

## Project Layout

```
PLog/                        ← repo root
├── .gitignore               ← excludes xcuserdata, DerivedData, .build, etc.
├── README.md
├── AGENT.md
├── CLAUDE.md                 ← pointer to this file
├── PLog.xcodeproj/
│   └── project.pbxproj      ← uses PBXFileSystemSynchronizedRootGroup (see below)
└── PLog/                    ← all Swift source lives here
    ├── PLogApp.swift         ← @main entry point, ModelContainer init
    ├── ContentView.swift     ← root TabView (Train, Progress, Plans, Exercises)
    ├── Models/
    │   ├── MuscleGroup.swift        ← Codable enum, drives category chips + chart colors
    │   ├── Exercise.swift           ← reusable master-list exercise
    │   ├── WorkoutDay.swift         ← one training session
    │   ├── ExerciseEntry.swift      ← exercise-within-a-day join record
    │   ├── SetEntry.swift           ← individual set (weight, reps, RPE, isDrop)
    │   ├── WorkoutPlan.swift        ← a program: name, startedAt/endedAt, day templates
    │   ├── PlanDay.swift            ← one day template ("Push Day") with exercise slots
    │   ├── PlanExercise.swift       ← slot: exercise + targetSets × targetReps
    │   ├── PlanStatus.swift         ← notStarted / active / ended (nonisolated enum)
    │   ├── UserProfile.swift        ← the user's own details; singleton (ensureExists(in:))
    │   └── Gender.swift              ← plain enum incl. .preferNotToSay, not Optional<Gender>
    ├── ViewModels/
    │   ├── ExerciseEntryViewModel.swift   ← per-exercise set list: prefill, duplicate-set, per-set trend
    │   ├── ExerciseHistoryViewModel.swift ← metric picker, chart data, overall trend
    │   ├── ExerciseLibraryViewModel.swift ← search/filter/add/delete for master list
    │   └── WorkoutPlanViewModel.swift     ← start/end, day CRUD, logWorkout(for:) stamping
    ├── Views/
    │   ├── Components/
    │   │   ├── NumberStepper.swift  ← ⊖ / number / ⊕ input for weight/reps/sets/age/etc. — see Code Conventions
    │   │   ├── NameEntrySheet.swift ← "name it first" sheet used to create plans and plan days
    │   │   ├── SupersetViews.swift  ← lettered badge, chain, "Superset · n rounds" title, superset menu items
    │   │   └── TrendBadge.swift     ← green/red/gray capsule pill; CategoryChip
    │   ├── Train/
    │   │   ├── TrainView.swift      ← Train tab: hero card, then sessions by month; Settings sheet
    │   │   ├── TrainHeroCard.swift  ← "Start <next day>" card; other days + blank workout in a menu
    │   │   └── WorkoutDayRow.swift  ← one row: name + date, exercise summary (two lines)
    │   ├── Calendar/
    │   │   └── CalendarView.swift   ← month grid, pushed from Progress; plain stack content
    │   ├── Analytics/
    │   │   ├── AnalyticsView.swift     ← Progress tab (type keeps its name): card dashboard + charts
    │   │   ├── AnalyticsCard.swift     ← card tile, title, BigStat, ProgressRing
    │   │   └── ActivityDotGrid.swift   ← 3-month "did I train?" dot grid
    │   ├── DayDetail/
    │   │   ├── DayDetailView.swift       ← exercises with sets edited inline; metadata behind the title menu
    │   │   ├── SessionDetailsSheet.swift ← name/date/notes editor (Cancel/Done sheet)
    │   │   ├── ExerciseEntryRows.swift   ← one exercise's rows: header, its SetRows, "Add Set", last-time hint
    │   │   ├── SupersetEntryRows.swift   ← a superset merged into one block: chain header, sets interleaved by round
    │   │   └── SetRow.swift              ← one set: summary row; steppers appear in place when expanded
    │   ├── Entry/
    │   │   └── ExercisePickerView.swift  ← searchable sheet to pick from library
    │   ├── History/
    │   │   └── ExerciseHistoryView.swift ← Swift Charts line chart per exercise; Edit button
    │   ├── Plans/
    │   │   ├── PlanListView.swift       ← Plans tab: owns its stack; declares PlanRoute enum
    │   │   ├── WorkoutPlanRow.swift     ← plan row + PlanStatusPill
    │   │   ├── PlanDetailView.swift     ← name, Start/End button, day list, link to log
    │   │   ├── PlanDayDetailView.swift  ← day template: name + exercise slots
    │   │   ├── PlanExerciseRow.swift    ← slot row with sets/reps steppers
    │   │   ├── PlanSupersetRow.swift    ← a superset merged into one row: shared Rounds stepper + reps per exercise
    │   │   └── PlanLogView.swift        ← date-by-date log with Rest Day gaps, "Up Next"
    │   ├── Exercises/
    │   │   ├── ExerciseLibraryView.swift ← Exercises tab: searchable list by category; owns its stack
    │   │   └── AddExerciseView.swift     ← create OR edit (exercise: Exercise? param)
    │   └── Settings/
    │       ├── SettingsView.swift        ← Settings sheet: theme, body weight, Data section
    │       └── DataTransferSection.swift ← Export/Import buttons, file pickers, confirm alerts
    └── Utilities/
        ├── ProgressiveOverload.swift ← SetSnapshot, ProgressTrend, overload logic
        ├── WorkoutHistory.swift      ← read-only helpers: previousEntry, historyPoints
        ├── WorkoutLogger.swift       ← stamps a PlanDay into a WorkoutDay; suggestedNextDay
        ├── WorkoutCalendar.swift     ← month grid cells + trained/rest/pending/inactive status
        ├── WorkoutStats.swift        ← analytics aggregations: volume, weekly, split, streak, best lifts
        ├── Supersets.swift           ← superset blocks, join/insert/remove/ungroup/move/normalize (entries + plan slots)
        ├── StarterData.swift         ← first-launch seed: exercise library + 2 sample plans
        ├── DataBackup.swift          ← JSON backup format (PLogBackup) + export/decode/restore
        ├── AppTheme.swift            ← system/light/dark @AppStorage preference
        ├── Formatters.swift          ← WeightFormatter, Date extensions
        └── SampleData.swift          ← in-memory ModelContainer for SwiftUI previews
```

### File system sync (important)

`project.pbxproj` uses `PBXFileSystemSynchronizedRootGroup` — any Swift file added under `PLog/PLog/` is **automatically compiled** into the target. You do not need to edit `project.pbxproj` when adding or moving files. Never hand-edit `project.pbxproj` while Xcode is open.

---

## Data Model

### Relationships & delete rules

```
WorkoutDay  ──cascade──►  ExerciseEntry  ──cascade──►  SetEntry
Exercise    ──nullify──►  ExerciseEntry
Exercise    ──nullify──►  PlanExercise
WorkoutPlan ──cascade──►  PlanDay  ──cascade──►  PlanExercise
PlanDay     ──nullify──►  WorkoutDay   (WorkoutDay.planDay = template it was logged from)
```

- Deleting a `WorkoutDay` cascades to its `ExerciseEntry` records, which cascade to their `SetEntry` records.
- Deleting an `Exercise` from the master library **nullifies** (does NOT cascade) the `ExerciseEntry.exercise` reference. Historical log entries survive with `exercise == nil`.
- Deleting a `WorkoutPlan` removes its templates but **never** the `WorkoutDay` sessions logged from it (`PlanDay.loggedDays` is nullify). An **active** plan can't be deleted at all — `PlanListView` blocks the swipe and shows an alert; end the plan first.
- `@Relationship` inverse declarations live on one side only (the convention SwiftData prefers to avoid ambiguity).

### Mutate relationships from the to-many side

Setting only the to-one side (`slot.planDay = day`, or passing it to the `init`) updates the inverse array in SwiftData but does **not** fire Observation on the parent, so a view reading `day.exercises` won't refresh. Always `context.insert(child)` then `parent.children.append(child)` (and `parent.children.removeAll { $0 === child }` before `context.delete`). `WorkoutPlanViewModel` and `PlanDayDetailView` follow this; the older `DayDetailView.addExercise` only works because it also flips a `@State`.

### Ordering

`ExerciseEntry` has an `order: Int` field for stable positioning within a day. `WorkoutDay.orderedEntries` and `ExerciseEntry.orderedSets` sort on this / on `setNumber`. Always use these computed properties in the UI instead of `.entries` or `.sets` directly.

### All eight models must be listed in the Schema

`PLogApp` and `SampleData` both construct `ModelContainer` with an explicit `Schema([WorkoutDay.self, Exercise.self, ExerciseEntry.self, SetEntry.self, WorkoutPlan.self, PlanDay.self, PlanExercise.self, UserProfile.self])`. Add any new `@Model` class here too.

### Light/Dark mode is an `@AppStorage` preference, not `UserProfile`

`AppTheme` (`Utilities/AppTheme.swift`: `.system`/`.light`/`.dark`) is read via `@AppStorage("appTheme")` in **both** `PLogApp` (applies `.preferredColorScheme(appTheme.colorScheme)` to the root view — `nil` for `.system` means "follow the device") and `SettingsView`'s `Picker`. Two independent `@AppStorage` properties with the same key stay in sync automatically because they share the same `UserDefaults` storage; there's no manual plumbing between them. This is deliberately **not** a `UserProfile` field — it's a UI preference, not user data, and `@AppStorage` (unlike a SwiftData `@Query`) is available synchronously the instant the App struct's `body` is evaluated, before the container/first query has resolved. Follow the same `@AppStorage` (not `UserProfile`) approach for any future pure-UI preference — the still-open weight-unit (kg/lbs) preference belongs here too.

### Gender is a plain two-case enum

`Gender` has exactly two cases, `.female` and `.male` — no "prefer not to say"/non-binary option; that was tried and deliberately walked back. `UserProfile`'s default is `.female`. If a third option is ever wanted, add the case back to `Gender.swift` and give `UserProfile.init` a real default again; don't special-case a `nil`/optional `Gender` for it.

**`name`, `gender`, `age` and `heightCm` are persisted but not surfaced.** Settings only edits `weightKg` — the one field a feature reads (Analytics' body-weight card). The other fields stay on the model and in `DataBackup` so existing backups round-trip unchanged; they were removed from the Settings form because asking for data nothing displays is clutter. Put them back in the UI only alongside a feature that consumes them.

### MuscleGroup categories

`biceps` / `traps` / `triceps` / `forearms` are all specific arm/shoulder-girdle categories — there's no generic "arms" catch-all anymore. `StarterData`'s "Tricep Pushdown" is tagged `.triceps`, "Bicep Curl"/"Hammer Curl" are `.biceps`; new seed/preset exercises should always prefer the most specific matching category. Every new `MuscleGroup` case needs a `displayName`, `systemImage`, and `color` — the three `switch` statements are exhaustive, so the compiler catches a missing case, but picking a `systemImage` that doesn't actually exist as an SF Symbol will still compile and just render blank at runtime; verify a new icon on-device/in a preview, don't just trust the compiler.

**Renaming a case**: `biceps` was originally `arms`, renamed for clarity once `triceps`/`forearms` existed and made the old generic name confusing. The case declaration explicitly pins the raw value to the old name (`case biceps = "arms"`) so any `Exercise` already persisted with that category — including on a device/simulator that had the app installed before the rename — still decodes correctly; only the displayed label changed. **Follow this pattern for any future enum-case rename on a `@Model` property** (`Gender`, `MuscleGroup`, `PlanStatus`, `AppTheme`): `case newName = "oldRawValue"`, never a bare rename — a bare rename changes the persisted raw string too, and existing rows with the old string silently fail to decode.

### UserProfile is a guaranteed singleton

`UserProfile.ensureExists(in:)` is called unconditionally at launch (`PLogApp`) and in `SampleData` — exactly one row always exists by the time `SettingsView` appears. `SettingsView` reads `profiles.first` and treats it as non-optional in practice (the `nil` branch is only reachable for the one frame before `ensureExists` commits). Don't add a second code path that creates a `UserProfile`.

### A set has no "completed" flag

`SetEntry` was simplified to drop its old `completed: Bool` tick box. A set's existence in `ExerciseEntry.orderedSets` **is** its "added" state — there's no separate in-progress/done toggle to manage. Don't reintroduce one without a concrete reason; it previously added UI weight (a checkbox on every set row and a checkmark on every exercise row) without affecting `ProgressiveOverload` or any query.

### Drop sets are flagged sets, not a separate model

A drop set is a `SetEntry` with `isDrop = true` that belongs to the nearest **working** set before it. `ExerciseEntry.setGroups` returns each working set followed by its drops; `workingSets` is the first of each group. `setNumber` stays a plain 1-based position across all sets (ordering only) — the UI never shows it: `ExerciseEntryViewModel.title(for:)` numbers working sets only ("Set 1, Set 2, Drop, Set 3"), and `SetRow` indents drops under a turn arrow. "N sets" in the exercise header and the set counts in `WorkoutStats` count working sets; volume includes drops (it's real work).

- **Adding:** "Add Drop Set" in the add row drops off the last set; a set row's context menu (on the summary label only — a long-press on the steppers is hold-to-repeat) adds a drop after *that* set's group and converts between working set and drop. The first set can't become a drop. A new drop is seeded from the same drop last session, otherwise ~80% of the set it follows (rounded to 2.5) at the same reps. `addSet()` seeds from the last *working* set, never a drop.
- **Deleting a working set deletes its drops** (`removeSets`), like a reminder's subtasks — otherwise they'd silently re-attach to the previous set.
- **Comparison:** set *n* vs set *n* uses working sets only (`WorkoutHistory.previousSets` skips drops, so `WorkoutLogger` prefill isn't shifted either); a drop is graded only against the same drop (same group, same position) last time and shows no trend when there wasn't one.
- `isDrop` has a property default so SwiftData migrates existing stores; `PLogBackup` is version 2 with an optional `SetRecord.isDrop` (v1 files read as `false`).

### Supersets are adjacent runs sharing a `supersetID`, shown merged

`ExerciseEntry` and `PlanExercise` both carry an optional `supersetID: UUID` (and conform to `SupersetMember`, which also exposes `order`). A superset is a **run of adjacent members** with the same ID — membership is never stored as a list, so reordering can't leave a superset pointing at something far away. All logic is in `Supersets` (`Utilities/Supersets.swift`), shared by `DayDetailView` and `PlanDayDetailView`.

**A superset is drawn as one merged block, not as tagged rows.** Both screens render `Supersets.blocks(in:)` — a plain exercise or a whole superset — and `ForEach` over blocks, so a superset **drags and (in plans) swipe-deletes as one**. A tagged-rows version (an "A1"/"A2" pill on each exercise) was tried first and rejected: the exercises still read as separate things.
- **Header:** "🔗 Superset · n rounds", then the exercises stacked on a *chain* — a `SupersetBadge` letter node per exercise with a connector line running down to the next (`SupersetChain`). The connector fills the rest of each item's height, so it meets the next node however tall the name/chip wraps.
- **Session (`SupersetEntryRows`)**, expanded: the sets interleaved by **round** — round *n* is each exercise's working set *n* plus its drops, in A, B… order — under compact "Round n" labels (tight insets, no separator below; `DayDetailView` lowers `defaultMinListRowHeight` to 28 to allow them). Each set row shows its exercise's badge and name instead of "Set n". "Add Round" adds one set to every exercise. Each exercise keeps its own `ExerciseEntryViewModel`, so prefill, drops and trends are unchanged. The block's `SupersetBlock.id` is every member's ID, so a membership change gives it a fresh identity and its view models rebuild.
- **Plan (`PlanSupersetRow`)**: one `DisclosureGroup`; content is a shared **Rounds** stepper (sets every slot's `targetSets`) plus a reps stepper per exercise.
- **Actions** (context menu on the block header — on a `DisclosureGroup` *label* in plans, never the steppers): a submenu per exercise (History / Remove from Superset / Remove), "Add Exercise to Superset…", join the neighbouring block, "Ungroup Superset". A plain row offers "Superset with New Exercise…" (opens the picker; `Supersets.insert` links the pick in right after it — the main way to build one) and "Superset with Previous/Next". The session block's trailing swipe is **Ungroup**, not Delete — one swipe shouldn't take several exercises' sets.
- **Every mutation ends in `Supersets.normalize`**: a member left alone loses its ID, and a run whose ID an earlier run already uses gets a fresh one (otherwise two supersets would silently merge if they became adjacent). `remove` moves the member out to just *after* its superset so the rest stay together.
- `WorkoutLogger` copies each slot's `supersetID` onto its entry (then normalizes, since a slot whose exercise was deleted is skipped); `WorkoutPlanViewModel.duplicate` copies it too. IDs only need to be unique within one list. `PLogBackup` version 3 carries `supersetID` on entries and plan slots.

---

## Architecture

### Pattern: MVVM with SwiftData constraints

`@Query` only works inside a `View` (`@Query` is a property wrapper tied to the SwiftUI environment). The split is:

- **List/read screens** (`TrainView`, `ExerciseLibraryView`, `ExercisePickerView`): use `@Query` directly, keep filtering/grouping inline as computed properties.
- **Mutation-heavy screens** (`ExerciseEntryRows`, `PlanDetailView`): use an `@Observable` view model (`ExerciseEntryViewModel`, `WorkoutPlanViewModel`) that holds the `ModelContext` and owns all insert/delete logic. `ExerciseEntryViewModel` is created per exercise on the session screen; it does **not** prefill in `init` — `ExerciseEntryViewModel.prefill(_:in:)` is called exactly once, by `DayDetailView.addExercise`, so an entry whose sets were all deleted stays empty instead of regrowing a set every time its rows are rebuilt.

### Passing ModelContext to view models

`@Environment(\.modelContext)` is not available during a view's `init`. The pattern used here is:

```swift
// In the View:
init(entry: ExerciseEntry, context: ModelContext, …) {
    _viewModel = State(initialValue: ExerciseEntryViewModel(entry: entry, context: context))
}

// Called from the parent (which reads @Environment(\.modelContext) in its body):
ExerciseEntryRows(entry: entry, context: context, …)
```

Do not deviate from this pattern. Do not try to capture `@Environment` in an `init` — it will crash.

### Navigation

`TrainView` owns a `NavigationStack(path: $path)` with a typed `[WorkoutDay]` path. To push a newly created day immediately to its detail screen, call `path.append(day)` after inserting. Sheets are used for all editor flows (entry form, exercise picker, library actions).

`PlanListView` (the Plans tab) owns a `NavigationStack` over a `NavigationPath` (mixed types: `WorkoutPlan`, `PlanDay`, `WorkoutDay`, `PlanRoute`) and registers every `navigationDestination(for:)` at the stack root. **Push everything by value** in this stack. A view-builder `NavigationLink { … }` leaves its destination outside the path and `NavigationLink(value:)` rows inside it silently do nothing (row highlights, no push) — that's why the log screen is reached via `PlanRoute.log(plan)`. Screens that need to push programmatically (`PlanLogView` after logging) take `path: Binding<NavigationPath>`; `PlanListView` uses its own path to open a freshly named plan.

`ExerciseLibraryView` (the Exercises tab) owns its own `NavigationStack` with one destination, `Exercise` → `ExerciseHistoryView`, reached from rows via `NavigationLink(value: exercise)`.

Plans and Exercises used to share one "Library" tab behind a segmented Plans | Exercises picker in the nav bar (the picker had to live there because Exercises' search field occupies the slot below the title). That saved a tab at the cost of a hidden mode switch and mismatched nav-bar chrome between the two sections; two plain tabs with large titles are simpler.

**New plans and plan days are named before they exist.** "+" on Plans and "Add Day" on a plan both present `NameEntrySheet` (`Views/Components/NameEntrySheet.swift` — the Reminders "New List" pattern: focused field, Cancel / Create disabled while blank). The record is inserted only on confirm, so backing out never leaves an unnamed placeholder behind and there is no phantom-record cleanup anywhere. Don't insert-then-push for a new record; name it first.

`AnalyticsView` (the Progress tab) owns its own `NavigationStack` and registers three destinations: `Exercise` → `ExerciseHistoryView` (best-lifts rows), `ProgressRoute.calendar` → `CalendarView` (the activity card is a `NavigationLink(value:)`), and `WorkoutDay` → `DayDetailView` (the calendar's session rows push through this stack). `CalendarView` is plain stack content — it must not wrap itself in a `NavigationStack`. `SettingsView` is presented as a sheet from `TrainView`'s profile button and keeps its own `NavigationStack` (with a Done button), which is fine for a sheet.

### Plans → sessions (the Train tab)

`WorkoutLogger.logWorkout(for:on:in:)` stamps a `PlanDay` template into a `WorkoutDay`: one `ExerciseEntry` per slot with `targetSets` sets at `targetReps`, weight prefilled from `WorkoutHistory.previousTopSet` — so logging a plan day means only adjusting weights. It's called from two places that must stay in sync: the **Train tab**'s hero card (`TrainHeroCard`: one prominent "Start <`WorkoutLogger.suggestedNextDay`>" button, the other days and "Blank Workout" behind a "Different day" menu; with no loggable plan it offers a blank workout and points at the Plans tab — there is no `+` in the toolbar, the card *is* the daily action) and the plan's own log screen via `WorkoutPlanViewModel`. `DayDetailView` shows a "Plan Day" row for stamped sessions.

`PlanLogView` lists only the sessions stamped from the plan's days (`allDays.filter { $0.planDay?.plan === plan }`), newest first by month, plus the "Up Next" row. It used to pad the list with a row for every rest day in the plan's window (`PlanTimeline`, since deleted) — a 12-week plan rendered ~60 "Rest Day" rows around a handful of sessions. The calendar (Progress → Activity) is where rest days are counted.

### Calendar & Progress are read-only over `@Query`

Both screens follow the list/read-screen pattern: `@Query` in the view, all math in pure helpers. `WorkoutCalendar.monthCells(for:workouts:historyStart:)` classifies every date as `.trained(sessions:)`, `.rest`, `.pending` (today, nothing logged) or `.inactive` (future, or before `historyStart`). **A rest day is only a past date on/after `historyStart`** — the earliest session or earliest `plan.startedAt` — so a fresh install isn't a wall of "rest days". The Progress activity grid reuses these cells (`WorkoutCalendar.weeks` chunks them into 7-wide columns), so the two screens can't disagree about which days count.

**Calendar cell language is iOS Calendar's, by design.** A trained day is a filled accent circle with a white number; today is an accent number; the selected day is a filled label-coloured circle with an inverted number, plus a small accent dot beneath it when it was also trained. Rest and inactive days get *nothing* — an earlier version drew an open-circle dot under every past rest day plus a legend, which decorated the default state and made the grid noisy; the month summary caption ("3 workouts · 6 rest days") carries the rest-day count in words instead. Don't add per-day decoration for the absence of a workout.

`WorkoutStats` (weekly summaries, daily volumes, muscle split, week streak, best lifts) always returns fixed-width series that include empty periods as zeros, so bar charts keep a stable width. Weeks are bucketed by `Calendar.dateInterval(of: .weekOfYear)` start, honoring the device's first weekday. The "Best lifts" trend reuses `ProgressiveOverload.trend` on the last two sessions' top sets — don't compare raw weights there either. Volume totals display via `WeightFormatter.volumeString` (grouped, no decimals); individual weights still use `WeightFormatter.string`.

`AnalyticsView`'s cards use `Color(uiColor: .secondarySystemGroupedBackground)` tiles on a `.systemGroupedBackground` scroll view so they look right in both themes; wrap any new widget in `AnalyticsCard` rather than inventing another card style (`TrainHeroCard` uses it too — it's the app's one card container). Cards are 16-pt continuous-radius with 16-pt gaps between them and 12-pt spacing inside (8-pt grid).

**Exactly one plan can be active.** `WorkoutPlanViewModel.start()` fetches every plan and sets `endedAt` on any other active one before starting this one. `TrainView` relies on this (`plans.first(where: \.isActive)`). Don't add another code path that sets `startedAt` without going through `start()`.

### Exercises are editable in place

`AddExerciseView` handles both create and edit: an optional `exercise: Exercise?` init param switches its title/behavior, and on save it mutates the passed-in `Exercise` directly rather than inserting a new one. Reached via a leading `.swipeActions` "Edit" button in `ExerciseLibraryView` and a toolbar Edit button on `ExerciseHistoryView` (both present the same sheet). Don't add a second exercise-editing form — extend this one.

**Seed `@State` from `init`, not `.onAppear`, for a form nested inside a `NavigationStack` with its own pushed screens.** `AddExerciseView`'s `category` used to be seeded via `.onAppear`, which reset it back to `exercise.category` every time the "Muscle Group" `.pickerStyle(.navigationLink)` screen was popped back to — `.onAppear` fires again on reappearance, not just on first appearance, so the just-picked category was silently stomped back to its original value before the user ever saw it stick. The fix is a custom `init(exercise:prefilledName:onCreate:)` that sets `_name`/`_category`/`_notes` directly (`State(initialValue:)`), which only ever runs once. Any future form with a sub-navigation picker (not just a `.sheet`-presented one) needs the same treatment.

### Duplicating a plan

`WorkoutPlanViewModel.duplicate(_:in:)` (static) deep-copies a plan's days and exercise slots into a new plan that is always inactive (`startedAt`/`endedAt` left `nil`) — the original plan's status is untouched. The copy's name is `"<base> (n)"`: `baseName(from:)` strips a trailing `" (N)"` suffix before appending the next free number, so duplicating "PPL (1)" produces "PPL (2)", not "PPL (1) (1)". Reached via a leading `.swipeActions` button in `PlanListView`.

### First-launch starter data

`PLogApp` calls `StarterData.seedIfNeeded(in:)` right after building the container. It seeds only when there are **zero** `Exercise` rows: a 20-exercise library across all muscle groups, an active "Push / Pull / Legs" plan (3 days, 5 slots each) and a not-started "Upper / Lower" plan. It never touches a store that already has data. This is distinct from `SampleData`, which is the in-memory preview fixture and also seeds workout history.

### Save model: pushed screens autosave, sheets are Cancel/Done

Two lanes, matching how Apple's own apps behave — pick one per screen, never mix them:

- **Pushed detail screens** (`PlanDetailView`, `PlanDayDetailView`; `DayDetailView` hosts the sets, which bind straight into `SetEntry`) live-bind `@Model` properties and **autosave** (the Notes/Reminders model). They use the system back button and title; the edge-swipe-back gesture always works; nothing is confirmed on the way out. Structural changes (add/remove a set, exercise, day) call `try? context.save()` immediately, as everywhere else.
- **Sheets that draft locally** (`AddExerciseView`, `NameEntrySheet`, `SessionDetailsSheet`) keep Cancel / Save (or Create / Done) and `.interactiveDismissDisabled(hasChanges)` with a "Discard Changes?" `.alert` — the modal-editor model. The model is never touched until Save.

**Don't reintroduce a back-button guard.** An earlier version replaced the system back button on the pushed screens with a custom one that asked Save / Discard / Cancel and showed an orange "Unsaved" tag in the title. That bolted a modal save model onto detail screens: it hid the platform back button, killed swipe-back, and (on iOS 26) opted those screens out of the system's glass back button entirely — while the sheets already had a proper Cancel/Done. If a screen genuinely needs a safety net for accidental edits, the platform answer is `UndoManager` (`context.undoManager`, shake-to-undo), not a confirmation on back.

`SettingsView` (a sheet with a Done button) live-applies preferences, as Settings apps conventionally do.

**A session's name, date and notes live behind the title.** `DayDetailView` sets `.navigationTitle` to the session name (or its date when unnamed) and attaches `.toolbarTitleMenu` with "Edit Details…" (→ `SessionDetailsSheet`) and "Delete Workout" (stage-then-`.alert`, then `dismiss()`), the Notes/Freeform pattern; the exercises section header shows "date · plan name", and a Notes section appears at the bottom only when there is a note. This exists so the exercises are the first thing on the screen — the old "Session" form section (name field, date picker, notes) pushed the actual content below the fold.

### Data export / import is a JSON snapshot, not the SwiftData store

`DataBackup` (`Utilities/DataBackup.swift`) serialises the whole object graph to one `PLogBackup` JSON document (ISO-8601 dates, pretty-printed) and restores it. Cross-references (`PlanExercise.exercise`, `ExerciseEntry.exercise`, `WorkoutDay.planDay`) are written as **export-time UUIDs** — `PersistentIdentifier` is not stable across stores, so it never appears in the file. `PLogBackup.currentVersion` is stamped into every file; `decode` refuses a newer version with a clear message. **Bump the version and add a migration branch in `decode` when a record's shape changes** — don't silently add required fields.

**Import is replace-all, never merge.** `restore` deletes sessions → plans → exercises (in that order so cascade/nullify rules never leave dangling links), then re-inserts everything appending from the to-many side per the relationship rule above. The `UserProfile` row is updated in place so the singleton guarantee holds. `DataTransferSection` (Settings → Data) parses the picked file first and shows counts in a "Replace All Data?" `.alert` before anything is touched. Enum raw values that no longer decode (`MuscleGroup`, `Gender`) fall back to `.other`/`.female` rather than failing the import.

The file picker URL is security-scoped — reads must be wrapped in `startAccessingSecurityScopedResource()`. `BackupDocument` (the `FileDocument` for `.fileExporter`) is declared `nonisolated` because the project's default `MainActor` isolation otherwise conflicts with the protocol's nonisolated requirements; do the same for any future `FileDocument`/`Transferable` type.

### Destructive actions confirm first — use `.alert`, not `.confirmationDialog`

Deleting a `WorkoutPlan` (`PlanListView`), ending a plan (`PlanDetailView`), deleting an `Exercise` (`ExerciseLibraryView`), or importing a backup (`DataTransferSection`) stages the target in `@State` and shows a confirmation before calling `context.delete`/mutating. Stage-then-confirm, not delete-then-undo, for any new destructive action.

**Use `.alert`, never `.confirmationDialog`, for these.** On the iOS version this app has been tested against, `.confirmationDialog` does not reliably render as the standard bottom action sheet — it can instead render as a small anchored callout that latches onto an arbitrary ancestor view (e.g. the top of a `List`) instead of the row that triggered it, pointing at the wrong item, and it can drop its `Cancel` button entirely. `.presentationCompactAdaptation(.sheet)` does **not** fix this. `.alert` sidesteps the whole problem — it's always a centered, unanchored modal, so there's no anchor to get wrong. This was root-caused and fixed for the plan-delete, plan-end, and exercise-delete confirmations; don't reintroduce `.confirmationDialog` for a destructive action without re-verifying on-device first.

Also prefer a single root-level (`NavigationStack`-level) `.alert` over one attached per-row inside a `ForEach`/`.swipeActions`: a per-row presentation attached to a row that a `.swipeActions` button just collapsed can silently fail to appear (the request seems to get lost in that transient teardown). `ExerciseLibraryView` and `PlanListView` both hold a single `pending…` `@State` (an optional model, or an array) and one alert at the stack root, gated by a computed `Binding<Bool>` when needed.

---

## Progressive Overload Logic

The core algorithm lives in `Utilities/ProgressiveOverload.swift` and `Utilities/WorkoutHistory.swift`.

**Do not compare weight or reps directly.** Use `SetSnapshot.estimatedOneRepMax` (Epley formula: `weight × (1 + reps/30)`) to classify improvement vs regression. This handles the case where a user trades weight for reps or vice versa — both register as the same 1RM and thus don't spuriously count as regression.

```
SetSnapshot(weight: 65, reps: 6).estimatedOneRepMax  ≈ 78
SetSnapshot(weight: 60, reps: 8).estimatedOneRepMax  ≈ 76
// → 65×6 is classified as .improved over 60×8
```

A tolerance of `0.01` is applied to avoid floating-point noise registering as a change.

**Which previous set a set is compared to — set *n* vs. set *n*.** `ExerciseEntryViewModel.trend(for:)` grades a set against the **same-numbered** set from the previous session (`WorkoutHistory.previousSets(for:excluding:)`, in performed order), falling back to the previous session's top set only for a set number the previous session didn't have. It used to compare every set to the top set, which painted a deliberate back-off third set red and taught users to ignore red — the whole signal loses credibility if it's wrong about normal training. Session-level questions still use the top set: `ExerciseHistoryView`'s overall trend and `WorkoutStats.bestLifts` compare sessions' best sets, and the "Last time" hint shows `previousTopSet`.

**Prefill follows the same rule.** `WorkoutLogger.logWorkout` gives set *n* the weight of last session's set *n* (top-set weight if there was no set *n*, `0` with no history); reps come from the plan's `targetReps`. `ExerciseEntryViewModel.addSet()` seeds the next set from last session's same-numbered set when there was one, otherwise duplicates the last set. `ExerciseEntryViewModel.prefill(_:in:)` (a brand-new entry's first set, called once from `DayDetailView.addExercise`) uses the top set — set 1 usually *is* the top set. `previousTopSet`/`previousSets` are `SetSnapshot`s (model-free; safe to pass around the UI).

---

## SwiftUI Previews

Every screen has a `#Preview` using `SampleData`:

```swift
#Preview {
    TrainView()
        .modelContainer(SampleData.container)
}
```

`SampleData.container` is an **in-memory** `ModelContainer` (`isStoredInMemoryOnly: true`) seeded with:
- 3 Push Day sessions showing bench press progression: 60kg×8 → 62.5kg×8 → 62.5kg×9
- 1 Leg Day with 4×5 back squats at 100kg
- An active "Push / Pull / Legs" plan started 21 days ago; the Push and Leg sessions are linked to its templates
- One `UserProfile` row (via `UserProfile.ensureExists`), so `SettingsView`'s preview never hits the empty-state branch
- Convenience accessors: `SampleData.benchPress`, `SampleData.recentDay`, `SampleData.plan`, `SampleData.pushDay`

When adding a new screen, always wire up a `#Preview` using `SampleData.container`. Never use the production container in previews.

---

## Code Conventions

- **Swift version:** 5.0, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- **Naming:** PascalCase for types, camelCase for properties/methods
- **Models:** `final class`, `@Model`, explicit `init` with default arguments
- **View models:** `@MainActor @Observable final class`
- **Views:** `struct`, conforms to `View`, `body` as the sole entry point
- **State:** `@State private var` for local view state; `@Bindable var` to bind directly into `@Model` properties (e.g. `DayDetailView` editing `WorkoutDay.name`)
- **Imports:** only what is needed — `Foundation + SwiftData` for any file that references SwiftData types (including `PersistentIdentifier`); `SwiftUI + SwiftData` for views that use `@Query` or `.modelContainer`; add `import Charts` for any chart view. `PersistentIdentifier` is in SwiftData, not Foundation — missing this import is a common build failure.
- **Comments:** only when the WHY is non-obvious (e.g. the nullify vs cascade decision). No docstrings on obvious getters
- **No Combine** — use `async/await` and `@Observable` instead
- **No force unwrap** in production code; sample data accessors may use `!` only where the data is known-seeded

### Accessibility: colour on the icon and fill, never on small text

Every tinted pill — `TrendBadge`, `CategoryChip`, `PlanStatusPill` — puts the semantic colour on its SF Symbol (or a leading dot) and on the capsule fill (`color.opacity(0.15)`); the **text is always `.primary`**. System green/red/orange/yellow/mint/cyan as *text* on a light background are 1.5–3.5:1, all under the 4.5:1 AA floor, and `.caption`-sized text is exactly where that bites. Label colour on any grouped background is ≥ 15:1, and system colours pick up their high-contrast variants under Increase Contrast on their own. `MuscleGroup.core` is `.brown` rather than `.yellow` because yellow fails even as a fill/icon on a light card. `AccentColor` is declared in the asset catalog (system blue's light/dark pair) rather than left to the default — the choice is deliberate: every other hue is a muscle group or plan status, and blue already means "trained / interactive" across the calendar, charts and buttons. Switching to a signature colour later is one asset edit, but check it against `MuscleGroup`/`PlanStatus` first. Don't add a new coloured-text pill; don't use `.caption2` for anything (the smallest text style in the app is `.caption`).

**Dynamic Type.** No fixed point sizes or widths on anything that holds text: `BigStat` takes a `Font.TextStyle`, not a number; segmented pickers size to their labels (the Analytics range picker and the old Library picker had hard-coded widths that clipped); dimensions that should grow with text use `@ScaledMetric` (calendar day circles, rings, legend dots, stepper buttons). Layouts that put two things side by side use `ViewThatFits(in: .horizontal) { HStack {…}; VStack {…} }` (Analytics card pairs and card headers, the two hero steppers in `SetRow`/`PlanExerciseRow`, the muscle-split donut + legend), or switch on `dynamicTypeSize.isAccessibilitySize` when the two arrangements aren't the same children (`WorkoutDayRow`, the `ExerciseEntryRows`/`SetRow`/`PlanExerciseRow` headers). Two deliberate exceptions: the activity dot grid and the muscle-split donut are charts, not text, and keep fixed sizes so three months of weeks still fit across the card; and every Swift `Chart` is capped at `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` because axis labels collide above that — the same approach Health takes. Verify at `accessibility-extra-extra-extra-large` (`xcrun simctl ui <udid> content_size …`); anything that wraps word-per-word or pushes the page wider than the screen (a vertical `ScrollView` silently centres over-wide content, which shows up as the *nav title* being cut off) needs one of the treatments above.

VoiceOver labelling beyond `TrendBadge`/`CategoryChip`/`PlanStatusPill`/`NumberStepper` is still to do.

### WeightFormatter

Always use `WeightFormatter.string(_:)` to display weights — drops `.0` for whole numbers (`60` not `60.0`), keeps one decimal for halves (`62.5`). Do not use `String(format:)` or `.formatted()` on weight values directly.

### NumberStepper

All weight/reps/sets/age/height/weight entry uses `NumberStepper` (`Views/Components/NumberStepper.swift`) — a ⊖ / number / ⊕ control, not free text and not a wheel. It has a `Double` `init` (`title, value, step, range, unit, style, format, keyboard`) and an `intValue:` convenience init mirroring it. Two layouts via `style:`: `.hero` (default — caption title above, large rounded number between the buttons; used in `SetRow` and `PlanExerciseRow`, two side by side in an `HStack(spacing: 24)`) and `.row` (a single form row, title leading and the compact control trailing; used in `SettingsView`).

Behavior worth knowing before touching it:

- **Tap steps once; hold repeats.** `RepeatButton` (private, same file) reads `isPressed` from its `ButtonStyle` — set on touch-down, and reliably cleared if the enclosing List's scroll cancels the touch — and runs a `Task` that waits 400 ms, then steps every 80 ms, dropping to 40 ms after ~1 s (`RepeatTiming`). The `Button`'s own action only fires when the hold loop never ran, so a release after a hold doesn't add one extra step. This was first written on a `DragGesture(minimumDistance: 0)`, which can be cancelled by the scroll view without `onEnded` ever firing and would leave the loop running forever — hence the `ButtonStyle`.
- **Haptics on every step**, including during a hold: `.sensoryFeedback(.increase/.decrease, trigger: value)` with a direction predicate.
- **Tap the number to type an exact value.** It swaps to an inline `TextField` (`.decimalPad`, or `.numberPad` for the int init), seeded once from the value (see the `AddExerciseView` "seed from init" note for why it's not re-derived per keystroke — reformatting mid-entry drops a just-typed "."), parsed with `,` → `.`, clamped to `range`, and committed when focus ends (keyboard "Done" / return).
- **Values don't need to sit on a step grid.** The old wheel `Picker` silently failed to highlight anything unless the bound value exactly matched a row tag, so every producer had to emit grid-aligned numbers. A stepper just adds `step` to whatever's there (`61 → 63.5`), so typed values and imported data are fine as-is.
- `ExerciseEntryRows`' header is a `Button` with `.tint(.primary)`: on iOS 26 the default button style tints its label with the accent, and hierarchical `.primary`/`.secondary` inside then resolve against *that* — so without the tint override the whole row went blue. (`SetRow`/`PlanExerciseRow` are `DisclosureGroup`s and don't need it.)
- **Two hero steppers share a phone-width row**, and four 44-pt buttons already take most of it. The number is `.title2` (not `.title`) with a 36-pt minimum and each stepper sizes to its content, which is what lets a 5-glyph weight ("120.5") sit beside a 1-digit rep count. Don't decide that layout with `ViewThatFits` — it judges by *ideal* width and ignores the number's `minimumScaleFactor`, so wide values silently fell into the stacked fallback; the rows stack only on `dynamicTypeSize.isAccessibilitySize`.

For an `Int?`/`Double?` model field (`UserProfile.age`/`heightCm`/`weightKg`), bind through a computed `Binding` with a fallback default (e.g. `profile.age ?? 25`) and seed the real default into the model `onAppear` — see `SettingsView` — so the stepper's initial display never silently disagrees with the (still-`nil`) persisted value.

### Sets, logged exercises, and plan-day slots are all collapsible, accordion-style — same pattern, same look

Sets are edited **inline on the session screen** — there is no separate set-editor sheet. `DayDetailView` renders one `ExerciseEntryRows` per `ExerciseEntry` inside a single `Section("Exercises")`; each produces a header row and, while expanded, one `SetRow` per set (a nested `ForEach` with `.onDelete`, so swipe-to-delete works per set), an "Add Set / Add Drop Set" row (two `.borderless` buttons; seeds the new set and expands it) and a "Last time" footnote.

**`SetRow` and `PlanExerciseRow` are `DisclosureGroup`s.** The label is the one-line summary; the content (the two `NumberStepper`s) becomes the group's child row, so the expand/collapse motion, chevron and row insertion are the platform's own — the same as subtasks in Reminders. This replaced a hand-rolled header `Button` + `if isExpanded { … }`: a List row's height closes faster than SwiftUI's removal transition runs, so the steppers' labels lingered over the next row on collapse (a `.move` transition slid them over the header instead, and an instant `.identity` removal made the whole thing a snap). Don't go back to a custom accordion for these rows; if you need something the group can't express, that's the signal to reconsider the design, not to re-animate it. The child row carries `.deleteDisabled(true)` (and `.moveDisabled(true)` in the plan-slot case) so a swipe or drag on the steppers never acts on the set/slot. Exercise delete and History live on the header row's `.swipeActions`/`.contextMenu`; History is presented as a **sheet** (`historyExercise`) because `DayDetailView` is reachable from three different stacks and owns no `path` to push onto. Adding an exercise (`+` → `ExercisePickerView`) inserts the entry, prefills set 1, expands both the entry and that set, and scrolls the header into view (`ScrollViewReader` + `.id(entry.persistentModelID)`) — one modal, no second sheet.

`SetRow` (inside `ExerciseEntryRows`), `ExerciseEntryRows` (inside `DayDetailView`), and `PlanExerciseRow` (inside `PlanDayDetailView`) all take `isExpanded: Binding<Bool>` rather than owning their own `@State` (for the two `DisclosureGroup`s it's passed straight through as `isExpanded:`). Each parent holds a single `expanded…ID: PersistentIdentifier?` and hands every row a computed `Binding` that compares against it, so **only one row is ever expanded at a time** in any list. `DayDetailView` holds two such IDs — `expandedEntryID` (which exercise) and `expandedSetID` (which set, across the whole day) — and collapsing an exercise clears the set too. Everything starts collapsed except a just-added exercise's first set.

Visually, all of these are **plain rows inside one shared `Section`** — no per-row card background or hidden separators. The exercise header in `ExerciseEntryRows` is a `Button` (not `onTapGesture`) so it highlights on touch-down and carries the button trait for VoiceOver; see the `.tint(.primary)` note under NumberStepper. Keep any new expandable list in this style rather than reinventing a bespoke card look.

## Git

- Remote: `git@github.com:ManjithaWeerasooriya/PLog-IOS.git` (origin)
- Branch: `main`
- `xcuserdata/` is gitignored and untracked
- Commit message style: imperative subject line, bullet-point body for significant changes

---

## Known Issues / To-Do

- **Signing:** development team not configured — set in Xcode → Target → Signing & Capabilities before building to a device or submitting to TestFlight.
- **Deployment target:** currently `26.5` in the project-level build settings; the target-level override sets `17.0`. Unify to `17.0` in project-level settings when convenient.
- **Weight unit preference:** the app hardcodes `kg`; `UserProfile` also stores height in cm and weight in kg with no unit toggle. A kg/lbs (and cm/in) preference would need a `UserDefaults`-backed `@AppStorage` and threading it through `WeightFormatter`, `NumberStepper` ranges, and all display sites.
- **`ExerciseLibraryViewModel`** is wired for mutations (add/delete) but the library and picker views inline their own `@Query`-based filtering. Consolidate if the filter logic grows complex.
- **`BuildProject` may target a physical device instead of the simulator** depending on Xcode's currently-selected scheme destination, with no MCP tool to switch it. If a simulator install/launch doesn't reflect a change you just built, check `PLog.app/PLog.debug.dylib`'s mtime in DerivedData's `Debug-iphonesimulator` products dir before assuming the app is broken — it may just be stale. Fall back to `xcodebuild -project PLog.xcodeproj -scheme PLog -configuration Debug -destination "platform=iOS Simulator,id=<UDID>" -derivedDataPath <tmp> build` to force a simulator build.
