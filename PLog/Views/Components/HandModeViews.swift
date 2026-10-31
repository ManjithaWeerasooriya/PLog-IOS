//
//  HandModeViews.swift
//  PLog
//
//  Small pieces for one-hand / two-hand exercises: the tag beside an exercise's chip and
//  the context-menu item that switches modes.
//

import SwiftUI

/// "One hand" beside a one-hand exercise's chip — a neutral capsule, since it's a fact about
/// how the sets were done, not a judgement. Draws nothing for two hands, the default.
struct HandModeTag: View {
    let mode: HandMode

    var body: some View {
        // An HStack rather than a `Label`: inside a List row's button, the label style
        // dropped the title and left only the icon.
        if mode == .single {
            HStack(spacing: 4) {
                Image(systemName: "hand.raised")
                Text(mode.displayName)
            }
            .foregroundStyle(.primary)
            .lineLimit(1)
            .fixedSize()
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(mode.displayName)
        }
    }
}

/// "Switch to One Hand" / "Switch to Two Hands" — for an exercise's context menu on the
/// session screen and in a superset's per-exercise submenu.
struct HandModeMenuItem: View {
    let current: HandMode
    let onChange: (HandMode) -> Void

    var body: some View {
        let other: HandMode = current == .single ? .both : .single
        Button {
            onChange(other)
        } label: {
            Label("Switch to \(other.displayName)", systemImage: "arrow.left.arrow.right")
        }
    }
}

#Preview {
    HStack {
        CategoryChip(category: .back)
        HandModeTag(mode: .single)
    }
}
