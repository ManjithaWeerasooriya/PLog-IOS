//
//  MuscleGroupsView.swift
//  PLog
//
//  Muscle Groups expanded, pushed from its card the way the calendar and Best Lifts are:
//  a large donut of working sets per muscle group (tap a slice to read it), every group
//  labelled with its sets and share, then each group's weekly sets against the hypertrophy
//  target (`HypertrophyTarget`). Opens on the card's range so the totals match it; "This
//  Week" is offered too. Plain stack content — the owning `NavigationStack` is
//  `AnalyticsView`'s. Totals come from `WorkoutStats.muscleGroupSplit`, the card's own code.
//

import SwiftUI
import SwiftData
import Charts

/// The periods this screen offers: the widget's ranges plus the current week alone.
enum MuscleSplitPeriod: Hashable, CaseIterable, Identifiable {
    case thisWeek
    case range(AnalyticsRange)

    static var allCases: [MuscleSplitPeriod] {
        [.thisWeek] + AnalyticsRange.allCases.map { .range($0) }
    }

    var id: Int { weeks }

    var weeks: Int {
        switch self {
        case .thisWeek: return 1
        case .range(let range): return range.weeks
        }
    }

    /// Segment label; fits four across a phone.
    var shortLabel: String {
        switch self {
        case .thisWeek: return "This Week"
        case .range(let range): return "\(range.weeks)W"
        }
    }

    var description: String {
        switch self {
        case .thisWeek: return "this week"
        case .range(let range): return range.label.lowercased()
        }
    }
}

struct MuscleGroupsView: View {
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workouts: [WorkoutDay]

    @State private var period: MuscleSplitPeriod
    /// The angle value under the user's finger on the donut, from `chartAngleSelection`.
    @State private var selectedAngle: Double?

    private let calendar = Calendar.current

    // A chart, not text: fixed so the legend can sit under it at every type size.
    private let donutSize: CGFloat = 240

    init(range: AnalyticsRange) {
        _period = State(initialValue: .range(range))
    }

    var body: some View {
        let split = WorkoutStats.muscleGroupSplit(workouts: workouts, weeks: period.weeks, calendar: calendar)
        let total = split.reduce(0) { $0 + $1.sets }

        List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(MuscleSplitPeriod.allCases) { period in
                        Text(period.shortLabel).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if total == 0 {
                ContentUnavailableView {
                    Label("No Sets Logged", systemImage: "chart.pie")
                } description: {
                    Text("Log a workout and its working sets will be split by muscle group here.")
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    donut(split, total: total)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    ForEach(split) { share in
                        shareRow(share, total: total)
                    }
                } header: {
                    Text("Working sets, \(period.description)")
                }

                Section {
                    ForEach(volumeRows(split)) { row in
                        volumeRow(row)
                    }
                } header: {
                    Text("Weekly sets")
                } footer: {
                    Text(volumeFooter)
                }
            }
        }
        .navigationTitle("Muscle Groups")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: period)
    }

    // MARK: - Donut

    private func donut(_ split: [WorkoutStats.MuscleGroupShare], total: Double) -> some View {
        let selected = selectedShare(in: split)
        return Chart(split) { share in
            SectorMark(
                angle: .value("Sets", share.sets),
                innerRadius: .ratio(0.62),
                outerRadius: selected?.group == share.group ? .ratio(1) : .ratio(0.94),
                angularInset: 1.5
            )
            .foregroundStyle(share.group.color)
            .opacity(selected == nil || selected?.group == share.group ? 1 : 0.4)
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .frame(width: donutSize, height: donutSize)
        .overlay {
            VStack(spacing: 2) {
                if let selected {
                    Text(selected.group.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(WorkoutStats.setCountString(selected.sets))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("sets · \(percent(selected.sets, of: total))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(WorkoutStats.setCountString(total))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text(total == 1 ? "set" : "sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .frame(width: donutSize * 0.55)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel("Working sets by muscle group, \(WorkoutStats.setCountString(total)) in total")
    }

    /// `chartAngleSelection` reports a position along the cumulative set count; find the slice.
    private func selectedShare(in split: [WorkoutStats.MuscleGroupShare]) -> WorkoutStats.MuscleGroupShare? {
        guard let selectedAngle else { return nil }
        var running = 0.0
        for share in split {
            running += share.sets
            if selectedAngle < running { return share }
        }
        return split.last
    }

    private func shareRow(_ share: WorkoutStats.MuscleGroupShare, total: Double) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(share.group.color)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(share.group.displayName)
            Spacer()
            Text("\(WorkoutStats.setCountString(share.sets)) set\(share.sets == 1 ? "" : "s")")
                .monospacedDigit()
            Text(percent(share.sets, of: total))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Weekly volume

    private struct VolumeRow: Identifiable {
        let group: MuscleGroup
        let weeklySets: Double
        var id: MuscleGroup { group }
        var status: HypertrophyTarget.Status? {
            HypertrophyTarget.applies(to: group) ? HypertrophyTarget.status(weeklySets: weeklySets) : nil
        }
    }

    /// Every muscle group, trained ones first by volume, so an untrained group shows as
    /// below target instead of silently missing. Groups the target doesn't apply to (Cardio,
    /// Full Body, Other) only appear when they have sets, and without a badge.
    private func volumeRows(_ split: [WorkoutStats.MuscleGroupShare]) -> [VolumeRow] {
        let weeks = Double(period.weeks)
        let trained = split.map { VolumeRow(group: $0.group, weeklySets: $0.sets / weeks) }
        let untrained = MuscleGroup.allCases
            .filter { group in HypertrophyTarget.applies(to: group) && !split.contains { $0.group == group } }
            .map { VolumeRow(group: $0, weeklySets: 0) }
        return trained + untrained
    }

    private func volumeRow(_ row: VolumeRow) -> some View {
        HStack(spacing: 12) {
            MuscleGroupIcon(row.group)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.group.displayName)
                Text("\(weeklyLabel(row.weeklySets)) sets / week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            if let status = row.status {
                VolumeStatusBadge(status: status)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Whole numbers for a single week; one decimal for a weekly average.
    private func weeklyLabel(_ value: Double) -> String {
        if period == .thisWeek || value == value.rounded() {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private var volumeFooter: String {
        let low = Int(HypertrophyTarget.minimumWeeklySets)
        let high = Int(HypertrophyTarget.highWeeklySets)
        let base = "Target: \(low)–\(high) working sets per muscle group per week. Sets count fully toward an exercise's primary groups and as half a set toward secondary ones. Drop sets aren't counted."
        if period == .thisWeek {
            return base + " This week is still in progress."
        }
        return base + " Weekly figures are averages over \(period.description), including this week so far."
    }

    private func percent(_ part: Double, of total: Double) -> String {
        "\(Int((part / max(total, 1) * 100).rounded()))%"
    }
}

/// Met / below / high against `HypertrophyTarget`. The colour sits on the symbol and the
/// capsule fill, and the text stays label-coloured, like `TrendBadge`.
struct VolumeStatusBadge: View {
    let status: HypertrophyTarget.Status

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.primary)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        switch status {
        case .below: return "Below target"
        case .met: return "On target"
        case .high: return "High volume"
        }
    }

    private var systemImage: String {
        switch status {
        case .below: return "arrow.down.circle.fill"
        case .met: return "checkmark.circle.fill"
        case .high: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .below: return .orange
        case .met: return .green
        case .high: return .red
        }
    }
}

#Preview("Light") {
    NavigationStack {
        MuscleGroupsView(range: .twelveWeeks)
    }
    .modelContainer(SampleData.container)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        MuscleGroupsView(range: .twelveWeeks)
    }
    .modelContainer(SampleData.container)
    .preferredColorScheme(.dark)
}
