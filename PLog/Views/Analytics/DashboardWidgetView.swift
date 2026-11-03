//
//  DashboardWidgetView.swift
//  PLog
//
//  One Progress widget, drawn from precomputed `DashboardStats`. The dashboard and the Add
//  Widget gallery both render through this view, so a preview in the gallery is the real
//  card, not a mock. Pure layout over the figures it's handed: it never reads workouts or
//  sets in `body` (see `DashboardStats` for why); the host owns queries, persistence and
//  editing.
//

import SwiftUI
import SwiftData
import Charts

/// Everything the widgets' figures come from, queried once by the screen that hosts them
/// and turned into `DashboardStats`.
struct DashboardData {
    /// Newest first.
    var workouts: [WorkoutDay]
    var plans: [WorkoutPlan]
    var bodyWeightKg: Double?
    /// Sorted by name.
    var exercises: [Exercise]
}

struct DashboardWidgetView: View {
    let kind: DashboardWidgetKind
    let stats: DashboardStats
    /// For the trend widgets; the others ignore it.
    @Binding var range: AnalyticsRange
    /// For Muscle Groups, which also offers the current week; the others ignore it.
    var muscleSplitPeriod: Binding<MuscleSplitPeriod> = .constant(.range(.twelveWeeks))
    /// The grid cell to fill; `nil` uses the kind's default size.
    var size: DashboardWidgetSize? = nil
    /// For Exercise Progress; the others ignore it.
    var exercise: Exercise? = nil
    var onChooseExercise: () -> Void = {}

    // Scaled with the type size so the ring and legend dots keep pace with their labels.
    // The donut stays fixed: it's a chart, and at accessibility sizes its legend drops
    // beneath it instead.
    @ScaledMetric(relativeTo: .title2) private var ringSize = 64
    @ScaledMetric(relativeTo: .caption) private var legendDot = 7

    /// One grid row's height. A column is about this wide on a phone, so 2×2 is square.
    @ScaledMetric(relativeTo: .body) private var gridUnit: CGFloat = DashboardGrid.baseUnit

    var body: some View {
        content
            .environment(\.analyticsCardHeight, cellHeight)
    }

    private var layoutSize: DashboardWidgetSize {
        size.flatMap { kind.supportedSizes.contains($0) ? $0 : nil } ?? kind.defaultSize
    }

    @Environment(\.dashboardGridUnit) private var widthUnit

    private var cellHeight: CGFloat {
        DashboardGrid.height(of: layoutSize, unit: widthUnit ?? gridUnit)
    }

    private var isLarge: Bool { layoutSize == .large }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .plan: planCard
        case .bodyWeight: bodyWeightCard
        case .activity: activityCard
        case .weekVolume: weekVolumeCard
        case .totals: totalsRow
        case .weeklyVolume: weeklyVolumeCard
        case .sessions: sessionsCard
        case .muscleSplit: muscleSplitCard
        case .bestLifts: bestLiftsCard
        case .exerciseProgress:
            ExerciseProgressWidget(
                exercise: exercise,
                points: exercise.map(stats.points(for:)) ?? [],
                size: layoutSize,
                onChooseExercise: onChooseExercise
            )
        case .regressingExercises:
            RegressingExercisesWidget(regressions: stats.regressions, size: layoutSize)
        }
    }

    // MARK: - Plan & body weight

    /// Small: ring above the title. Wide: ring beside it.
    private var planCard: some View {
        AnalyticsCard {
            if layoutSize == .small {
                VStack(alignment: .leading, spacing: 12) {
                    planRing
                    Spacer(minLength: 0)
                    planTitle
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                HStack(spacing: 16) {
                    planRing
                    planTitle
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var planRing: some View {
        Group {
            if let plan = stats.plan {
                let done = stats.thisWeekSessions
                ProgressRing(progress: Double(done) / Double(max(plan.dayCount, 1))) {
                    Text("\(done)")
                        .font(.title2.bold())
                        .monospacedDigit()
                }
            } else {
                ProgressRing(progress: 0) {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: ringSize, height: ringSize)
    }

    @ViewBuilder
    private var planTitle: some View {
        if let plan = stats.plan {
            AnalyticsCardTitle(
                title: plan.name.isEmpty ? "Plan" : plan.name,
                subtitle: planSubtitle(for: plan, done: stats.thisWeekSessions, target: max(plan.dayCount, 1))
            )
        } else {
            AnalyticsCardTitle(title: "No active plan", subtitle: "Start one in Plans")
        }
    }

    private func planSubtitle(for plan: DashboardStats.PlanSummary, done: Int, target: Int) -> String {
        var parts = ["\(done) of \(target) this week"]
        if let next = plan.nextDayName, !next.isEmpty {
            parts.append("Next: \(next)")
        }
        return parts.joined(separator: " · ")
    }

    /// Small: number above the title. Wide: title leading, number trailing.
    private var bodyWeightCard: some View {
        AnalyticsCard {
            if layoutSize == .small {
                VStack(alignment: .leading, spacing: 12) {
                    bodyWeightStat
                    Spacer(minLength: 0)
                    bodyWeightTitle
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                HStack {
                    bodyWeightTitle
                    Spacer()
                    bodyWeightStat
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var bodyWeightStat: some View {
        BigStat(value: stats.bodyWeightKg.map { WeightFormatter.string($0) } ?? "—", unit: "kg")
    }

    private var bodyWeightTitle: some View {
        AnalyticsCardTitle(
            title: "Body weight",
            subtitle: stats.bodyWeightKg == nil ? "Set it in Settings" : "From your profile"
        )
    }

    // MARK: - Activity grid

    /// Tappable: pushes the full month calendar. Wide: three months of dots in one compact
    /// row of months (it used to be a 4×4 card, mostly empty space). Small: this month only,
    /// laid out as a calendar.
    private var activityCard: some View {
        NavigationLink(value: ProgressRoute.calendar) {
            AnalyticsCard {
                if layoutSize == .small {
                    smallActivity
                } else {
                    wideActivity
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(activityAccessibilityLabel)
    }

    private var wideActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Activity")
                    .font(.headline)
                Text("Last 3 months")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text("\(recentWorkoutCount) workout\(recentWorkoutCount == 1 ? "" : "s")")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                activityChevron
            }
            .lineLimit(1)
            ActivityDotGrid(months: stats.activityMonths, dotSize: 7, spacing: 4)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var smallActivity: some View {
        let cells = stats.thisMonthCells
        let trained = Self.trainedCount(cells)
        // The count sits in the header beside a trained-day dot: a six-week month of dots
        // plus a footer line ran taller than a small cell.
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Date.now.formatted(.dateTime.month(.wide)))
                    .font(.headline)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                    Text("\(trained)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                activityChevron
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            ActivityMonthDots(cells: cells)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var activityChevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
    }

    private var activityAccessibilityLabel: String {
        if layoutSize == .small {
            let trained = Self.trainedCount(stats.thisMonthCells)
            return "Activity, \(Date.now.formatted(.dateTime.month(.wide))): \(trained) workout\(trained == 1 ? "" : "s")"
        }
        return "Activity, last 3 months: \(recentWorkoutCount) workout\(recentWorkoutCount == 1 ? "" : "s")"
    }

    // MARK: - Last 7 days volume

    private var weekVolumeCard: some View {
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(title: "Volume lifted", subtitle: "Last 7 days") {
                    BigStat(value: WeightFormatter.volumeString(last7Volume), unit: "kg", style: .title)
                    if let change = WorkoutStats.percentChange(from: stats.previous7Volume, to: last7Volume) {
                        TrendBadge(
                            trend: change > 0.5 ? .improved : (change < -0.5 ? .regressed : .matched),
                            text: "\(change > 0 ? "+" : "")\(Int(change.rounded()))% vs prior week"
                        )
                    }
                }

                Chart(stats.last7Days) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Volume", day.volume)
                    )
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxis(.hidden)
                .frame(minHeight: 60, maxHeight: .infinity)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
    }

    // MARK: - Totals

    private var totalsRow: some View {
        TotalsWidget(workouts: stats.workoutCount, sets: stats.totalSets, streak: stats.streak, size: layoutSize)
    }

    // MARK: - Trends

    /// The range subtitle on a trend card: tap to pick how far back it looks. Each card keeps
    /// its own range (they used to share one picker above them).
    private func rangeMenu(prefix: String? = nil) -> some View {
        optionMenu(AnalyticsRange.allCases, selection: $range, label: \.label, prefix: prefix)
    }

    /// A tappable caption ("Last 12 weeks ⌃⌄") that opens a menu of `options`. Compact enough
    /// for a small card, so every size gets the same control.
    private func optionMenu<Option: Hashable & Identifiable>(
        _ options: [Option],
        selection: Binding<Option>,
        label: @escaping (Option) -> String,
        prefix: String?
    ) -> some View {
        let current = label(selection.wrappedValue)
        return Menu {
            Picker("Range", selection: selection) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(prefix.map { "\($0) · \(current.lowercased())" } ?? current)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .tint(.secondary)
        .accessibilityLabel("Range")
        .accessibilityValue(current)
    }

    private func trendTitle<Menu: View>(_ title: String, @ViewBuilder menu: () -> Menu) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            menu()
        }
    }

    private func trendTitle(_ title: String, prefix: String? = nil) -> some View {
        trendTitle(title) { rangeMenu(prefix: prefix) }
    }

    @ViewBuilder
    private var weeklyVolumeCard: some View {
        let weekly = weeklySummaries(range)
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader {
                    trendTitle("Weekly volume")
                } trailing: {
                    BigStat(value: WeightFormatter.volumeString(averageWeeklyVolume(weekly)), unit: "kg avg", style: .title2)
                }
                Chart(weekly) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Volume", week.volume)
                    )
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(3)
                }
                .chartXAxis { weeklyAxis(range) }
                .frame(minHeight: 60, maxHeight: .infinity)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
    }

    @ViewBuilder
    private var sessionsCard: some View {
        let weekly = weeklySummaries(range)
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader {
                    trendTitle("Sessions per week")
                } trailing: {
                    BigStat(value: String(format: "%.1f", averageWeeklySessions(weekly)), unit: "avg", style: .title2)
                }
                Chart {
                    ForEach(weekly) { week in
                        BarMark(
                            x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Sessions", week.sessions)
                        )
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(3)
                    }
                    if let target = stats.plan?.dayCount, target > 0 {
                        RuleMark(y: .value("Plan", target))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(.secondary)
                            .annotation(position: .top, alignment: .leading) {
                                Text("Plan: \(target)/wk")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartXAxis { weeklyAxis(range) }
                .chartYAxis {
                    AxisMarks(values: Array(0...sessionsAxisMax(weekly))) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(minHeight: 60, maxHeight: .infinity)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
    }

    private func weeklyAxis(_ range: AnalyticsRange) -> some AxisContent {
        AxisMarks(values: .stride(by: .weekOfYear, count: max(1, range.weeks / 4))) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
    }

    // MARK: - Muscle split

    /// Tappable like Best Lifts and Activity: pushes `MuscleGroupsView` at this card's period.
    /// The period menu in the header ("This week" or a range) still works on its own — a tap
    /// on it opens the menu, anywhere else on the card navigates.
    private var muscleSplitCard: some View {
        let period = muscleSplitPeriod.wrappedValue
        let split = stats.muscleSplit[period] ?? []
        let total = split.reduce(0) { $0 + $1.sets }
        return NavigationLink(value: ProgressRoute.muscleGroups(period)) {
            AnalyticsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        // Small has no room for the "Sets ·" prefix beside the period.
                        trendTitle("Muscle groups") {
                            optionMenu(
                                MuscleSplitPeriod.allCases,
                                selection: muscleSplitPeriod,
                                label: \.label,
                                prefix: layoutSize == .small ? nil : "Sets"
                            )
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    if split.isEmpty {
                        emptyMuscleSplit(period)
                    } else if layoutSize == .small {
                        // Small: the donut alone, its total in the middle.
                        donut(split, total: total, diameter: 84)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if isLarge {
                        // Large: the donut on top, legend in two columns beneath.
                        VStack(spacing: 16) {
                            donut(split, total: total, diameter: 168)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], spacing: 8) {
                                legendRows(split, total: total, limit: 6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 20) { muscleSplitContent(split, total: total) }
                            VStack(alignment: .leading, spacing: 16) { muscleSplitContent(split, total: total) }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .buttonStyle(.plain)
    }

    /// Wide: a small donut beside the top three groups.
    @ViewBuilder
    private func muscleSplitContent(_ split: [WorkoutStats.MuscleGroupShare], total: Double) -> some View {
        donut(split, total: total, diameter: 92)
        VStack(alignment: .leading, spacing: 8) {
            legendRows(split, total: total, limit: 3)
        }
    }

    private func donut(_ split: [WorkoutStats.MuscleGroupShare], total: Double, diameter: CGFloat) -> some View {
        Chart(split) { share in
            SectorMark(
                angle: .value("Sets", share.sets),
                innerRadius: .ratio(0.66),
                angularInset: 1.5
            )
            .foregroundStyle(share.group.color)
            .cornerRadius(3)
        }
        .chartLegend(.hidden)
        .frame(width: diameter, height: diameter)
        .overlay {
            // Sets actually done, not the weighted share total (see `workingSetCount`).
            DonutCenterLabel(
                value: WorkoutStats.compactCountString(setsDone),
                caption: setsDone == 1 ? "set" : "sets",
                holeDiameter: diameter * 0.66
            )
        }
    }

    private var setsDone: Int {
        stats.setsDone[muscleSplitPeriod.wrappedValue] ?? 0
    }

    /// Fills the card so the grid cell keeps its size; one line on small, a hint beside it
    /// on the bigger sizes.
    private func emptyMuscleSplit(_ period: MuscleSplitPeriod) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.pie")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(period == .thisWeek ? "No sets yet this week" : "No sets in this range")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            if layoutSize != .small {
                Text(period == .thisWeek
                     ? "Log a workout and its sets show up here."
                     : "Pick a longer range, or log a workout.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func legendRows(_ split: [WorkoutStats.MuscleGroupShare], total: Double, limit: Int) -> some View {
        // With more groups than room, the last slot says how many are left out.
        let shown = split.count > limit ? limit - 1 : limit
        ForEach(split.prefix(shown)) { share in
            HStack(spacing: 8) {
                Circle().fill(share.group.color).frame(width: legendDot, height: legendDot)
                Text(share.group.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text("\(Int((share.sets / max(total, 1) * 100).rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        if split.count > limit {
            Text("+\(split.count - shown) more")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Title/subtitle leading with a stat trailing — or, when the stat no longer fits
    /// beside the title at large type sizes, the stat beneath it.
    private func cardHeader<Trailing: View>(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        cardHeader {
            AnalyticsCardTitle(title: title, subtitle: subtitle)
        } trailing: {
            trailing()
        }
    }

    private func cardHeader<Title: View, Trailing: View>(
        @ViewBuilder title: () -> Title,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        let title = title()
        let trailing = trailing()
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                title
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { trailing }
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                VStack(alignment: .leading, spacing: 4) { trailing }
            }
        }
    }

    // MARK: - Best lifts

    /// Tappable like Activity: pushes `BestLiftsView`, which opens on the top lift.
    private var bestLiftsCard: some View {
        let lifts = Array(stats.bestLifts.prefix(isLarge ? 5 : 2))
        return NavigationLink(value: ProgressRoute.bestLifts) {
            AnalyticsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        AnalyticsCardTitle(title: "Best lifts", subtitle: "Estimated one-rep max")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    if lifts.isEmpty {
                        if isLarge {
                            ContentUnavailableView {
                                Label("No Lifts Yet", systemImage: "trophy")
                            } description: {
                                Text("Log sets with weight and reps to rank your strongest lifts.")
                            }
                        } else {
                            ContentUnavailableView("No Lifts Yet", systemImage: "trophy")
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(lifts.enumerated()), id: \.element.id) { index, lift in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(lift.exercise.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text(lift.exercise.category.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    TrendBadge(trend: lift.trend)
                                    Text("\(WeightFormatter.string(lift.estimatedOneRepMax)) kg")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.primary)
                                }
                                .padding(.vertical, isLarge ? 10 : 6)
                                if index < lifts.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived data

    private func weeklySummaries(_ range: AnalyticsRange) -> [WorkoutStats.WeekSummary] {
        stats.weekly[range] ?? []
    }

    private func averageWeeklyVolume(_ weekly: [WorkoutStats.WeekSummary]) -> Double {
        guard !weekly.isEmpty else { return 0 }
        return weekly.reduce(0) { $0 + $1.volume } / Double(weekly.count)
    }

    private func averageWeeklySessions(_ weekly: [WorkoutStats.WeekSummary]) -> Double {
        guard !weekly.isEmpty else { return 0 }
        return Double(weekly.reduce(0) { $0 + $1.sessions }) / Double(weekly.count)
    }

    private func sessionsAxisMax(_ weekly: [WorkoutStats.WeekSummary]) -> Int {
        let peak = weekly.map(\.sessions).max() ?? 0
        return max(peak, stats.plan?.dayCount ?? 0, 1)
    }

    private var last7Volume: Double {
        stats.last7Days.reduce(0) { $0 + $1.volume }
    }

    private var recentWorkoutCount: Int {
        Self.trainedCount(stats.activityMonths.flatMap(\.weeks).flatMap { $0 })
    }

    private static func trainedCount(_ cells: [CalendarDayCell?]) -> Int {
        cells
            .compactMap { $0 }
            .filter { if case .trained = $0.status { return true } else { return false } }
            .count
    }
}

#Preview {
    let stats = DashboardStats(data: SampleData.dashboardData)
    return NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(DashboardWidgetKind.allCases) { kind in
                    DashboardWidgetView(kind: kind, stats: stats, range: .constant(.twelveWeeks), exercise: SampleData.benchPress)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    .modelContainer(SampleData.container)
}
