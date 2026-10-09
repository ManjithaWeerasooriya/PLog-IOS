//
//  SupersetViews.swift
//  PLog
//
//  The pieces that draw a superset as one merged block — a lettered node per exercise on a
//  chain that runs down the block — and the menu actions that build supersets. Shared by
//  the session screen and the plan-day editor.
//

import SwiftUI

/// "A" in a ringed circle: names an exercise within its superset, on the chain in the
/// header and beside each of its sets in the rounds below. Colour on the ring and fill,
/// the letter label-coloured — the same contrast rule as the app's pills.
struct SupersetBadge: View {
    let letter: String

    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 22

    var body: some View {
        Text(letter)
            .font(.caption.weight(.bold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background(Color.accentColor.opacity(0.15), in: Circle())
            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

/// One exercise on a superset's chain.
struct SupersetChainItem: Identifiable {
    let id: AnyHashable
    let letter: String
    let name: String
    let category: MuscleGroup?
    /// Trailing summary, e.g. "× 8" in a plan.
    var detail: String?
}

/// The exercises of a superset stacked on a chain: each node is a `SupersetBadge` and a
/// line runs from it down to the next one, so the block reads as one linked unit.
struct SupersetChain: View {
    let items: [SupersetChainItem]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    // The connector fills the rest of this item's height, reaching the
                    // next node exactly however tall the name and chip wrap.
                    VStack(spacing: 0) {
                        SupersetBadge(letter: item.letter)
                        if index < items.count - 1 {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.5))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    content(for: item)
                        .padding(.bottom, index < items.count - 1 ? 14 : 0)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func content(for item: SupersetChainItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if typeSize.isAccessibilitySize {
                name(item)
                detail(item)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    name(item)
                    Spacer(minLength: 8)
                    detail(item)
                }
            }
            if let category = item.category {
                CategoryChip(category: category)
            }
        }
    }

    private func name(_ item: SupersetChainItem) -> some View {
        Text(item.name)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func detail(_ item: SupersetChainItem) -> some View {
        if let detail = item.detail {
            Text(detail)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// "🔗 Superset · 3 rounds" — the caption line that heads a merged block.
struct SupersetTitle: View {
    let rounds: Int

    var body: some View {
        Label {
            Text("Superset · ^[\(rounds) round](inflect: true)")
        } icon: {
            Image(systemName: "link")
                .foregroundStyle(.tint)
        }
        .font(.caption.weight(.semibold))
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
    }
}

/// What a row (plain exercise or whole superset) may do to form supersets; `nil` actions
/// aren't offered. The parent works these out because only it sees the neighbouring rows.
struct SupersetActions {
    var joinPrevious: (() -> Void)?
    var joinNext: (() -> Void)?
    /// Picks an exercise and links it in after this row.
    var addExercise: (() -> Void)?

    static let none = SupersetActions()
}

/// The superset-building items for a context menu.
struct SupersetMenuItems: View {
    let actions: SupersetActions
    /// "Superset with New Exercise…" on a plain row; "Add Exercise to Superset…" on a block.
    var isSuperset = false

    var body: some View {
        if let addExercise = actions.addExercise {
            Button(action: addExercise) {
                Label(
                    isSuperset ? "Add Exercise to Superset…" : "Superset with New Exercise…",
                    systemImage: "link.badge.plus"
                )
            }
        }
        if let joinPrevious = actions.joinPrevious {
            Button(action: joinPrevious) {
                Label("Superset with Previous", systemImage: "arrow.up")
            }
        }
        if let joinNext = actions.joinNext {
            Button(action: joinNext) {
                Label("Superset with Next", systemImage: "arrow.down")
            }
        }
    }
}

extension View {
    /// The same actions for VoiceOver, which can't reach a context menu as easily.
    func supersetAccessibilityActions(_ actions: SupersetActions, isSuperset: Bool = false) -> some View {
        accessibilityActions {
            SupersetMenuItems(actions: actions, isSuperset: isSuperset)
        }
    }
}

#Preview {
    List {
        VStack(alignment: .leading, spacing: 12) {
            SupersetTitle(rounds: 3)
            SupersetChain(items: [
                .init(id: 0, letter: "A", name: "Bench Press", category: .chest, detail: "× 8"),
                .init(id: 1, letter: "B", name: "Barbell Row", category: .back, detail: "× 10"),
            ])
        }
        .padding(.vertical, 4)
    }
}
