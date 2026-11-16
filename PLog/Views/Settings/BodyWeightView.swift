//
//  BodyWeightView.swift
//  PLog
//
//  The body-weight log: log today's weight, see the trend, and remove a wrong reading.
//  Pushed from Settings and from the Body Weight card on Progress — plain stack content, so
//  it never wraps itself in a `NavigationStack`. Weight going up or down isn't good or bad
//  here (that depends on whether the user is bulking or cutting), so the change is stated
//  without the green/red of a `TrendBadge`.
//

import SwiftUI
import SwiftData
import Charts

struct BodyWeightView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.weightUnit) private var unit

    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]
    @Query private var profiles: [UserProfile]

    /// The stepper's value once the user has touched it; until then it shows the latest
    /// reading (or a neutral starting point), so nothing is written just by looking.
    @State private var draft: Double?
    /// Bumped when a reading is logged, for the haptic.
    @State private var loggedCount = 0

    private var todaysEntry: BodyWeightEntry? {
        entries.first { Calendar.current.isDateInToday($0.date) }
    }

    private var value: Double {
        draft ?? entries.first?.weight ?? profiles.first?.weightKg ?? unit.defaultBodyWeight
    }

    var body: some View {
        // Read once per redraw; both sections below use it.
        let readings = BodyWeightLog.readings(entries)
        return List {
            Section {
                NumberStepper(
                    title: "Today",
                    value: Binding(get: { value }, set: { draft = $0 }),
                    step: unit.bodyWeightStep,
                    range: unit.bodyWeightRange,
                    unit: unit.symbol,
                    style: .row
                )
                Button(todaysEntry == nil ? "Log Today's Weight" : "Update Today's Weight", action: log)
                    .disabled(todaysEntry?.weight == value)
            } footer: {
                Text("Weigh at the same time of day so readings compare. First thing in the morning is the usual choice.")
            }

            if readings.count >= 2 {
                Section {
                    trend(readings)
                }
            }

            if !entries.isEmpty {
                Section("Readings") {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.date.mediumDayLabel)
                            Spacer()
                            Text(unit.string(entry.weight))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Body Weight")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: loggedCount)
    }

    // MARK: - Trend

    private func trend(_ readings: [BodyWeightLog.Reading]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let change = BodyWeightLog.change(in: readings) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(changeText(change.amount))
                        .font(.headline)
                    Text("Since \(change.since.shortDateLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Chart(readings) { reading in
                LineMark(
                    x: .value("Date", reading.date),
                    y: .value("Weight", reading.weight)
                )
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Date", reading.date),
                    y: .value("Weight", reading.weight)
                )
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)
            // Axis labels collide above this, as on every chart in the app.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Body weight over time")
            .accessibilityValue(chartSummary(readings))
        }
        .padding(.vertical, 8)
    }

    /// "+1.2 kg", "−0.8 kg", "No change".
    private func changeText(_ amount: Double) -> String {
        guard amount != 0 else { return "No change" }
        return "\(amount > 0 ? "+" : "−")\(unit.string(abs(amount)))"
    }

    private func chartSummary(_ readings: [BodyWeightLog.Reading]) -> String {
        guard let first = readings.first, let last = readings.last else { return "" }
        return "\(readings.count) readings, from \(WeightFormatter.string(first.weight)) to \(WeightFormatter.string(last.weight)) \(unit.spokenName)"
    }

    // MARK: - Actions

    private func log() {
        withAnimation(.snappy) {
            _ = BodyWeightLog.record(value, in: context)
        }
        loggedCount += 1
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            BodyWeightLog.delete(entries[index], in: context)
        }
    }
}

#Preview {
    NavigationStack {
        BodyWeightView()
    }
    .modelContainer(SampleData.container)
}
