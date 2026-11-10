//
//  PlanWeeklySetsView.swift
//  PLog
//
//  Planned working sets per muscle group per week (`PlanVolume`). Two surfaces:
//  `PlanWeeklySetsSection`, the summary at the bottom of `PlanDetailView` (total, share bar,
//  on-target counts, a two-column grid of every group), and `PlanWeeklySetsView`, pushed from
//  it, where each group opens to the slots it comes from, with a sets stepper on each so the plan can be adjusted without leaving the screen.
//  Plain stack content — the owning `NavigationStack` is `PlanListView`'s.
//

import SwiftUI
import SwiftData

// MARK: - Plan detail section

struct PlanWeeklySetsSection: View {
    let plan: WorkoutPlan

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let summary = PlanVolume.summary(for: plan)
        Section {
            if summary.isEmpty {
                Text("Add exercises to your days to see sets per muscle group.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(PlanVolume.setString(summary.weeklySets))
                            .font(.title.weight(.bold))
                            .monospacedDigit()
                        Text("sets a week")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    MuscleShareBar(groups: summary.groups)
                    HStack(spacing: 8) {
                        if summary.onTargetCount > 0 {
                            VolumeCountPill(status: .met, count: summary.onTargetCount)
                        }
                        if summary.belowCount > 0 {
                            VolumeCountPill(status: .below, count: summary.belowCount)
                        }
                        if summary.highCount > 0 {
                            VolumeCountPill(status: .high, count: summary.highCount)
                        }
                    }
                }
                .padding(.vertical, 4)

                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
                    ForEach(summary.groups) { volume in
                        GridCell(volume: volume)
                    }
                }
                .padding(.vertical, 6)
            }

            NavigationLink(value: PlanRoute.weeklySets(plan)) {
                Text("Details & Adjust")
            }
        } header: {
            HStack {
                Text("Weekly Sets")
                Spacer()
                Text("\(plan.daysPerWeek) day\(plan.daysPerWeek == 1 ? "" : "s") a week")
            }
        } footer: {
            Text("Target: 10–30 sets per muscle. Secondary muscles count half.")
        }
    }

    private var gridColumns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 20), GridItem(.flexible())]
    }

    private struct GridCell: View {
        let volume: PlanVolume.GroupVolume

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(volume.group.color)
                        .frame(width: 8, height: 8)
                    Text(volume.group.displayName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    Text(PlanVolume.setString(volume.weeklySets))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    if volume.status == .below || volume.status == .high {
                        Image(systemName: volume.status == .below ? "arrow.down.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(volume.status == .below ? .orange : .red)
                    }
                }
                .font(.subheadline)
                TargetBandBar(value: volume.weeklySets, color: volume.group.color, height: 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(volume.group.displayName)
            .accessibilityValue(accessibilityValue)
        }

        private var accessibilityValue: String {
            let sets = "\(PlanVolume.setString(volume.weeklySets)) sets a week"
            switch volume.status {
            case .below: return sets + ", below target"
            case .met: return sets + ", on target"
            case .high: return sets + ", high volume"
            case nil: return sets
            }
        }
    }
}

// MARK: - Weekly Sets screen

struct PlanWeeklySetsView: View {
    @Bindable var plan: WorkoutPlan

    /// Only one group open at a time, like the plan day's slots.
    @State private var expanded: MuscleGroup?
    /// Row order fixed when the screen opens, so a group doesn't jump while its sets are
    /// being stepped. Groups that appear later go to the end.
    @State private var order: [MuscleGroup] = []

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let summary = PlanVolume.summary(for: plan)
        List {
            Section {
                ForEach(ordered(summary.groups)) { volume in
                    DisclosureGroup(isExpanded: isExpanded(volume.group)) {
                        GroupContent(volume: volume)
                    } label: {
                        GroupLabel(volume: volume, isAccessibilitySize: typeSize.isAccessibilitySize)
                    }
                }
            } header: {
                Text("\(PlanVolume.setString(summary.weeklySets)) sets a week · \(plan.daysPerWeek) day\(plan.daysPerWeek == 1 ? "" : "s")")
            } footer: {
                Text("Target: 10–30 sets per muscle. Secondary muscles count half. Tap a muscle to change its sets per session. Set how often a day repeats on that day's screen.")
            }
        }
        .navigationTitle("Weekly Sets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if order.isEmpty { order = summary.groups.map(\.group) }
        }
    }

    private func isExpanded(_ group: MuscleGroup) -> Binding<Bool> {
        Binding(
            get: { expanded == group },
            set: { expanded = $0 ? group : nil }
        )
    }

    private func ordered(_ groups: [PlanVolume.GroupVolume]) -> [PlanVolume.GroupVolume] {
        guard !order.isEmpty else { return groups }
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return groups.enumerated()
            .sorted { (rank[$0.element.group] ?? order.count + $0.offset) < (rank[$1.element.group] ?? order.count + $1.offset) }
            .map(\.element)
    }
}

private struct GroupLabel: View {
    let volume: PlanVolume.GroupVolume
    let isAccessibilitySize: Bool

    var body: some View {
        HStack(spacing: 12) {
            MuscleGroupIcon(volume.group)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(volume.group.displayName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    if !isAccessibilitySize {
                        setsText
                    }
                }
                if isAccessibilitySize {
                    setsText
                }
                TargetBandBar(value: volume.weeklySets, color: volume.group.color, height: 6)
                if isAccessibilitySize, let status = volume.status {
                    VolumeStatusBadge(status: status, compact: true)
                }
            }
            if !isAccessibilitySize, let status = volume.status {
                VolumeStatusBadge(status: status, compact: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var setsText: some View {
        Text("\(PlanVolume.setString(volume.weeklySets))/wk")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

/// The slots a group's sets come from, each with a sets-per-session stepper. When the group
/// is below target, the slot that trains it most says how many more sets reach 10.
private struct GroupContent: View {
    let volume: PlanVolume.GroupVolume

    var body: some View {
        let suggestion = PlanVolume.suggestion(for: volume)
        VStack(alignment: .leading, spacing: 12) {
            if volume.contributions.isEmpty {
                Text("No exercise in this plan works it yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(volume.contributions) { contribution in
                ContributionRow(
                    contribution: contribution,
                    extraSets: contribution.isPrimary && suggestion?.slot === contribution.slot ? suggestion?.extraSets : nil
                )
            }
            // Only half-sets from other exercises: more sets of those is the wrong fix.
            if suggestion == nil, volume.status == .below, !volume.contributions.isEmpty {
                Label {
                    Text("Add a \(volume.group.displayName.lowercased()) exercise to reach 10")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ContributionRow: View {
    let contribution: PlanVolume.Contribution
    /// Sets per session to add here to reach the target, when this is the slot to change.
    let extraSets: Int?

    var body: some View {
        let slot = contribution.slot
        VStack(alignment: .leading, spacing: 2) {
            NumberStepper(
                title: slot.exercise?.name ?? "Exercise",
                intValue: setsBinding(for: slot),
                range: 1...20,
                style: .row
            )
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let extraSets {
                Label {
                    Text("Add \(extraSets) to reach 10")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    /// "Pull Day · 6 a week" / "Pull Day ×2 · half · 3 a week"; a superset's stepper is its rounds.
    private var detail: String {
        let day = contribution.dayName.isEmpty ? "Day" : contribution.dayName
        var parts = [contribution.timesPerWeek > 1 ? "\(day) ×\(contribution.timesPerWeek)" : day]
        if contribution.slot.supersetID != nil { parts.append("superset rounds") }
        if !contribution.isPrimary { parts.append("half") }
        parts.append("\(PlanVolume.setString(contribution.weeklySets)) a week")
        return parts.joined(separator: " · ")
    }

    /// A superset's rounds are shared, so stepping one member steps every slot in it, the
    /// same as `PlanSupersetRow`'s Rounds stepper.
    private func setsBinding(for slot: PlanExercise) -> Binding<Int> {
        Binding(
            get: { slot.targetSets },
            set: { newValue in
                if let id = slot.supersetID, let day = slot.planDay {
                    for member in day.exercises where member.supersetID == id {
                        member.targetSets = newValue
                    }
                } else {
                    slot.targetSets = newValue
                }
            }
        )
    }
}

// MARK: - Shared pieces

/// A track from 0 to 40 sets (or the value, if higher) with the 10–30 target band shaded
/// green and the value filled in the group's colour. Drawn in a `Canvas`: one view per bar
/// instead of a `GeometryReader` and three shapes, which matters when a stepper held down
/// redraws every row 12–25 times a second.
struct TargetBandBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            let scale = max(40, value)
            let track = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2)
            context.clip(to: track)
            context.fill(track, with: .style(.fill.tertiary))
            let low = size.width * HypertrophyTarget.minimumWeeklySets / scale
            let high = size.width * HypertrophyTarget.highWeeklySets / scale
            context.fill(Path(CGRect(x: low, y: 0, width: high - low, height: size.height)), with: .color(.green.opacity(0.28)))
            let filled = size.width * min(value / scale, 1)
            if filled > 0 {
                context.fill(
                    Path(roundedRect: CGRect(x: 0, y: 0, width: filled, height: size.height), cornerRadius: size.height / 2),
                    with: .color(color)
                )
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Every group's weighted share of the plan's sets, in the groups' colours.
private struct MuscleShareBar: View {
    let groups: [PlanVolume.GroupVolume]

    var body: some View {
        let trained = groups.filter { $0.weeklySets > 0 }
        let total = trained.reduce(0) { $0 + $1.weeklySets }
        Canvas { context, size in
            let gap: CGFloat = 2
            let available = max(size.width - gap * CGFloat(max(trained.count - 1, 0)), 0)
            context.clip(to: Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2))
            var x: CGFloat = 0
            for volume in trained {
                let width = available * volume.weeklySets / max(total, 1)
                context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)), with: .color(volume.group.color))
                x += width + gap
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

/// "8 on target" — colour on the symbol and the fill, label-coloured text (see `TrendBadge`).
private struct VolumeCountPill: View {
    let status: HypertrophyTarget.Status
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.primary)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        switch status {
        case .below: return "\(count) below"
        case .met: return "\(count) on target"
        case .high: return "\(count) high"
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

#Preview("Weekly Sets") {
    NavigationStack {
        PlanWeeklySetsView(plan: SampleData.plan)
    }
    .modelContainer(SampleData.container)
}

#Preview("Plan section") {
    NavigationStack {
        List {
            PlanWeeklySetsSection(plan: SampleData.plan)
        }
    }
    .modelContainer(SampleData.container)
}
