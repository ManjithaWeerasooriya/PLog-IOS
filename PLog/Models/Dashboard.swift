//
//  Dashboard.swift
//  PLog
//
//  The Progress tab's layout: which widgets the user has, in what order, and each one's
//  settings. Lives in SwiftData (not `@AppStorage`) because an Exercise Progress widget points
//  at an `Exercise`, and only a relationship survives renames, deletes and a backup restore.
//  `Dashboard` is a singleton like `UserProfile` — its existence marks the layout as seeded,
//  so a user who removes every widget isn't handed the defaults back on the next launch.
//

import Foundation
import SwiftData

/// How far back the weekly trend widgets look.
enum AnalyticsRange: Int, CaseIterable, Identifiable {
    case eightWeeks = 8
    case twelveWeeks = 12
    case halfYear = 26

    var id: Int { rawValue }
    var weeks: Int { rawValue }

    /// e.g. "Last 12 weeks"
    var label: String { "Last \(rawValue) weeks" }
}

/// How much of the dashboard grid a widget covers. The grid is 4 columns wide; a unit row
/// is as tall as a column is wide, so a small widget is square. Persisted by raw value
/// (`DashboardWidget.sizeRawValue`), so a rename must keep the old string.
enum DashboardWidgetSize: String, CaseIterable, Identifiable {
    /// 2×2: half width; two sit side by side.
    case small
    /// 4×2: full width, small height.
    case wide
    /// 4×4: full width, twice the height.
    case large

    var id: String { rawValue }

    var columns: Int { self == .small ? 2 : 4 }
    var rows: Int { self == .large ? 4 : 2 }

    var label: String {
        switch self {
        case .small: return "Small"
        case .wide: return "Wide"
        case .large: return "Large"
        }
    }
}

/// The grid's fixed numbers. A row unit is scaled with Dynamic Type by each view that lays
/// out cards (`@ScaledMetric(relativeTo: .body)` from `baseUnit`), so taller text gets
/// taller cells; the dashboard and the Add Widget gallery must agree, hence one place.
enum DashboardGrid {
    static let baseUnit: CGFloat = 80
    static let spacing: CGFloat = 16

    static func height(of size: DashboardWidgetSize, unit: CGFloat) -> CGFloat {
        let rows = CGFloat(size.rows)
        return rows * unit + (rows - 1) * spacing
    }
}

/// What a widget shows. Persisted by raw value (`DashboardWidget.kindRawValue`), so a rename
/// must keep the old string: `case newName = "oldRawValue"` (see AGENT.md).
enum DashboardWidgetKind: String, CaseIterable, Identifiable {
    case plan
    case bodyWeight
    case activity
    case weekVolume
    case totals
    case weeklyVolume
    case sessions
    case muscleSplit
    case bestLifts
    case exerciseProgress
    case regressingExercises

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan: return "Active Plan"
        case .bodyWeight: return "Body Weight"
        case .activity: return "Activity"
        case .weekVolume: return "Volume Lifted"
        case .totals: return "Totals"
        case .weeklyVolume: return "Weekly Volume"
        case .sessions: return "Sessions per Week"
        case .muscleSplit: return "Muscle Groups"
        case .bestLifts: return "Best Lifts"
        case .exerciseProgress: return "Exercise Progress"
        case .regressingExercises: return "Regressing Exercises"
        }
    }

    var systemImage: String {
        switch self {
        case .plan: return "list.clipboard"
        case .bodyWeight: return "scalemass"
        case .activity: return "calendar"
        case .weekVolume: return "chart.bar"
        case .totals: return "number"
        case .weeklyVolume: return "chart.bar.xaxis"
        case .sessions: return "figure.strengthtraining.traditional"
        case .muscleSplit: return "chart.pie"
        case .bestLifts: return "trophy"
        case .exerciseProgress: return "chart.xyaxis.line"
        case .regressingExercises: return "arrow.down.right"
        }
    }

    /// One line for the Add Widget picker.
    var summary: String {
        switch self {
        case .plan: return "This week's sessions against your active plan"
        case .bodyWeight: return "Your weight from Settings"
        case .activity: return "Training days at a glance; opens the calendar"
        case .weekVolume: return "Kilograms lifted in the last 7 days"
        case .totals: return "Workouts, sets and your week streak"
        case .weeklyVolume: return "Volume per week over a range you pick"
        case .sessions: return "Sessions per week against your plan"
        case .muscleSplit: return "Sets per muscle group"
        case .bestLifts: return "Your strongest lifts by estimated one-rep max"
        case .exerciseProgress: return "One exercise's estimated one-rep max over time"
        case .regressingExercises: return "Exercises that dipped since the session before"
        }
    }

    /// The sizes this widget has a layout for, smallest first.
    var supportedSizes: [DashboardWidgetSize] {
        switch self {
        case .plan, .bodyWeight: return [.small, .wide]
        case .activity: return [.small, .wide]
        case .totals: return [.small, .wide, .large]
        case .weekVolume, .weeklyVolume, .sessions, .muscleSplit,
             .bestLifts, .exerciseProgress, .regressingExercises:
            return [.wide, .large]
        }
    }

    /// The size a new widget gets, and the size of a widget saved before sizes existed.
    var defaultSize: DashboardWidgetSize {
        switch self {
        case .plan, .bodyWeight: return .small
        case .bestLifts: return .large
        case .activity, .weekVolume, .totals, .weeklyVolume, .sessions, .muscleSplit,
             .exerciseProgress, .regressingExercises:
            return .wide
        }
    }

    /// Only Exercise Progress makes sense more than once (one per exercise).
    var allowsMultiple: Bool { self == .exerciseProgress }

    var needsExercise: Bool { self == .exerciseProgress }

    /// Widgets with their own `AnalyticsRange` (they used to share one picker).
    var hasRange: Bool {
        self == .weeklyVolume || self == .sessions || self == .muscleSplit
    }

    /// The dashboard as it was before widgets were customisable, so nobody's dashboard changes on update.
    static let defaultLayout: [DashboardWidgetKind] = [
        .plan, .bodyWeight, .activity, .weekVolume, .totals,
        .weeklyVolume, .sessions, .muscleSplit, .bestLifts,
    ]
}

@Model
final class Dashboard {
    /// Cascade: the widgets are the dashboard's own rows. Inverse on `DashboardWidget.dashboard`.
    @Relationship(deleteRule: .cascade, inverse: \DashboardWidget.dashboard)
    var widgets: [DashboardWidget] = []

    init() {}

    var orderedWidgets: [DashboardWidget] {
        widgets.sorted { $0.order < $1.order }
    }
}

@Model
final class DashboardWidget {
    /// A `DashboardWidgetKind` raw value. Stored as a string so a kind this build doesn't know
    /// (a newer backup) is skipped rather than failing to load the row.
    var kindRawValue: String

    /// Position on the dashboard.
    var order: Int

    /// `AnalyticsRange` weeks for the widgets that have a range; ignored by the rest.
    var rangeWeeks: Int

    /// A `DashboardWidgetSize` raw value. `nil` (every widget saved before sizes existed) or a
    /// size this kind doesn't support reads as the kind's default size.
    var sizeRawValue: String? = nil

    /// The tracked exercise for Exercise Progress. Nullified if the exercise is deleted — the
    /// widget then asks for another rather than disappearing.
    var exercise: Exercise?

    var dashboard: Dashboard?

    init(
        kind: DashboardWidgetKind,
        order: Int = 0,
        range: AnalyticsRange = .twelveWeeks,
        size: DashboardWidgetSize? = nil,
        exercise: Exercise? = nil
    ) {
        self.kindRawValue = kind.rawValue
        self.order = order
        self.rangeWeeks = range.rawValue
        self.sizeRawValue = size?.rawValue
        self.exercise = exercise
    }

    var kind: DashboardWidgetKind? {
        DashboardWidgetKind(rawValue: kindRawValue)
    }

    var range: AnalyticsRange {
        get { AnalyticsRange(rawValue: rangeWeeks) ?? .twelveWeeks }
        set { rangeWeeks = newValue.rawValue }
    }

    var size: DashboardWidgetSize {
        get {
            guard let kind else { return .wide }
            guard
                let stored = sizeRawValue.flatMap(DashboardWidgetSize.init(rawValue:)),
                kind.supportedSizes.contains(stored)
            else { return kind.defaultSize }
            return stored
        }
        set { sizeRawValue = newValue.rawValue }
    }
}

/// Packs widgets into grid rows. Full-width widgets take a row each; small ones pair up. A
/// small widget left alone pulls the next small one up beside it, even past full-width
/// widgets in between — dense packing, like the Home Screen — so a half-empty row only
/// remains when there's no other small widget below to fill it.
///
/// `anchor` is the widget being dragged: it stays where it was dropped, so when it's the one
/// that would be pulled up, the lone small widget moves down to join it instead. Without
/// this, dragging one of a pair below a full-width widget would snap straight back.
enum DashboardLayout {
    static func rows(_ widgets: [DashboardWidget], anchor: DashboardWidget? = nil) -> [[DashboardWidget]] {
        var rows: [[DashboardWidget]] = []
        var openSmallRow: Int?
        for widget in widgets {
            if widget.size == .small {
                if let open = openSmallRow {
                    if widget === anchor {
                        let lone = rows.remove(at: open)
                        rows.append(lone + [widget])
                    } else {
                        rows[open].append(widget)
                    }
                    openSmallRow = nil
                } else {
                    rows.append([widget])
                    openSmallRow = rows.count - 1
                }
            } else {
                rows.append([widget])
            }
        }
        return rows
    }

    /// The order the widgets are actually drawn in. Saved after every edit, so the stored
    /// order (and a backup) always matches what's on screen.
    static func packedOrder(_ widgets: [DashboardWidget], anchor: DashboardWidget? = nil) -> [DashboardWidget] {
        rows(widgets, anchor: anchor).flatMap { $0 }
    }
}

extension Dashboard {
    /// Guarantees the dashboard row exists, seeding the default layout the first time —
    /// including for a store from before widgets existed. A no-op once it's there.
    static func ensureExists(in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Dashboard>())) ?? 0
        guard count == 0 else { return }
        let dashboard = Dashboard()
        context.insert(dashboard)
        dashboard.addDefaultWidgets(in: context)
        try? context.save()
    }

    /// Appends the default widgets (callers clear the dashboard first when replacing it).
    func addDefaultWidgets(in context: ModelContext) {
        for (index, kind) in DashboardWidgetKind.defaultLayout.enumerated() {
            let widget = DashboardWidget(kind: kind, order: index)
            context.insert(widget)
            widgets.append(widget)
        }
    }
}
