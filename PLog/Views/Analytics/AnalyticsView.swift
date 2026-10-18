//
//  AnalyticsView.swift
//  PLog
//
//  The Progress tab (the type keeps its old name — `ProgressView` is SwiftUI's): a 4-column
//  grid of small (2×2), wide (4×2) and large (4×4) widgets the user adds, removes, resizes and
//  reorders in place, the Control Center way. The pencil hides the navigation and tab bars
//  and puts the cards themselves into edit mode: a ⊖ badge on each,
//  long-press-and-drag to reorder (the others reflow live), and a fixed bar with ＋ (the
//  `AddWidgetGallery` of live previews) and Done. The layout is the `Dashboard` row; each
//  card is a `DashboardWidgetView` over one `DashboardData` built from this view's queries.
//  Activity pushes the calendar and Best Lifts pushes `BestLiftsView`.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Non-model screens reachable from the Progress stack.
enum ProgressRoute: Hashable {
    case calendar
    case bestLifts
}

/// One grid row: a full-width widget, or one or two small ones (see `DashboardLayout`).
private struct DashboardRow: Identifiable {
    let widgets: [DashboardWidget]
    var id: PersistentIdentifier? { widgets.first?.persistentModelID }
}

struct AnalyticsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \WorkoutDay.date, order: .reverse) private var workouts: [WorkoutDay]
    @Query private var plans: [WorkoutPlan]
    @Query private var profiles: [UserProfile]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var dashboards: [Dashboard]

    @State private var isEditing = false
    @State private var showingAddWidget = false
    /// An Exercise Progress widget whose exercise is being changed from its context menu.
    @State private var widgetChangingExercise: DashboardWidget?
    /// The widget being dragged in edit mode; the drop delegates move it as it passes others.
    @State private var draggedWidget: DashboardWidget?
    /// Bumped on every removal, to drive the haptic.
    @State private var removals = 0

    @ScaledMetric(relativeTo: .body) private var badgeSize = 26

    var body: some View {
        NavigationStack {
            content
                // Under the bars too (and as the navigation bar's own fill), so nothing white
                // shows while the bars slide away and back.
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
                .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
                .navigationTitle("Progress")
                // Edit mode hides both bars and shows its own ＋ / Done. `setEditing` animates
                // the change, so the tab bar slides away and back.
                .toolbar(isEditing ? .hidden : .visible, for: .navigationBar)
                .toolbar(isEditing ? .hidden : .visible, for: .tabBar)
                // Never leave the tab bar hidden behind: leaving the tab (or anything that
                // takes this screen away) ends editing.
                .onDisappear { if isEditing { setEditing(false) } }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { setEditing(true) } label: {
                            Label("Edit Dashboard", systemImage: "pencil")
                        }
                        .disabled(dashboard == nil)
                    }
                }
                // Outside the ScrollView, so it stays put while the cards scroll beneath it.
                .safeAreaInset(edge: .top, spacing: 0) {
                    if isEditing { editBar }
                }
                .sheet(isPresented: $showingAddWidget) {
                    AddWidgetGallery(data: data, canAdd: { viewModel?.canAdd($0) ?? false }) { kind, exercise in
                        withAnimation(.snappy) { viewModel?.add(kind, exercise: exercise) }
                    }
                }
                .sheet(item: $widgetChangingExercise) { widget in
                    ExercisePickerView { exercise in
                        viewModel?.setExercise(exercise, for: widget)
                    }
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: removals)
                .sensoryFeedback(.impact(weight: .light), trigger: draggedWidget?.persistentModelID) { _, new in
                    new != nil
                }
                .navigationDestination(for: Exercise.self) { exercise in
                    ExerciseHistoryView(exercise: exercise)
                }
                .navigationDestination(for: ProgressRoute.self) { route in
                    switch route {
                    case .calendar:
                        CalendarView()
                    case .bestLifts:
                        BestLiftsView()
                    }
                }
                // The calendar's session rows push through this stack.
                .navigationDestination(for: WorkoutDay.self) { day in
                    DayDetailView(day: day)
                }
        }
    }

    /// One branch for the grid in both modes, so entering and leaving edit mode animates the
    /// same cards in place rather than cross-fading two copies of the dashboard.
    @ViewBuilder
    private var content: some View {
        if !isEditing && workouts.isEmpty {
            emptyState
        } else if !isEditing && widgets.isEmpty {
            noWidgetsState
        } else {
            dashboardContent
        }
    }

    // MARK: - Layout

    private var dashboardContent: some View {
        ScrollView {
            // 16-pt gaps between cards (8-pt grid); 12 inside them.
            VStack(spacing: 16) {
                ForEach(rows) { row in
                    gridRow(row)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .padding(.horizontal)
            // Room for the ⊖ badges that overhang the first row.
            .padding(.top, isEditing ? 12 : 0)
            .padding(.bottom, 24)
        }
        .overlay {
            if isEditing && widgets.isEmpty {
                ContentUnavailableView {
                    Label("No Widgets", systemImage: "square.grid.2x2")
                } description: {
                    Text("Tap ＋ to add a widget.")
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private func gridRow(_ row: DashboardRow) -> some View {
        if row.widgets.count == 2 {
            // Two smalls side by side; stacked at accessibility type sizes.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(row.widgets) { widgetCell($0) }
                }
                // Equal heights when accessibility type sizes let the cells grow.
                .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 16) {
                    ForEach(row.widgets) { widgetCell($0) }
                }
            }
        } else if let widget = row.widgets.first {
            if widget.size == .small {
                // A small widget with no partner keeps its half width.
                HStack(spacing: 16) {
                    widgetCell(widget)
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                }
            } else {
                widgetCell(widget)
            }
        }
    }

    @ViewBuilder
    private func widgetCell(_ widget: DashboardWidget) -> some View {
        if let kind = widget.kind {
            let card = DashboardWidgetView(
                kind: kind,
                data: data,
                range: rangeBinding(for: widget),
                size: widget.size,
                exercise: widget.exercise
            ) {
                widgetChangingExercise = widget
            }

            if isEditing {
                ZStack {
                    // The card's own links, menus and buttons sleep while editing; the clear
                    // layer takes the touches instead, so the drag lifts the whole card.
                    card.allowsHitTesting(false)
                    Color.clear.contentShape(Rectangle())
                }
                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onDrag {
                    draggedWidget = widget
                    return NSItemProvider(object: widget.kindRawValue as NSString)
                }
                .overlay(alignment: .topLeading) {
                    removeBadge(for: widget, kind: kind)
                }
                .onDrop(of: [.text], delegate: WidgetDropDelegate(
                    target: widget,
                    dragged: $draggedWidget,
                    move: move
                ))
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: "Remove \(kind.title)") { remove(widget) }
            } else {
                card
                    .contextMenu {
                        if kind.supportedSizes.count > 1 {
                            Picker(selection: sizeBinding(for: widget)) {
                                ForEach(kind.supportedSizes) { size in
                                    Text(size.label).tag(size)
                                }
                            } label: {
                                Label("Size", systemImage: "rectangle.expand.vertical")
                            }
                            .pickerStyle(.menu)
                        }
                        if kind.needsExercise {
                            Button {
                                widgetChangingExercise = widget
                            } label: {
                                Label("Change Exercise…", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        Button {
                            setEditing(true)
                        } label: {
                            Label("Edit Dashboard", systemImage: "pencil")
                        }
                    }
            }
        }
    }

    /// Control Center's gray ⊖, hung off the card's top-left corner.
    private func removeBadge(for widget: DashboardWidget, kind: DashboardWidgetKind) -> some View {
        Button {
            remove(widget)
        } label: {
            Image(systemName: "minus")
                .font(.system(size: badgeSize * 0.5, weight: .bold))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: badgeSize, height: badgeSize)
                .background(Color(uiColor: .systemGray), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: -(22 - badgeSize / 2) - 8, y: -(22 - badgeSize / 2) - 8)
        .accessibilityLabel("Remove \(kind.title)")
    }

    /// The edit-mode bar: ＋ top-leading, Done top-trailing, floating over the cards. Card-
    /// coloured fills (not material) so a chart scrolling beneath never shows through.
    private var editBar: some View {
        HStack {
            Button {
                showingAddWidget = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            }
            .accessibilityLabel("Add Widget")

            Spacer()

            Button {
                setEditing(false)
            } label: {
                Text("Done")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Analytics Yet", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Log a few workouts and your volume, consistency and best lifts will show up here.")
        }
    }

    private var noWidgetsState: some View {
        ContentUnavailableView {
            Label("No Widgets", systemImage: "square.grid.2x2")
        } description: {
            Text("Add widgets to see your volume, consistency and lifts here.")
        } actions: {
            Button("Edit Dashboard") { setEditing(true) }
        }
    }

    // MARK: - Editing

    private func setEditing(_ editing: Bool) {
        draggedWidget = nil
        withAnimation(.snappy) { isEditing = editing }
    }

    private func remove(_ widget: DashboardWidget) {
        withAnimation(.snappy) { viewModel?.remove(widget) }
        removals += 1
    }

    /// Moves the dragged widget into the target's slot. Called as the drag enters each card,
    /// so the rest reflow live; each step saves, so a drag that ends anywhere is kept.
    private func move(_ dragged: DashboardWidget, onto target: DashboardWidget) {
        guard let dashboard else { return }
        var ordered = dashboard.orderedWidgets
        guard
            let from = ordered.firstIndex(where: { $0 === dragged }),
            let to = ordered.firstIndex(where: { $0 === target }),
            from != to
        else { return }
        ordered.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        withAnimation(.snappy) { viewModel?.reorder(ordered, moved: dragged) }
    }

    private func sizeBinding(for widget: DashboardWidget) -> Binding<DashboardWidgetSize> {
        Binding(
            get: { widget.size },
            set: { newValue in
                withAnimation(.snappy) { viewModel?.setSize(newValue, for: widget) }
            }
        )
    }

    private func rangeBinding(for widget: DashboardWidget) -> Binding<AnalyticsRange> {
        Binding(
            get: { widget.range },
            set: { newValue in
                withAnimation(.snappy) { widget.range = newValue }
                try? context.save()
            }
        )
    }

    // MARK: - Derived data

    private var dashboard: Dashboard? { dashboards.first }

    /// Holds no state of its own (just the dashboard and the context), so it's built on use
    /// rather than kept: `@Environment` isn't readable in `init`, and this screen is created
    /// by the tab bar with no context to hand it.
    private var viewModel: DashboardViewModel? {
        dashboard.map { DashboardViewModel(dashboard: $0, context: context) }
    }

    private var data: DashboardData {
        DashboardData(
            workouts: workouts,
            plans: plans,
            bodyWeightKg: profiles.first?.weightKg,
            exercises: exercises
        )
    }

    private var widgets: [DashboardWidget] {
        (dashboard?.orderedWidgets ?? []).filter { $0.kind != nil }
    }

    private var rows: [DashboardRow] {
        DashboardLayout.rows(widgets).map(DashboardRow.init)
    }
}

/// Reorders live: as a dragged card passes over another, it takes that card's place.
private struct WidgetDropDelegate: DropDelegate {
    let target: DashboardWidget
    @Binding var dragged: DashboardWidget?
    let move: (DashboardWidget, DashboardWidget) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged !== target else { return }
        move(dragged, target)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        return true
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(SampleData.container)
}
