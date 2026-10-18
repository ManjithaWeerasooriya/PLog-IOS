//
//  MuscleGroupIcon.swift
//  PLog
//
//  A muscle group's icon, sized to sit beside text of a given style.
//

import SwiftUI

/// Draws `MuscleGroup.icon` in a square that scales with Dynamic Type: illustrations in their
/// own colours, SF Symbols tinted with the group colour. Not for `Menu` items, which ignore
/// sizing — use `MuscleGroup.image` there.
struct MuscleGroupIcon: View {
    let group: MuscleGroup
    @ScaledMetric private var side: CGFloat

    init(_ group: MuscleGroup, size: CGFloat = 28, relativeTo textStyle: Font.TextStyle = .body) {
        self.group = group
        _side = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    var body: some View {
        Group {
            switch group.icon {
            case .illustration(let resource):
                Image(resource)
                    .resizable()
                    .scaledToFit()
            case .symbol(let name):
                Image(systemName: name)
                    .foregroundStyle(group.color)
            }
        }
        .frame(width: side, height: side)
        .accessibilityLabel(group.displayName)
    }
}

#Preview("All groups") {
    List(MuscleGroup.allCases) { group in
        HStack {
            Label {
                Text(group.displayName)
            } icon: {
                MuscleGroupIcon(group)
            }
            Spacer()
            CategoryChip(category: group)
        }
    }
}
