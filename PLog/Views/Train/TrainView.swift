//
//  TrainView.swift
//  PLog
//
//  The Train tab: today's action first (the hero card — start the plan's next day, or a
//  blank workout), then every logged session, newest first, grouped by month. Tap a session
//  to view/edit it. Settings is a sheet behind the profile button.
//

import SwiftUI
import SwiftData

struct TrainView: View {
    @Environment(\.modelContext) private var context

    /// All logged sessions, newest first. `@Query` keeps this list live as data changes.
    @Query(sort: \WorkoutDay.date, order: .reverse) private var days: [WorkoutDay]

    /// At most one plan is active at a time (starting one ends the others), so `first` is safe.
    @Query private var plans: [WorkoutPlan]

    /// Navigation path so we can push a freshly-created session straight into its detail screen.
    @State private var path: [WorkoutDay] = []
    @State private var showingSettings = false

    private var activePlan: WorkoutPlan? {
        plans.first(where: \.isActive)
    }

    /// The active plan, only if it actually has days to log against.
    private var loggablePlan: WorkoutPlan? {
        guard let plan = activePlan, !plan.days.isEmpty else { return nil }
        return plan
    }

    /// Today's session, if one is already logged — only one workout can be logged per day.
    private var todaysSession: WorkoutDay? {
        days.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // The card is its own row on the grouped background; with nothing logged yet
                // it also carries the empty-state line, since the card *is* the action.
                Section {
                    TrainHeroCard(
                        plan: loggablePlan,
                        todaysSession: todaysSession,
                        onLog: log,
                        onBlankWorkout: startBlankWorkout,
                        onOpenToday: { path.append($0) }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    if days.isEmpty {
                        Text("Your sessions will appear here.")
                            .frame(maxWidth: .infinity)
                    }
                }

                sessionSections
            }
            .navigationTitle("Train")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "person.crop.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(for: WorkoutDay.self) { day in
                DayDetailView(day: day)
            }
            // A light tap when a session is created from the card and pushed.
            .sensoryFeedback(.impact(flexibility: .soft), trigger: path.count) { old, new in new > old }
        }
    }

    // MARK: - Sessions

    private var sessionSections: some View {
        ForEach(groupedDays, id: \.title) { section in
            Section(section.title) {
                ForEach(section.days) { day in
                    NavigationLink(value: day) {
                        WorkoutDayRow(day: day)
                    }
                }
                .onDelete { offsets in
                    delete(from: section.days, at: offsets)
                }
            }
        }
    }

    private struct DaySection {
        let title: String
        let days: [WorkoutDay]
    }

    /// Groups sessions into month sections (e.g. "September 2026"), preserving newest-first order.
    private var groupedDays: [DaySection] {
        let groups = Dictionary(grouping: days) { day in
            day.date.formatted(.dateTime.month(.wide).year())
        }
        return groups
            .map { DaySection(title: $0.key, days: $0.value.sorted { $0.date > $1.date }) }
            .sorted { ($0.days.first?.date ?? .distantPast) > ($1.days.first?.date ?? .distantPast) }
    }

    // MARK: - Actions

    /// Stamps the plan day's template into a new session and opens it.
    private func log(_ planDay: PlanDay) {
        let day = WorkoutLogger.logWorkout(for: planDay, in: context)
        path.append(day)
    }

    private func startBlankWorkout() {
        let day = WorkoutDay(date: .now, name: "New Workout")
        context.insert(day)
        try? context.save()
        path.append(day)
    }

    private func delete(from sectionDays: [WorkoutDay], at offsets: IndexSet) {
        for index in offsets {
            context.delete(sectionDays[index])
        }
        try? context.save()
    }
}

#Preview {
    TrainView()
        .modelContainer(SampleData.container)
}
