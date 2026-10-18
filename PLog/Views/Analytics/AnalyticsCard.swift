//
//  AnalyticsCard.swift
//  PLog
//
//  The rounded tile every Analytics widget sits in, plus the small title/subtitle header
//  most of them share. Kept as one component so the dashboard reads as a single grid.
//

import SwiftUI

struct AnalyticsCard<Content: View>: View {
    private let content: Content

    /// Set by the dashboard grid: the cell's height. Outside the grid (Train's hero card)
    /// it's `nil` and the card is as tall as its content.
    @Environment(\.analyticsCardHeight) private var gridHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if let gridHeight {
            // Exactly the cell's height, so the grid lines up and charts can stretch to fill;
            // at accessibility type sizes the cell height becomes a minimum and text wins.
            let exact = !dynamicTypeSize.isAccessibilitySize
            tile
                .frame(maxWidth: .infinity, minHeight: exact ? nil : gridHeight, maxHeight: .infinity, alignment: .topLeading)
                .background(background)
                .frame(height: exact ? gridHeight : nil)
        } else {
            tile
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(background)
        }
    }

    private var tile: some View {
        content.padding(16)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

private struct AnalyticsCardHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    /// The dashboard grid cell height an `AnalyticsCard` fills; `nil` outside the grid.
    var analyticsCardHeight: CGFloat? {
        get { self[AnalyticsCardHeightKey.self] }
        set { self[AnalyticsCardHeightKey.self] = newValue }
    }
}

/// "Volume lifted / Last 7 days" style header used at the top of a card.
struct AnalyticsCardTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A big number with a small trailing unit, e.g. "190 kg". Sized by text style, not points,
/// so it follows Dynamic Type like everything else.
struct BigStat: View {
    let value: String
    var unit: String? = nil
    var style: Font.TextStyle = .largeTitle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(style, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let unit {
                Text(unit)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A ring that fills clockwise from the top, with arbitrary content in the middle.
struct ProgressRing<Content: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 6
    private let content: Content

    init(progress: Double, lineWidth: CGFloat = 6, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: progress)
            content
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AnalyticsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ProgressRing(progress: 0.66) {
                            Text("2").font(.title2.bold())
                        }
                        .frame(width: 64, height: 64)
                        AnalyticsCardTitle(title: "Push / Pull / Legs", subtitle: "Next: Leg Day")
                    }
                }
                AnalyticsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        BigStat(value: "70", unit: "kg")
                        AnalyticsCardTitle(title: "Body weight", subtitle: "From your profile")
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
