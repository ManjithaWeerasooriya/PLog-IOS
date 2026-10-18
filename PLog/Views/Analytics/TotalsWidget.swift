//
//  TotalsWidget.swift
//  PLog
//
//  All-time totals: workouts logged, working sets, and the current week streak. Pure layout
//  over the three numbers `DashboardWidgetView` hands it. Each figure gets an SF Symbol on an
//  accent-tinted tile (colour on the icon and fill, never the text — see AGENT.md), a big
//  rounded number and a quiet caption.
//
//  Small (2×2): three compact rows. Wide (4×2): three columns. Large (4×4): three roomy rows
//  with a one-line explanation each. Every layout falls back to plain rows when the type is
//  too large for it to fit.
//

import SwiftUI
import SwiftData

struct TotalsWidget: View {
    let workouts: Int
    let sets: Int
    let streak: Int
    var size: DashboardWidgetSize = .wide

    var body: some View {
        AnalyticsCard {
            switch size {
            case .small: smallLayout
            case .wide: wideLayout
            case .large: largeLayout
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Layouts

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(stats) { stat in
                CompactRow(stat: stat)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        if index > 0 {
                            Divider().padding(.vertical, 4)
                        }
                        ColumnStat(stat: stat)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(stats) { CompactRow(stat: $0) }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 {
                        Divider()
                    }
                    DetailRow(stat: stat)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Totals")
                .font(.headline)
            Text("All time")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }

    // MARK: - Data

    fileprivate struct Stat: Identifiable {
        let id: String
        let value: String
        let label: String
        /// For the compact rows, where a half-width card can't fit "Weeks streak" at large type.
        let shortLabel: String
        let detail: String
        let systemImage: String
    }

    private var stats: [Stat] {
        [
            Stat(
                id: "workouts",
                value: "\(workouts)",
                label: workouts == 1 ? "Workout" : "Workouts",
                shortLabel: workouts == 1 ? "Workout" : "Workouts",
                detail: "Sessions logged",
                systemImage: "figure.strengthtraining.traditional"
            ),
            Stat(
                id: "sets",
                value: WeightFormatter.volumeString(Double(sets)),
                label: sets == 1 ? "Set" : "Sets",
                shortLabel: sets == 1 ? "Set" : "Sets",
                detail: "Working sets, drops not counted",
                systemImage: "square.stack.3d.up.fill"
            ),
            Stat(
                id: "streak",
                value: "\(streak)",
                label: streak == 1 ? "Week streak" : "Weeks streak",
                shortLabel: "Wk streak",
                detail: "Weeks in a row with a workout",
                systemImage: "flame.fill"
            ),
        ]
    }
}

// MARK: - Pieces

/// The SF Symbol on a soft accent tile: the one place colour appears.
private struct StatIcon: View {
    let systemImage: String
    var textStyle: Font.TextStyle = .subheadline

    @ScaledMetric(relativeTo: .subheadline) private var tile: CGFloat = 28

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(textStyle, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: tile, height: tile)
            .background(
                Color.accentColor.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

/// Wide: icon over number over caption, centred in its third of the card.
private struct ColumnStat: View {
    let stat: TotalsWidget.Stat

    var body: some View {
        VStack(spacing: 6) {
            StatIcon(systemImage: stat.systemImage)
            Text(stat.value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(stat.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

/// Small, and the fallback everywhere: icon, number, caption on one line.
private struct CompactRow: View {
    let stat: TotalsWidget.Stat

    var body: some View {
        HStack(spacing: 10) {
            StatIcon(systemImage: stat.systemImage, textStyle: .footnote)
            // Caption beside the number while it fits; under it otherwise, never truncated.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    number
                    caption
                }
                VStack(alignment: .leading, spacing: 0) {
                    number
                    caption
                }
            }
            Spacer(minLength: 0)
        }
    }
}

extension CompactRow {
    fileprivate var number: some View {
        Text(stat.value)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    fileprivate var caption: some View {
        Text(stat.shortLabel)
            .accessibilityLabel(stat.label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

/// Large: label and a one-line explanation leading, the number big and trailing.
private struct DetailRow: View {
    let stat: TotalsWidget.Stat

    var body: some View {
        HStack(spacing: 12) {
            StatIcon(systemImage: stat.systemImage, textStyle: .body)
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.label)
                    .font(.subheadline.weight(.semibold))
                Text(stat.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            Text(stat.value)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - Previews

private struct TotalsPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(DashboardWidgetKind.totals.supportedSizes) { size in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(size.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        DashboardWidgetView(
                            kind: .totals,
                            data: SampleData.dashboardData,
                            range: .constant(.twelveWeeks),
                            size: size
                        )
                        .frame(width: size == .small ? 177 : nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .modelContainer(SampleData.container)
    }
}

#Preview("Light") {
    TotalsPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    TotalsPreviewGallery()
        .preferredColorScheme(.dark)
}

#Preview("Large type") {
    TotalsPreviewGallery()
        .dynamicTypeSize(.xxxLarge)
}
