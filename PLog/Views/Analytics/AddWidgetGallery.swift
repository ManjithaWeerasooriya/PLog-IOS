//
//  AddWidgetGallery.swift
//  PLog
//
//  The ＋ sheet in Progress edit mode, laid out like the iOS widget gallery: each widget the
//  user can still add, rendered for real by `DashboardWidgetView` and scaled down. Previews
//  use the user's own data; before their first workout they use the `SampleData` fixture so
//  the gallery shows what each widget is for rather than a page of empty states. Tapping a
//  preview adds that widget at its default size (resize it later from its context menu)
//  and closes the sheet.
//

import SwiftUI
import SwiftData

struct AddWidgetGallery: View {
    @Environment(\.dismiss) private var dismiss

    let data: DashboardData
    let canAdd: (DashboardWidgetKind) -> Bool
    let onAdd: (DashboardWidgetKind, Exercise?) -> Void

    /// Card width on a phone (402-pt screen less 16-pt margins), drawn at 80%.
    private let cardWidth: CGFloat = 370
    private let compactWidth: CGFloat = 177
    private let scale: CGFloat = 0.8

    /// The same row unit the dashboard uses, so a preview is the card's real size.
    @ScaledMetric(relativeTo: .body) private var gridUnit: CGFloat = DashboardGrid.baseUnit

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if usesSampleData {
                        Text("Previews show sample data until you log a workout.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    ForEach(DashboardWidgetKind.allCases.filter(canAdd)) { kind in
                        galleryItem(kind)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func galleryItem(_ kind: DashboardWidgetKind) -> some View {
        Button {
            onAdd(kind, kind.needsExercise ? exerciseToAdd : nil)
            dismiss()
        } label: {
            VStack(spacing: 10) {
                ScaledWidgetPreview(
                    width: kind.defaultSize == .small ? compactWidth : cardWidth,
                    height: DashboardGrid.height(of: kind.defaultSize, unit: gridUnit),
                    scale: scale
                ) {
                    DashboardWidgetView(
                        kind: kind,
                        data: previewData,
                        range: .constant(.twelveWeeks),
                        size: kind.defaultSize,
                        exercise: kind.needsExercise ? previewExercise : nil
                    )
                }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                VStack(spacing: 2) {
                    Text(kind.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(kind.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add \(kind.title)")
        .accessibilityHint(kind.summary)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Data

    private var usesSampleData: Bool { data.workouts.isEmpty }

    private var previewData: DashboardData {
        guard usesSampleData else { return data }
        let context = SampleData.context
        return DashboardData(
            workouts: (try? context.fetch(FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? [],
            plans: (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? [],
            bodyWeightKg: 72,
            exercises: (try? context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))) ?? []
        )
    }

    /// What Exercise Progress starts on: the user's strongest lift, else any logged exercise,
    /// else the first in their library. Changeable afterwards from the card's context menu.
    private var exerciseToAdd: Exercise? {
        WorkoutStats.bestLifts(exercises: data.exercises, limit: 1).first?.exercise
            ?? data.exercises.first { !$0.entries.isEmpty }
            ?? data.exercises.first
    }

    private var previewExercise: Exercise? {
        usesSampleData ? SampleData.benchPress : exerciseToAdd
    }
}

/// Lays a card out at its full grid size, then draws it scaled down — the widget gallery
/// look, with real content rather than a mock. Not interactive. The size is known up front
/// (grid cells are fixed), so nothing is measured: an earlier version measured the card with
/// a `GeometryReader` and stored the height in `@State`, which looped forever once cards
/// started filling their cell's height.
private struct ScaledWidgetPreview<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    let scale: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: width, height: height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width * scale, height: height * scale, alignment: .topLeading)
            .allowsHitTesting(false)
    }
}

#Preview {
    let context = SampleData.context
    AddWidgetGallery(
        data: DashboardData(
            workouts: (try? context.fetch(FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? [],
            plans: (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? [],
            bodyWeightKg: 72,
            exercises: (try? context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))) ?? []
        ),
        canAdd: { _ in true },
        onAdd: { _, _ in }
    )
    .modelContainer(SampleData.container)
}
