//
//  MuscleGroup.swift
//  PLog
//
//  The muscle-group category used to organize the master exercise list.
//

import SwiftUI

/// A muscle-group category for an `Exercise`.
///
/// Stored on `Exercise` as a `Codable` enum. SwiftData persists `RawRepresentable`/`Codable`
/// enums directly, so we can use a strongly-typed property instead of a raw `String`.
enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest
    case back
    /// Raw value kept as "legs" (the case's old name) so any exercise already persisted
    /// with that category still decodes correctly — only the label changed.
    case quads = "legs"
    case hamstrings
    case glutes
    case calves
    case shoulders
    case rearDelts
    /// Raw value kept as "arms" (the case's old name) so any exercise already persisted
    /// with that category still decodes correctly — only the label changed.
    case biceps = "arms"
    case traps
    case triceps
    case forearms
    case core
    case cardio
    case fullBody
    case other

    var id: String { rawValue }

    /// Human-facing label shown in the UI.
    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .shoulders: return "Shoulders"
        case .rearDelts: return "Rear Delts"
        case .biceps: return "Biceps"
        case .traps: return "Traps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .core: return "Core"
        case .cardio: return "Cardio"
        case .fullBody: return "Full Body"
        case .other: return "Other"
        }
    }

    /// How a group's icon is drawn: an illustration from `Assets.xcassets/MuscleGroups`
    /// (full colour, so never tinted), or an SF Symbol tinted with `color` (only Other).
    enum Icon {
        case illustration(ImageResource)
        case symbol(String)
    }

    /// The group's visual tag. Draw it with `MuscleGroupIcon`, or `image` inside a `Menu`.
    var icon: Icon {
        switch self {
        case .chest: return .illustration(.muscleChest)
        case .back: return .illustration(.muscleBack)
        case .quads: return .illustration(.muscleQuads)
        case .hamstrings: return .illustration(.muscleHamstrings)
        case .glutes: return .illustration(.muscleGlutes)
        case .calves: return .illustration(.muscleCalves)
        case .shoulders: return .illustration(.muscleShoulders)
        case .rearDelts: return .illustration(.muscleRearDelts)
        case .biceps: return .illustration(.muscleBiceps)
        case .traps: return .illustration(.muscleTraps)
        case .triceps: return .illustration(.muscleTriceps)
        case .forearms: return .illustration(.muscleForearms)
        case .core: return .illustration(.muscleCore)
        case .cardio: return .illustration(.muscleCardio)
        case .fullBody: return .illustration(.muscleFullBody)
        case .other: return .symbol("questionmark.circle")
        }
    }

    /// The icon as a plain `Image` at its natural size (illustrations are 28 pt). For `Menu`
    /// items, which ignore `.resizable()`/`.frame` — everywhere else use `MuscleGroupIcon`.
    var image: Image {
        switch icon {
        case .illustration(let resource): return Image(resource)
        case .symbol(let name): return Image(systemName: name)
        }
    }

    /// Accent color used to tint category chips and chart legends.
    var color: Color {
        switch self {
        case .chest: return .red
        case .back: return .blue
        case .quads: return .green
        // Every system hue is taken, so the split-out groups use asset shades of their
        // parent's hue (the colour their illustration highlights) that stay distinct in the donut.
        case .hamstrings: return Color(.muscleColorHamstrings)
        case .glutes: return Color(.muscleColorGlutes)
        case .calves: return Color(.muscleColorCalves)
        case .shoulders: return .orange
        case .rearDelts: return Color(.muscleColorRearDelts)
        case .biceps: return .purple
        case .traps: return .indigo
        case .triceps: return .mint
        case .forearms: return .cyan
        case .core: return .brown  // not yellow: unusable even as a fill/icon on a light card
        case .cardio: return .pink
        case .fullBody: return .teal
        case .other: return .gray
        }
    }
}
