//
//  PlanDetailView.swift
//  PLog
//
//  Edit one plan: name, start/end lifecycle, the ordered list of day templates, and a link
//  into the day-by-day workout log, then the planned weekly sets per muscle group. Everything autosaves; nothing to confirm on back.
//

import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @State private var viewModel: WorkoutPlanViewModel

    @State private var showingAddDay = false
    @State private var confirmingEnd = false

    /// Context is passed in explicitly because `@Environment` isn't available during `init`.
    init(plan: WorkoutPlan, context: ModelContext) {
        _viewModel = State(initialValue: WorkoutPlanViewModel(plan: plan, context: context))
    }

    var body: some View {
        @Bindable var plan = viewModel.plan

        List {
            Section("Plan") {
                TextField("Plan name", text: $plan.name)
                    .font(.headline)
                TextField("Notes", text: $plan.notes, axis: .vertical)
                    .lineLimit(1...4)
            }

            Section {
                lifecycleButton
                NavigationLink(value: PlanRoute.log(viewModel.plan)) {
                    Label("Workout Log", systemImage: "calendar.day.timeline.left")
                }
            } footer: {
                Text(statusLine)
            }

            daysSection

            PlanWeeklySetsSection(plan: viewModel.plan)
        }
        .navigationTitle(plan.name.isEmpty ? "Plan" : plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddDay) {
            NameEntrySheet(title: "New Day", placeholder: "e.g. Push Day", confirmLabel: "Add") { name in
                viewModel.addDay(named: name)
            }
        }
        // `.alert` rather than `.confirmationDialog`: the latter renders (at least on this
        // iOS version) as a small anchored callout that latches onto an arbitrary ancestor
        // view instead of appearing near the button that triggered it. A centered alert has
        // no anchor to get wrong.
        .alert(
            "End this plan?",
            isPresented: $confirmingEnd
        ) {
            Button("End Plan", role: .destructive) { viewModel.end() }
        } message: {
            Text("Your logged workouts are kept. You can restart the plan later.")
        }
    }

    // MARK: - Sections

    /// e.g. "Active since Sep 16" / "Ran Sep 1 – Sep 16" / "Not started".
    private var statusLine: String {
        switch viewModel.plan.status {
        case .notStarted:
            return "Not started"
        case .active:
            return viewModel.plan.startedAt.map { "Active since \($0.shortDateLabel)" } ?? "Active"
        case .ended:
            guard let start = viewModel.plan.startedAt, let end = viewModel.plan.endedAt else { return "Ended" }
            return "Ran \(start.shortDateLabel) – \(end.shortDateLabel)"
        }
    }

    @ViewBuilder
    private var lifecycleButton: some View {
        switch viewModel.plan.status {
        case .notStarted:
            Button {
                withAnimation(.snappy) { viewModel.start() }
            } label: {
                Label("Start Plan", systemImage: "play.fill")
            }
        case .active:
            Button(role: .destructive) {
                confirmingEnd = true
            } label: {
                Label("End Plan", systemImage: "stop.fill")
                    .foregroundStyle(.red)
            }
        case .ended:
            Button {
                withAnimation(.snappy) { viewModel.start() }
            } label: {
                Label("Restart Plan", systemImage: "arrow.counterclockwise")
            }
        }
    }

    @ViewBuilder
    private var daysSection: some View {
        Section {
            ForEach(viewModel.days) { day in
                NavigationLink(value: day) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.name.isEmpty ? "Day" : day.name)
                        Text(exerciseSummary(for: day))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .onDelete(perform: viewModel.removeDays)
            .onMove(perform: moveDays)

            Button {
                showingAddDay = true
            } label: {
                Label("Add Day", systemImage: "plus.circle")
            }
        } header: {
            Text("Days")
        } footer: {
            if viewModel.days.isEmpty {
                Text("Add the days you rotate through, e.g. Push, Pull, Legs.")
            }
        }
    }

    private func moveDays(from source: IndexSet, to destination: Int) {
        var ordered = viewModel.days
        ordered.move(fromOffsets: source, toOffset: destination)
        viewModel.reorderDays(ordered)
    }

    /// "Bench Press · Overhead Press…", led by "2× a week ·" when the day repeats.
    private func exerciseSummary(for day: PlanDay) -> String {
        let names = day.orderedExercises.compactMap { $0.exercise?.name }
        let list = names.isEmpty ? "No exercises yet" : names.joined(separator: " · ")
        return day.timesPerWeek > 1 ? "\(day.timesPerWeek)× a week · \(list)" : list
    }
}

#Preview {
    NavigationStack {
        PlanDetailView(plan: SampleData.plan, context: SampleData.context)
    }
    .modelContainer(SampleData.container)
}
