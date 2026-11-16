//
//  TrainHeroCard.swift
//  PLog
//
//  The first thing on the Train tab: what to do today. With an active plan it names the
//  suggested next day and offers one prominent "Start …" button, with the other days and a
//  blank workout behind a secondary menu. With no plan it offers the ready-made programs
//  first and a blank workout second. Once today's session exists it becomes the way back
//  into it. The daily action lives on-screen, not behind a toolbar menu.
//

import SwiftUI
import SwiftData

struct TrainHeroCard: View {
    /// The active plan, only if it has days to log against; `nil` shows the no-plan state.
    let plan: WorkoutPlan?
    /// Today's session, if one is already logged — only one workout can be logged per day,
    /// so this replaces the "Start …" actions with a way back into it instead.
    let todaysSession: WorkoutDay?
    var onLog: (PlanDay) -> Void
    var onBlankWorkout: () -> Void
    var onOpenToday: (WorkoutDay) -> Void
    /// Opens the ready-made programs, from the no-plan state.
    var onChooseProgram: () -> Void = {}

    var body: some View {
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                if let todaysSession {
                    loggedTodayContent(todaysSession)
                } else if let plan, let next = WorkoutLogger.suggestedNextDay(in: plan) {
                    planContent(plan: plan, next: next)
                } else {
                    noPlanContent
                }
            }
        }
    }

    // MARK: - Already logged today

    /// The session itself — what it is and how much is in it — with the way back in. The
    /// one-a-day rule is a footnote: it used to be the card's whole message.
    @ViewBuilder
    private func loggedTodayContent(_ session: WorkoutDay) -> some View {
        heading(
            session.name.isEmpty ? "Today's Workout" : session.name,
            detail: "Today · \(Self.countSummary(exercises: session.entries.count, sets: session.entries.reduce(0) { $0 + $1.workingSets.count }))"
        )

        Button {
            onOpenToday(session)
        } label: {
            Text("Continue Workout")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Text("One workout a day. To log a different one today, delete this one first.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    // MARK: - Active plan

    @ViewBuilder
    private func planContent(plan: WorkoutPlan, next: PlanDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            heading(
                next.name.isEmpty ? "Day" : next.name,
                detail: "Next in \(plan.name.isEmpty ? "your plan" : plan.name) · \(Self.countSummary(exercises: next.exercises.count, sets: next.exercises.reduce(0) { $0 + $1.targetSets }))"
            )
            Text(exerciseSummary(for: next))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }

        Button {
            onLog(next)
        } label: {
            Text("Start \(next.name.isEmpty ? "Workout" : next.name)")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Menu {
            Section(plan.name.isEmpty ? "Plan" : plan.name) {
                ForEach(plan.orderedDays) { day in
                    if day !== next {
                        Button(day.name.isEmpty ? "Day" : day.name) { onLog(day) }
                    }
                }
            }
            Button(action: onBlankWorkout) {
                Label("Blank Workout", systemImage: "square.dashed")
            }
        } label: {
            Label("Different day", systemImage: "chevron.down")
                .labelStyle(.titleAndIconTrailing)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 32)
                .contentShape(Rectangle())
        }
    }

    // MARK: - No plan

    @ViewBuilder
    private var noPlanContent: some View {
        heading(
            "No plan yet",
            detail: "A plan fills in each workout for you: the exercises, the sets, and the weights you used last time."
        )

        Button(action: onChooseProgram) {
            Text("Choose a Program")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Button(action: onBlankWorkout) {
            Text("Log a Blank Workout")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Helpers

    /// The card's title with one line of context under it.
    private func heading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "5 exercises · 16 sets".
    static func countSummary(exercises: Int, sets: Int) -> String {
        guard exercises > 0 else { return "No exercises yet" }
        return "\(exercises) \(exercises == 1 ? "exercise" : "exercises") · \(sets) \(sets == 1 ? "set" : "sets")"
    }

    /// e.g. "Bench Press · Overhead Press · Lateral Raise".
    private func exerciseSummary(for day: PlanDay) -> String {
        day.orderedExercises.compactMap { $0.exercise?.name }.joined(separator: " · ")
    }
}

/// Icon after the title, for a "Different day ⌄" style menu label.
private struct TitleAndIconTrailingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
                .font(.caption.weight(.semibold))
        }
    }
}

private extension LabelStyle where Self == TitleAndIconTrailingLabelStyle {
    static var titleAndIconTrailing: TitleAndIconTrailingLabelStyle { .init() }
}

#Preview("Active plan") {
    List {
        Section {
            TrainHeroCard(
                plan: SampleData.plan,
                todaysSession: nil,
                onLog: { _ in },
                onBlankWorkout: {},
                onOpenToday: { _ in }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    .modelContainer(SampleData.container)
}

#Preview("No plan") {
    List {
        Section {
            TrainHeroCard(
                plan: nil,
                todaysSession: nil,
                onLog: { _ in },
                onBlankWorkout: {},
                onOpenToday: { _ in }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
}

#Preview("Logged today") {
    List {
        Section {
            TrainHeroCard(
                plan: SampleData.plan,
                todaysSession: SampleData.recentDay,
                onLog: { _ in },
                onBlankWorkout: {},
                onOpenToday: { _ in }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }
    .modelContainer(SampleData.container)
}
