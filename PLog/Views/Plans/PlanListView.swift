//
//  PlanListView.swift
//  PLog
//
//  The Plans tab: the currently active plan on top, every other plan below. Tap "+" to name
//  a new plan and jump straight into editing it. Owns the tab's `NavigationStack` and
//  registers every destination reachable from it (plans, day templates, logged sessions,
//  the plan log).
//

import SwiftUI
import SwiftData

/// Non-model screens reachable in the Plans stack. Everything is pushed by value so that
/// value-based links keep working from any depth (a view-builder `NavigationLink` would
/// leave its destination outside the path and break `NavigationLink(value:)` inside it).
enum PlanRoute: Hashable {
    case log(WorkoutPlan)
    /// Planned sets per muscle group per week, with steppers to adjust them.
    case weeklySets(WorkoutPlan)
}

struct PlanListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \WorkoutPlan.createdAt, order: .reverse) private var plans: [WorkoutPlan]

    /// Mixed-type path: plans, day templates, logged sessions and `PlanRoute`s all push onto
    /// it. Push everything by value — see AGENT.md. "+" uses it to open a new plan directly.
    @State private var path = NavigationPath()

    /// Plans staged for deletion, pending the confirmation dialog below.
    @State private var pendingDeletePlans: [WorkoutPlan] = []
    @State private var showingDeleteConfirmation = false
    /// Shown instead of the confirmation dialog when a swipe targets the active plan.
    @State private var showingActivePlanBlockedAlert = false
    @State private var showingNewPlan = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if plans.isEmpty {
                    emptyState
                } else {
                    planList
                }
            }
            .navigationTitle("Plans")
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanDetailView(plan: plan, context: context)
            }
            .navigationDestination(for: PlanDay.self) { day in
                PlanDayDetailView(day: day)
            }
            .navigationDestination(for: WorkoutDay.self) { day in
                DayDetailView(day: day)
            }
            .navigationDestination(for: PlanRoute.self) { route in
                switch route {
                case .log(let plan):
                    PlanLogView(plan: plan, context: context, path: $path)
                case .weeklySets(let plan):
                    PlanWeeklySetsView(plan: plan)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewPlan = true
                    } label: {
                        Label("New Plan", systemImage: "plus")
                    }
                }
            }
            // Name first, insert on confirm: backing out of the sheet leaves nothing behind.
            .sheet(isPresented: $showingNewPlan) {
                NameEntrySheet(title: "New Plan", placeholder: "e.g. Push / Pull / Legs", onConfirm: createPlan)
            }
            // `.alert` rather than `.confirmationDialog`: the latter renders (at least on
            // this iOS version) as a small anchored callout that latches onto an arbitrary
            // ancestor view instead of the swiped row, landing near the top of the list and
            // pointing at the wrong plan entirely. A centered alert has no anchor to get wrong.
            .alert(
                deleteConfirmationTitle,
                isPresented: $showingDeleteConfirmation
            ) {
                Button("Delete", role: .destructive, action: confirmDelete)
                Button("Cancel", role: .cancel) { pendingDeletePlans = [] }
            } message: {
                Text("This removes its day templates. Workouts you've already logged are kept.")
            }
            .alert("Can't Delete an Active Plan", isPresented: $showingActivePlanBlockedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("End the plan before deleting it.")
            }
        }
    }

    // MARK: - Subviews

    private var planList: some View {
        List {
            if !activePlans.isEmpty {
                Section("Active") {
                    ForEach(activePlans) { plan in
                        NavigationLink(value: plan) {
                            WorkoutPlanRow(plan: plan)
                        }
                        .swipeActions(edge: .leading) {
                            duplicateButton(for: plan)
                        }
                    }
                    .onDelete { offsets in requestDelete(from: activePlans, at: offsets) }
                }
            }
            if !otherPlans.isEmpty {
                Section(activePlans.isEmpty ? "All Plans" : "Other Plans") {
                    ForEach(otherPlans) { plan in
                        NavigationLink(value: plan) {
                            WorkoutPlanRow(plan: plan)
                        }
                        .swipeActions(edge: .leading) {
                            duplicateButton(for: plan)
                        }
                    }
                    .onDelete { offsets in requestDelete(from: otherPlans, at: offsets) }
                }
            }
        }
    }

    private func duplicateButton(for plan: WorkoutPlan) -> some View {
        Button {
            duplicate(plan)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        .tint(.indigo)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Plans Yet", systemImage: "list.clipboard")
        } description: {
            Text("Build a plan of days like Push, Pull and Legs, then start it to log against it.")
        } actions: {
            Button("Create a Plan") { showingNewPlan = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Grouping

    private var activePlans: [WorkoutPlan] { plans.filter(\.isActive) }
    private var otherPlans: [WorkoutPlan] { plans.filter { !$0.isActive } }

    // MARK: - Actions

    private func createPlan(named name: String) {
        let plan = WorkoutPlan(name: name)
        context.insert(plan)
        try? context.save()
        path.append(plan)
    }

    /// Copies the plan's days and exercise slots into a new, inactive plan; stays on the
    /// list so the user can see it land in "Other Plans" rather than jumping away.
    private func duplicate(_ plan: WorkoutPlan) {
        WorkoutPlanViewModel.duplicate(plan, in: context)
    }

    /// Stages the swiped plans for deletion, unless one of them is currently active — an
    /// active plan must be ended first so it can't be lost mid-program by accident.
    private func requestDelete(from sectionPlans: [WorkoutPlan], at offsets: IndexSet) {
        let targeted = offsets.map { sectionPlans[$0] }
        guard !targeted.contains(where: \.isActive) else {
            showingActivePlanBlockedAlert = true
            return
        }
        pendingDeletePlans = targeted
        showingDeleteConfirmation = true
    }

    private func confirmDelete() {
        for plan in pendingDeletePlans {
            context.delete(plan)
        }
        pendingDeletePlans = []
        try? context.save()
    }

    private var deleteConfirmationTitle: String {
        if pendingDeletePlans.count == 1 {
            let name = pendingDeletePlans[0].name
            return "Delete “\(name.isEmpty ? "Plan" : name)”?"
        }
        return "Delete \(pendingDeletePlans.count) Plans?"
    }
}

#Preview {
    PlanListView()
        .modelContainer(SampleData.container)
}
