//
//  TrendBadge.swift
//  PLog
//
//  A small tinted pill that shows whether a set/session beat the previous one. The colour
//  lives on the symbol and the capsule fill; the text stays label-coloured so it passes
//  contrast on any background (system green/red on white are ~2–3.5:1, well under AA).
//

import SwiftUI

struct TrendBadge: View {
    let trend: ProgressTrend
    var text: String? = nil

    var body: some View {
        if trend != .none, let symbol = trend.systemImage {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .foregroundStyle(trend.color)
                if let text {
                    Text(text)
                        .foregroundStyle(.primary)
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(trend.color.opacity(0.15), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text.map { "\(trend.accessibilityLabel), \($0)" } ?? trend.accessibilityLabel)
        }
    }
}

/// A tinted chip for a muscle-group category — same colour rule as `TrendBadge`.
struct CategoryChip: View {
    let category: MuscleGroup

    var body: some View {
        HStack(spacing: 4) {
            MuscleGroupIcon(category, size: 16, relativeTo: .caption)
            Text(category.displayName)
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
        .fixedSize()
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(category.color.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.displayName)
    }
}

/// Marks the user's strongest lift — same colour rule as `TrendBadge`. Orange rather than
/// yellow, which fails even as a fill/icon on a light card.
struct BestBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.orange)
            Text("Best")
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
        .fixedSize()
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Best lift")
    }
}

#Preview {
    VStack(spacing: 12) {
        BestBadge()
        TrendBadge(trend: .improved, text: "Improved")
        TrendBadge(trend: .regressed, text: "Down")
        TrendBadge(trend: .matched, text: "Same")
        TrendBadge(trend: .improved)
        CategoryChip(category: .chest)
        CategoryChip(category: .core)
    }
    .padding()
}
