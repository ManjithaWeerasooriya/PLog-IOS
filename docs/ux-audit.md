# PLog UX audit, research and scope

Written on the `ux-overhaul` branch, November 2026. Evidence: the app run on an iPhone 17
simulator (iOS 26.5) from a fresh install and again with two years of generated history,
plus a read of the source. Nothing here was checked on a physical device.

The goal was fixed in advance: better for bodybuilding, more appealing to a new user, still
simple. Each finding below is judged against that, and against the decisions already
recorded in `AGENT.md` (no set "completed" flag, no back-button guard, no list-based
dashboard editor, `.alert` for destructive actions, and so on). None of those are reopened.

## 1. Audit

### What already works

- The Train tab opens on one action. A plan day is stamped with its exercises and sets, so
  logging is adjusting numbers rather than building a workout.
- Set *n* is graded against set *n* last time by estimated 1RM, so trading weight for reps
  isn't painted red.
- Weekly sets per muscle group, planned and done, against a 10–30 target. This is the core
  of evidence-based volume tracking and few apps show it this plainly.
- Platform conformance is high: system navigation, sheets, swipe actions, context menus,
  SF Symbols, semantic colours, Dynamic Type handling with deliberate exceptions.
- Performance work is already serious (cached `SessionRecord`s, stats built outside `body`).

### Technical audit (scored from source and the simulator)

| # | Dimension | Score | Key finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | 3 | Pills and steppers are labelled; the set row, hero card and charts are not, and only `NumberStepper` honours Reduce Motion |
| 2 | Performance | 4 | Stats are cached and built off `body`; nothing new found |
| 3 | Appearance & theming | 4 | Semantic colours throughout; light and dark both first-class |
| 4 | Platform conformance | 4 | Reads as a native app on every screen |
| 5 | Adaptivity | 3 | iPhone portrait is solid; landscape and iPad were not examined |
| | **Total** | **18/20** | Excellent. The gaps are in product, not in craft |

### Gaps, by severity

**P1: things that get in a lifter's way**

1. **Kilograms only.** Every weight is labelled "kg" and steps by 2.5. A lifter who trains
   in pounds has no honest way to use the app. This is the largest single limit on who the
   app is useful to. (Already listed under Known Issues in `AGENT.md`.)
2. **The first session is all zeros.** A new plan day opens as "0 kg × 8" on every set.
   Bench at 60 kg is 24 taps per set, four times over, because a weight entered on set 1
   isn't carried to sets 2–4.
3. **Untouched sets are painted red.** With history, a stamped set that still reads 0 kg
   shows a red "regressed" arrow before it has been done. `AGENT.md` already says a wrong
   red teaches people to ignore red.
4. **Bodyweight exercises never show progress.** Pull-ups, planks and leg raises are logged
   at 0 kg, so their estimated 1RM is 0 and the trend is always "none", whatever the reps.
5. **No rest timer.** Rest between sets is part of the training variable set, and a timer
   is the feature lifters most expect from a log.
6. **Last time's numbers are one line at the bottom.** Only the previous top set is shown,
   under the last set. What set 3 was last time, and what would beat it, isn't on screen
   while editing set 3.

**P2: things that make the app less useful for bodybuilding**

7. **The starter plan fails the app's own target.** Push / Pull / Legs is seeded at once a
   week per day (three days), which lands 11 of 13 muscle groups "below" target on the
   plan's own Weekly Sets card. A new user's first impression of the volume feature is a
   wall of orange.
8. **Everyone gets the same plan.** PPL is seeded active whether the user trains three
   days or six. There is no choice and no other ready-made program to start from.
9. **Twenty exercises.** No pull-up, dip, hack squat, leg extension, hip thrust, preacher
   curl, skull crusher, pec deck or rear-delt fly. Building a real bodybuilding plan means
   typing the library in by hand.
10. **No all-time record.** A set is compared with last time only. Beating a lifetime best
    passes without a mark.
11. **Effort isn't recorded.** `SetEntry.rpe` exists and is backed up, but nothing reads or
    writes it. Proximity to failure is the other half of "was that a productive set".
12. **Body weight is one number.** Settings holds a single value and the Body Weight card
    repeats it ("From your profile"). There is no history, so a bulk or a cut can't be seen.
    Opening Settings also writes a made-up 70 kg into the profile.
13. **Exercise notes are invisible while training.** Form cues and machine settings can be
    saved on an exercise but appear nowhere on the session screen.

**P2: things a new user meets**

14. **"Logged today" reads as a rule.** After starting a workout the Train card says "Only
    one workout can be logged per day. Delete this one to log a different workout today."
    That is the app's limitation, stated where the user's session should be.
15. **Progress is blank until the first workout.** "No Analytics Yet" and an edit pencil
    that edits nothing.
16. **Eyebrow labels on the Train card** ("UP NEXT · PUSH / PULL / LEGS") sit above a
    heading that could carry the information itself.

**P3: hardening**

17. `PLogApp` calls `fatalError` if the store can't be opened: a crash on every launch
    with no explanation and no way to act.
18. `DataBackup.restore` deletes everything, then inserts. If it throws partway, the
    context is left half-replaced with no rollback.
19. Imported values aren't range-checked (negative reps or weights restore as they are).
20. VoiceOver: a set row reads as separate fragments; the hero card's summary and the
    session row are fine. Charts have no summary.

## 2. Research

Searched November 2026. Most of what search returns on this subject is vendor blogs, so
each point says how strong its support is. Where a point rests on secondary coverage of a
paper rather than the paper, it says so.

### Training science

- **Volume drives growth, with diminishing returns.** Pelland et al., *The Resistance
  Training Dose Response* (Sports Medicine, 2025; preprint on SportRxiv), is the current
  reference meta-regression. Reported findings: more weekly sets, more hypertrophy, at a
  falling rate; counting indirect work as a fraction of a set fits the data better than
  counting it fully or not at all. *Read from abstracts and secondary summaries, not the
  full text.* PLog already counts secondary muscles as half a set, which is that method.
- **Frequency matters mostly through volume.** The same paper reports no clear growth
  benefit from training a muscle more often once volume is equal. Practical guides still
  favour twice a week because it makes 10+ quality sets easier to fit. *Secondary.*
- **Proximity to failure.** Robinson, Pelland et al. (2024 meta-regression) report that
  hypertrophy tends to improve as sets end closer to failure, while strength gains are
  similar across a wide range of reps in reserve; Refalo et al. (2023) and Grgic et al.
  (2022) found no significant overall difference between failure and non-failure training.
  The consistent reading is "close to failure, not necessarily to it". *Secondary.*
- **Rest.** Singer et al. (2024, Frontiers in Sports and Active Living, Bayesian
  meta-analysis) found a small benefit to resting more than 60 seconds between sets and no
  appreciable difference beyond 90 seconds. *Primary source located; abstract-level.*
- **Progression.** Evidence-based apps and guides (Alpha Progression, RippedBody) centre on
  double progression: add reps within a range, then add load. *Practice, not a trial.*
- Lengthened partials: the searches returned nothing usable. Not acted on.

### What lifters want from an app

Direct survey data wasn't found; the following recurs across review round-ups and
app-store analyses, most of them written by competing vendors. Treat as weak signal.

- Logging in as few taps as possible, with last time's numbers visible where the set is
  edited, without extra taps or scrolling.
- A rest timer, ideally starting on its own.
- Templates and ready-made programs.
- RIR/RPE as a per-set field (several apps put it behind a paywall).
- Clear progress history and data export.
- The most repeated complaint is not a missing feature but clutter: "too much stuff I
  don't need".
- On onboarding, the same sources agree on one thing: long questionnaires lose people
  before they reach any value.

Sources:
- https://sportrxiv.org/index.php/server/preprint/view/537
- https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2024.1429789/pdf
- https://rippedbody.com/progression/
- https://alphaprogression.com/en/blog/best-progressive-overload-apps
- https://www.boostcamp.app/best/rpe-rir
- https://setgraph.app/ai-blog/workout-tracker-app-reddit
- https://www.jefit.com/blog/best-workout-apps-for-2026-top-7-options-tested-and-reviewed
- https://sahha.ai/blog/health-app-churn-retention/

## 3. Scope chosen

The rule for inclusion: it removes friction from logging, or it answers a question the
research says a bodybuilder asks, and it can be ignored by someone who doesn't want it.

**Build**

| # | Change | Answers |
|---|--------|---------|
| A | Weight unit, kg or lb: chosen from the device region on a fresh install, changeable in Settings, with the option to convert logged weights | Gap 1 |
| B | Faster logging: a weight typed into a set fills the untouched sets after it; each open set shows that set last time and the smallest step that beats it | Gaps 2, 6 |
| C | Honest trend badges: an untouched set shows nothing; bodyweight sets are graded on reps | Gaps 3, 4 |
| D | Personal records: a mark on a set that beats the exercise's all-time best | Gap 10 |
| E | Rest timer on the session screen, one tap, with presets | Gap 5, rest research |
| F | A larger starter library and ready-made programs that each meet the weekly-set target, offered once on first launch and from the Plans tab | Gaps 7, 8, 9 |
| G | Reps in reserve per set, off unless switched on in Settings | Gap 11, failure research |
| H | Body-weight log with a trend | Gap 12 |
| I | Exercise notes shown while training; a session summary instead of a rule on the Train card; no eyebrow labels | Gaps 13, 14, 16 |
| J | Hardening: no crash when the store won't open, an import that can't be left half-done, imported values clamped, VoiceOver labels on set rows | Gaps 17–20 |

**Not building, and why**

- A set "done" tick. Recorded in `AGENT.md` as tried and removed. The rest timer is
  started by hand instead of by ticking a set.
- Automatic weight progression, mesocycles, deload scheduling. They need rep-range targets
  on plan slots and a model of fatigue; each is a feature the size of this whole pass, and
  they add decisions to every screen.
- Warm-up sets, plate calculator, exercise videos, social features, Apple Health, Apple
  Watch. Real requests, but each is either a new surface or a new permission.
- Rep ranges on plan slots (8–12 rather than 8). Wanted for double progression; it changes
  the plan model, the stamping logic and the backup format. Left for a pass of its own.
- A sample dashboard on the empty Progress tab (gap 15). The empty state's copy is
  improved; a full preview dashboard was judged to be decoration.

## 4. Outcome

Everything in the Build table was built. What changed against the plan while building:

- **Restore doesn't roll back; it can't be left half-done instead.** The plan was to call
  `context.rollback()` if an import failed. A test of exactly that crashed inside SwiftData
  ("Unexpected backing data for snapshot creation"): rollback traps when the context holds
  cascade-deleted rows that were never faulted in, which an import always does. The import
  now reads everything that can fail before its first change, and the replace itself can't
  throw. Unit conversion keeps the original values and puts them back by hand on failure.
- **The set editor became three rows.** As one stacked row, a hint that wrapped to two lines
  squeezed the weight stepper and its number shrank. Found in the simulator, not in review.
- **The rest timer stops growing at the first accessibility text size.** At the largest size
  it covered the sets beneath it.
- **Gap 15** (blank Progress tab) got better copy only, as planned.

### Interaction details reviewed

| Before | After | Why |
| --- | --- | --- |
| PR badge would appear with no transition | Fades in from 85% scale over 0.2 s; fade only under Reduce Motion | Nothing should appear from nothing, and a record is rare enough to earn a moment |
| Rest capsule swapped idle and running states instantly | 0.25 s snappy change with a light impact | A state change the user caused should be felt and seen |
| Countdown digits would jump each second | Numeric content transition counting down, driven by a one-second `TimelineView` | Reads as one number changing; nothing else on the screen redraws |
| Welcome program choice had no feedback beyond the checkmark | Selection haptic on change | Confirms the tap on a screen the user sees once |
| "Different day" and "Log a Blank Workout" were text-height targets | 44 pt tall, full card width | Minimum touch target |
| Program rows inherited the accent tint on iOS 26 | `.tint(.primary)`, accent only on the icon | Colour marks what's interactive, not every word of the label |
| Hint text shared a row with the steppers | Its own row, in two lines | Wrapping text was resizing a control |

No animation was added to anything a lifter does dozens of times a session (stepping a
weight, opening a set, adding a set); those keep the platform's own motion.

### Verified, and not

Run on an iPhone 17 simulator, iOS 26.5:

- Fresh install with a US region: welcome sheet, pounds preselected, program started, first
  session opened, a held stepper filled all four sets.
- Fresh install elsewhere: kilograms; Skip leads to the "No plan yet" card.
- This build installed over a store written by the previous one (416 sessions, the old
  seeded plans): data intact, no welcome sheet, unit kg.
- With two years of generated history: trend badges, the PR mark, the hint, reps in
  reserve, the rest timer through a full one-minute countdown, converting kg to lb, the
  body-weight log and its card, the Programs sheet and the weekly sets of an installed
  program (Push / Pull / Legs: 11 groups on target, 2 below).
- Dark appearance and the largest accessibility text size on the Train card, the session
  screen, the set editor and the welcome sheet.
- 50 unit tests pass.

Not verified: anything on a physical device; haptics; the rest-timer notification actually
arriving (only that it's scheduled behind the Settings switch); VoiceOver by ear (labels
were set in code and not listened to); iPad and landscape; iOS 17 and 18 (the deployment
target is 17.6 but only 26.5 was run); the store-won't-open screen (no way to make the
store fail on demand was built); file export and import through the system pickers (the
round trip is covered by tests, not by hand).
