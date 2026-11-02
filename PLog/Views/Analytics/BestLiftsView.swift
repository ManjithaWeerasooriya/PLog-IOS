//
//  BestLiftsView.swift
//  PLog
//
//  Best Lifts expanded, pushed from its card the way the calendar is pushed from Activity:
//  the selected exercise's progress on top, and every lift ranked beneath it to pick from —
//  like picking a date. It opens on the strongest lift, marked "Best". Search finds any
//  exercise in the library, logged or not. Plain stack content; the `Exercise` destination
//  behind "Full History" is registered in `AnalyticsView`.
//

import SwiftUI
import SwiftData

struct BestLiftsView: View {
    @State private var searchText = ""

    var body: some View {
        BestLiftsContent(searchText: searchText)
            // Always showing: finding any exercise is half of what this screen is for.
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search exercises"
            )
            .navigationTitle("Best Lifts")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Separate from `BestLiftsView` because `isSearching` / `dismissSearch` are only readable
/// beneath the `.searchable` modifier.
private struct BestLiftsContent: View {
    let searchText: String

    @Environment(\.isSearching) private var isSearching
    @Environment(\.dismissSearch) private var dismissSearch

    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var selectedID: PersistentIdentifier?
    @State private var metric: ExerciseHistoryViewModel.Metric = .oneRepMax

    private let topID = "selected"

    var body: some View {
        // Ranked once per update: every row and the header read it.
        let lifts = WorkoutStats.bestLifts(exercises: exercises, limit: .max)
        ScrollViewReader { proxy in
            List {
                if isSearching {
                    searchResults(lifts: lifts, proxy: proxy)
                } else if let selected = selectedExercise(lifts: lifts) {
                    selectedSection(for: selected, lifts: lifts)
                    rankingSection(lifts: lifts, selected: selected, proxy: proxy)
                } else {
                    ContentUnavailableView {
                        Label("No Exercises", systemImage: "dumbbell")
                    } description: {
                        Text("Add exercises in the Exercises tab, then log them to see your best lifts.")
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    // MARK: - Selected exercise

    private func selectedSection(for exercise: Exercise, lifts: [WorkoutStats.ExerciseBest]) -> some View {
        let points = WorkoutHistory.historyPoints(for: exercise)
        let best = lifts.first { $0.exercise === exercise }
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(exercise.name)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    if exercise === lifts.first?.exercise {
                        BestBadge()
                    }
                }
                HStack(spacing: 8) {
                    CategoryChip(category: exercise.category)
                    if let best {
                        TrendBadge(trend: best.trend)
                    }
                }
                if let best {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        BigStat(value: WeightFormatter.string(best.estimatedOneRepMax.roundedToTenth), unit: "kg", style: .title)
                        Text("best est. 1RM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
            .id(topID)

            if points.isEmpty {
                ExerciseHistoryEmptyView()
            } else {
                Picker("Metric", selection: $metric) {
                    ForEach(ExerciseHistoryViewModel.Metric.allCases) { metric in
                        Text(metric.shortLabel).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                ExerciseHistoryChart(points: points, metric: metric, color: exercise.category.color)
                    .padding(.vertical, 8)
            }

            NavigationLink(value: exercise) {
                Label("Full History", systemImage: "list.bullet.rectangle")
            }
        }
    }

    // MARK: - Lists

    private func rankingSection(
        lifts: [WorkoutStats.ExerciseBest],
        selected: Exercise,
        proxy: ScrollViewProxy
    ) -> some View {
        Section {
            if lifts.isEmpty {
                Text("Log a few sets and your strongest lifts will rank here.")
                    .foregroundStyle(.secondary)
            }
            ForEach(lifts) { lift in
                exerciseRow(
                    lift.exercise,
                    best: lift,
                    isTop: lift.id == lifts.first?.id,
                    selected: selected,
                    proxy: proxy
                )
            }
        } header: {
            Text("Ranked by estimated one-rep max")
        }
    }

    @ViewBuilder
    private func searchResults(lifts: [WorkoutStats.ExerciseBest], proxy: ScrollViewProxy) -> some View {
        let results = searchMatches(lifts: lifts)
        let selected = selectedExercise(lifts: lifts)
        if results.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(results) { exercise in
                    exerciseRow(
                        exercise,
                        best: lifts.first { $0.exercise === exercise },
                        isTop: exercise === lifts.first?.exercise,
                        selected: selected,
                        proxy: proxy
                    )
                }
            }
        }
    }

    private func exerciseRow(
        _ exercise: Exercise,
        best: WorkoutStats.ExerciseBest?,
        isTop: Bool,
        selected: Exercise?,
        proxy: ScrollViewProxy
    ) -> some View {
        Button {
            select(exercise, proxy: proxy)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                    Text(exercise.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isTop {
                    BestBadge()
                }
                if let best {
                    Text("\(WeightFormatter.string(best.estimatedOneRepMax.roundedToTenth)) kg")
                        .font(.subheadline.monospacedDigit())
                } else {
                    Text("Not logged")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(exercise === selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
        .accessibilityAddTraits(exercise === selected ? [.isSelected] : [])
    }

    private func select(_ exercise: Exercise, proxy: ScrollViewProxy) {
        withAnimation(.snappy) {
            selectedID = exercise.persistentModelID
        }
        dismissSearch()
        withAnimation(.snappy) {
            proxy.scrollTo(topID, anchor: .top)
        }
    }

    // MARK: - Derived data

    /// The user's pick, or the strongest lift until they pick one.
    private func selectedExercise(lifts: [WorkoutStats.ExerciseBest]) -> Exercise? {
        if let selectedID, let picked = exercises.first(where: { $0.persistentModelID == selectedID }) {
            return picked
        }
        return lifts.first?.exercise ?? exercises.first
    }

    /// Matching exercises, logged lifts first by strength, then the rest by name.
    private func searchMatches(lifts: [WorkoutStats.ExerciseBest]) -> [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let matches = { (exercise: Exercise) in
            query.isEmpty || exercise.name.localizedCaseInsensitiveContains(query)
        }
        let ranked = lifts.map(\.exercise).filter(matches)
        let unlogged = exercises.filter { exercise in
            matches(exercise) && !ranked.contains { $0 === exercise }
        }
        return ranked + unlogged
    }
}

private extension Double {
    /// Estimated 1RMs are rarely round — one decimal is plenty.
    var roundedToTenth: Double { (self * 10).rounded() / 10 }
}

#Preview {
    NavigationStack {
        BestLiftsView()
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseHistoryView(exercise: exercise)
            }
    }
    .modelContainer(SampleData.container)
}
