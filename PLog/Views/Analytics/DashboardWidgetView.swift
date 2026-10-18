//
//  DashboardWidgetView.swift
//  PLog
//
//  One Progress widget, drawn from `DashboardData`. The dashboard and the Add Widget gallery
//  both render through this view, so a preview in the gallery is the real card, not a mock.
//  Pure layout over the data it's handed; the host owns queries, persistence and editing.
//

import SwiftUI
import SwiftData
import Charts

/// Everything the widgets read, queried once by the screen that hosts them.
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
    let data: DashboardData
    /// For the trend widgets; the others ignore it.
    @Binding var range: AnalyticsRange
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

    private let calendar = Calendar.current

    private var workouts: [WorkoutDay] { data.workouts }
    private var plans: [WorkoutPlan] { data.plans }
    private var exercises: [Exercise] { data.exercises }

    var body: some View {
        content
            .environment(\.analyticsCardHeight, cellHeight)
    }

    private var layoutSize: DashboardWidgetSize {
        size.flatMap { kind.supportedSizes.contains($0) ? $0 : nil } ?? kind.defaultSize
    }

    private var cellHeight: CGFloat {
        DashboardGrid.height(of: layoutSize, unit: gridUnit)
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
            ExerciseProgressWidget(exercise: exercise, size: layoutSize, onChooseExercise: onChooseExercise)
        case .regressingExercises:
            RegressingExercisesWidget(
                regressions: WorkoutStats.regressingExercises(exercises: exercises),
                size: layoutSize
            )
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
            if let plan = activePlan {
                let done = thisWeek?.sessions ?? 0
                ProgressRing(progress: Double(done) / Double(max(plan.days.count, 1))) {
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
        if let plan = activePlan {
            AnalyticsCardTitle(
                title: plan.name.isEmpty ? "Plan" : plan.name,
                subtitle: planSubtitle(for: plan, done: thisWeek?.sessions ?? 0, target: max(plan.days.count, 1))
            )
        } else {
            AnalyticsCardTitle(title: "No active plan", subtitle: "Start one in Plans")
        }
    }

    private func planSubtitle(for plan: WorkoutPlan, done: Int, target: Int) -> String {
        var parts = ["\(done) of \(target) this week"]
        if let next = WorkoutLogger.suggestedNextDay(in: plan), !next.name.isEmpty {
            parts.append("Next: \(next.name)")
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
        BigStat(value: data.bodyWeightKg.map { WeightFormatter.string($0) } ?? "—", unit: "kg")
    }

    private var bodyWeightTitle: some View {
        AnalyticsCardTitle(
            title: "Body weight",
            subtitle: data.bodyWeightKg == nil ? "Set it in Settings" : "From your profile"
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
            ActivityDotGrid(months: activityMonths, dotSize: 7, spacing: 4)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var smallActivity: some View {
        let month = WorkoutCalendar.startOfMonth(.now, calendar: calendar)
        let cells = WorkoutCalendar.monthCells(
            for: month,
            workouts: workouts,
            historyStart: WorkoutCalendar.historyStart(workouts: workouts, plans: plans, calendar: calendar),
            calendar: calendar
        )
        let trained = cells.compactMap { $0 }.filter { if case .trained = $0.status { return true } else { return false } }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(month.formatted(.dateTime.month(.wide)))
                    .font(.headline)
                Spacer(minLength: 4)
                activityChevron
            }
            .lineLimit(1)
            ActivityMonthDots(cells: cells)
            Spacer(minLength: 0)
            Text("\(trained) workout\(trained == 1 ? "" : "s")")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
            let month = WorkoutCalendar.startOfMonth(.now, calendar: calendar)
            let trained = WorkoutCalendar.monthCells(
                for: month,
                workouts: workouts,
                historyStart: WorkoutCalendar.historyStart(workouts: workouts, plans: plans, calendar: calendar),
                calendar: calendar
            )
            .compactMap { $0 }
            .filter { if case .trained = $0.status { return true } else { return false } }
            .count
            return "Activity, \(month.formatted(.dateTime.month(.wide))): \(trained) workout\(trained == 1 ? "" : "s")"
        }
        return "Activity, last 3 months: \(recentWorkoutCount) workout\(recentWorkoutCount == 1 ? "" : "s")"
    }

    // MARK: - Last 7 days volume

    private var weekVolumeCard: some View {
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(title: "Volume lifted", subtitle: "Last 7 days") {
                    BigStat(value: WeightFormatter.volumeString(last7Volume), unit: "kg", style: .title)
                    if let change = WorkoutStats.percentChange(from: previous7Volume, to: last7Volume) {
                        TrendBadge(
                            trend: change > 0.5 ? .improved : (change < -0.5 ? .regressed : .matched),
                            text: "\(change > 0 ? "+" : "")\(Int(change.rounded()))% vs prior week"
                        )
                    }
                }

                Chart(last7Days) { day in
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
        TotalsWidget(workouts: workouts.count, sets: totalSets, streak: streak, size: layoutSize)
    }

    // MARK: - Trends

    /// The range subtitle on a trend card: tap to pick how far back it looks. Each card keeps
    /// its own range (they used to share one picker above them).
    private func rangeMenu(prefix: String? = nil) -> some View {
        Menu {
            Picker("Range", selection: $range) {
                ForEach(AnalyticsRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(prefix.map { "\($0) · \(range.label.lowercased())" } ?? range.label)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .tint(.secondary)
        .accessibilityLabel("Range")
        .accessibilityValue(range.label)
    }

    private func trendTitle(_ title: String, prefix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            rangeMenu(prefix: prefix)
        }
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
                    if let target = activePlan?.days.count, target > 0 {
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

    @ViewBuilder
    private var muscleSplitCard: some View {
        let split = muscleSplit(range)
        let total = split.reduce(0) { $0 + $1.sets }
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                trendTitle("Muscle groups", prefix: "Sets")
                if split.isEmpty {
                    Text("No sets logged in this range.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

    /// Wide: a small donut beside the top three groups.
    @ViewBuilder
    private func muscleSplitContent(_ split: [WorkoutStats.MuscleGroupShare], total: Int) -> some View {
        donut(split, total: total, diameter: 92)
        VStack(alignment: .leading, spacing: 8) {
            legendRows(split, total: total, limit: 3)
        }
    }

    private func donut(_ split: [WorkoutStats.MuscleGroupShare], total: Int, diameter: CGFloat) -> some View {
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
            VStack(spacing: 0) {
                Text("\(total)")
                    .font(.title2.bold())
                    .monospacedDigit()
                Text("sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func legendRows(_ split: [WorkoutStats.MuscleGroupShare], total: Int, limit: Int) -> some View {
        // With more groups than room, the last slot says how many are left out.
        let shown = split.count > limit ? limit - 1 : limit
        ForEach(split.prefix(shown)) { share in
            HStack(spacing: 8) {
                Circle().fill(share.group.color).frame(width: legendDot, height: legendDot)
                Text(share.group.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text("\(Int((Double(share.sets) / Double(max(total, 1)) * 100).rounded()))%")
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
        let lifts = Array(bestLifts.prefix(isLarge ? 5 : 2))
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

    private var activePlan: WorkoutPlan? {
        plans.first(where: \.isActive)
    }

    private func weeklySummaries(_ range: AnalyticsRange) -> [WorkoutStats.WeekSummary] {
        WorkoutStats.weeklySummaries(workouts: workouts, weeks: range.weeks, calendar: calendar)
    }

    private var thisWeek: WorkoutStats.WeekSummary? {
        WorkoutStats.weeklySummaries(workouts: workouts, weeks: 1, calendar: calendar).first
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
        return max(peak, activePlan?.days.count ?? 0, 1)
    }

    private var last7Days: [WorkoutStats.DailyVolume] {
        WorkoutStats.dailyVolumes(workouts: workouts, days: 7, calendar: calendar)
    }

    private var last7Volume: Double {
        last7Days.reduce(0) { $0 + $1.volume }
    }

    private var previous7Volume: Double {
        let todayStart = calendar.startOfDay(for: .now)
        guard
            let end = calendar.date(byAdding: .day, value: -6, to: todayStart),
            let start = calendar.date(byAdding: .day, value: -7, to: end)
        else { return 0 }
        return WorkoutStats.workouts(workouts, from: start, before: end)
            .reduce(0) { $0 + WorkoutStats.volume(of: $1) }
    }

    private var totalSets: Int {
        workouts.reduce(0) { $0 + WorkoutStats.setCount(of: $1) }
    }

    private var streak: Int {
        WorkoutStats.weekStreak(workouts: workouts, calendar: calendar)
    }

    private func muscleSplit(_ range: AnalyticsRange) -> [WorkoutStats.MuscleGroupShare] {
        guard let start = weeklySummaries(range).first?.weekStart else { return [] }
        return WorkoutStats.muscleGroupSplit(
            workouts: WorkoutStats.workouts(workouts, from: start, before: .distantFuture)
        )
    }

    private var bestLifts: [WorkoutStats.ExerciseBest] {
        WorkoutStats.bestLifts(exercises: exercises)
    }

    /// The current month and the two before it, oldest first.
    private var activityMonths: [ActivityMonth] {
        let historyStart = WorkoutCalendar.historyStart(workouts: workouts, plans: plans, calendar: calendar)
        let thisMonth = WorkoutCalendar.startOfMonth(.now, calendar: calendar)
        return (0..<3).reversed().compactMap { back in
            guard let month = calendar.date(byAdding: .month, value: -back, to: thisMonth) else { return nil }
            let cells = WorkoutCalendar.monthCells(
                for: month,
                workouts: workouts,
                historyStart: historyStart,
                calendar: calendar
            )
            return ActivityMonth(
                id: month,
                label: month.formatted(.dateTime.month(.abbreviated)),
                weeks: WorkoutCalendar.weeks(cells)
            )
        }
    }

    private var recentWorkoutCount: Int {
        activityMonths
            .flatMap(\.weeks)
            .flatMap { $0 }
            .compactMap { $0 }
            .filter { if case .trained = $0.status { return true } else { return false } }
            .count
    }
}

#Preview {
    let context = SampleData.context
    let data = DashboardData(
        workouts: (try? context.fetch(FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? [],
        plans: (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? [],
        bodyWeightKg: 72,
        exercises: (try? context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))) ?? []
    )
    return NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(DashboardWidgetKind.allCases) { kind in
                    DashboardWidgetView(kind: kind, data: data, range: .constant(.twelveWeeks), exercise: SampleData.benchPress)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    .modelContainer(SampleData.container)
}
