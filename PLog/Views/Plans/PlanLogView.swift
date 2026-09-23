//
//  PlanLogView.swift
//  PLog
//
//  The log for a plan: every session logged against it, newest first, grouped by month.
//  Logging a new session stamps out the chosen day template and opens it for editing.
//

import SwiftUI
import SwiftData

struct PlanLogView: View {
    @State private var viewModel: WorkoutPlanViewModel

    /// The Plans tab's navigation path, so a freshly logged session can be pushed straight
    /// into its editor. (A local `navigationDestination(item:)` would shadow the root's
    /// `WorkoutDay` destination and break the value-based row links.)
    @Binding var path: NavigationPath

    /// All sessions, filtered to this plan's in `sessions`. `@Query` keeps the log live
    /// whether a session is logged here or from the Logs tab.
    @Query(sort: \WorkoutDay.date, order: .reverse) private var allDays: [WorkoutDay]

    init(plan: WorkoutPlan, context: ModelContext, path: Binding<NavigationPath>) {
        _viewModel = State(initialValue: WorkoutPlanViewModel(plan: plan, context: context))
        _path = path
    }

    var body: some View {
        Group {
            if viewModel.plan.status == .notStarted {
                notStartedState
            } else {
                logList
            }
        }
        .navigationTitle("Workout Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.plan.isActive {
                ToolbarItem(placement: .primaryAction) {
                    logMenu
                }
            }
        }
    }

    // MARK: - Subviews

    private var logList: some View {
        List {
            if viewModel.plan.isActive, let next = viewModel.suggestedNextDay {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.name.isEmpty ? "Day" : next.name)
                                .font(.headline)
                            Text("\(next.exercises.count) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Log") { log(next) }
                            .buttonStyle(.borderedProminent)
                            .disabled(todaysSession != nil)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Up Next")
                } footer: {
                    if todaysSession != nil {
                        Text("Only one workout can be logged per day. Delete today's workout to log a different one.")
                    }
                }
            }

            if sections.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Workouts Yet", systemImage: "figure.strengthtraining.traditional")
                    } description: {
                        Text("Sessions you log against this plan show up here.")
                    }
                }
            }

            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.items) { workout in
                        NavigationLink(value: workout) {
                            WorkoutDayRow(day: workout)
                        }
                    }
                }
            }
        }
    }

    private var logMenu: some View {
        Menu {
            ForEach(viewModel.days) { day in
                Button(day.name.isEmpty ? "Day" : day.name) { log(day) }
            }
        } label: {
            Label("Log Workout", systemImage: "plus")
        }
        .disabled(viewModel.days.isEmpty || todaysSession != nil)
    }

    private var notStartedState: some View {
        ContentUnavailableView {
            Label("Plan Not Started", systemImage: "play.circle")
        } description: {
            Text("Start the plan to begin logging days against it.")
        } actions: {
            Button("Start Plan") {
                withAnimation(.snappy) { viewModel.start() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Sessions

    private struct LogSection {
        let title: String
        let items: [WorkoutDay]
    }

    /// Sessions stamped from one of this plan's days, newest first (`allDays` is already
    /// sorted that way).
    private var sessions: [WorkoutDay] {
        allDays.filter { $0.planDay?.plan === viewModel.plan }
    }

    /// Today's session, if one is already logged (against any plan, or blank) — only one
    /// workout can be logged per day, so both log actions here are disabled while it exists.
    private var todaysSession: WorkoutDay? {
        allDays.first { Calendar.current.isDateInToday($0.date) }
    }

    /// Month sections in newest-first order, built sequentially so ordering is preserved.
    private var sections: [LogSection] {
        var result: [LogSection] = []
        for item in sessions {
            let title = item.date.formatted(.dateTime.month(.wide).year())
            if let last = result.indices.last, result[last].title == title {
                result[last] = LogSection(title: title, items: result[last].items + [item])
            } else {
                result.append(LogSection(title: title, items: [item]))
            }
        }
        return result
    }

    // MARK: - Actions

    private func log(_ day: PlanDay) {
        path.append(viewModel.logWorkout(for: day))
    }
}

#Preview {
    struct Demo: View {
        @State private var path = NavigationPath()
        var body: some View {
            NavigationStack(path: $path) {
                PlanLogView(plan: SampleData.plan, context: SampleData.context, path: $path)
                    .navigationDestination(for: WorkoutDay.self) { day in
                        DayDetailView(day: day)
                    }
            }
        }
    }
    return Demo()
        .modelContainer(SampleData.container)
}
