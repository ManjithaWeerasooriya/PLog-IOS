//
//  DashboardViewModel.swift
//  PLog
//
//  Owns the Progress dashboard's structural edits: adding, removing, reordering and
//  resizing widgets, and changing an Exercise Progress widget's exercise. Every change saves
//  immediately, so the layout (and the JSON backup built from it) never lags the screen.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class DashboardViewModel {
    let dashboard: Dashboard

    private let context: ModelContext

    init(dashboard: Dashboard, context: ModelContext) {
        self.dashboard = dashboard
        self.context = context
    }

    var widgets: [DashboardWidget] { dashboard.orderedWidgets }

    /// Single-instance kinds already on the dashboard can't be added again.
    func canAdd(_ kind: DashboardWidgetKind) -> Bool {
        kind.allowsMultiple || !widgets.contains { $0.kind == kind }
    }

    func add(_ kind: DashboardWidgetKind, exercise: Exercise? = nil) {
        guard canAdd(kind) else { return }
        let widget = DashboardWidget(
            kind: kind,
            order: (widgets.last?.order ?? -1) + 1,
            exercise: exercise
        )
        context.insert(widget)
        dashboard.widgets.append(widget)
        renumber(widgets)
        save()
    }

    func remove(_ widget: DashboardWidget) {
        dashboard.widgets.removeAll { $0 === widget }
        context.delete(widget)
        renumber(widgets)
        save()
    }

    /// Persists a new order. The view does the `move(fromOffsets:)` (a SwiftUI API).
    /// `moved` is the widget the user dragged; packing keeps it where it was dropped.
    func reorder(_ ordered: [DashboardWidget], moved: DashboardWidget? = nil) {
        renumber(ordered, anchor: moved)
        save()
    }

    func setSize(_ size: DashboardWidgetSize, for widget: DashboardWidget) {
        guard widget.kind?.supportedSizes.contains(size) == true else { return }
        widget.size = size
        renumber(widgets)
        save()
    }

    func setExercise(_ exercise: Exercise, for widget: DashboardWidget) {
        widget.exercise = exercise
        save()
    }

    /// Stores the order as drawn (see `DashboardLayout`), so a small widget that packing pulled
    /// up beside another stays there in the saved layout.
    private func renumber(_ ordered: [DashboardWidget], anchor: DashboardWidget? = nil) {
        for (index, widget) in DashboardLayout.packedOrder(ordered, anchor: anchor).enumerated() where widget.order != index {
            widget.order = index
        }
    }

    private func save() {
        try? context.save()
    }
}
