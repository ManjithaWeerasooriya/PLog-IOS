//
//  ActivityDotGrid.swift
//  PLog
//
//  A compact "did I train?" grid: one block per month, weeks as columns and weekdays as
//  rows, with a bright dot on every training day. The same cells drive the Calendar tab.
//

import SwiftUI
import SwiftData

struct ActivityMonth: Identifiable {
    /// Start of the month.
    let id: Date
    let label: String
    let weeks: [[CalendarDayCell?]]
}

struct ActivityDotGrid: View {
    let months: [ActivityMonth]

    // Deliberately not scaled with Dynamic Type: three months of weeks have to fit across
    // the card at every size, and the dots are a chart, not text.
    var dotSize: CGFloat = 7
    var spacing: CGFloat = 5

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(months) { month in
                VStack(spacing: 10) {
                    Text(month.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: spacing) {
                        ForEach(Array(month.weeks.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: spacing) {
                                ForEach(Array(week.enumerated()), id: \.offset) { _, cell in
                                    dot(for: cell)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func dot(for cell: CalendarDayCell?) -> some View {
        Circle()
            .fill(Self.color(for: cell))
            .frame(width: dotSize, height: dotSize)
    }

    /// Shared with `ActivityMonthDots`, so both grids mean the same thing by each shade.
    static func color(for cell: CalendarDayCell?) -> Color {
        guard let cell else { return .clear }
        switch cell.status {
        case .trained: return .accentColor
        case .rest: return Color.primary.opacity(0.18)
        case .pending: return Color.primary.opacity(0.18)
        case .inactive: return Color.primary.opacity(0.06)
        }
    }
}

/// One month as a calendar — weekdays across, weeks down — in dots, for the small Activity
/// widget. Same colours as `ActivityDotGrid`; today gets an accent ring, as in Calendar.
struct ActivityMonthDots: View {
    let cells: [CalendarDayCell?]
    var dotSize: CGFloat = 9
    var rowSpacing: CGFloat = 6

    private let calendar = Calendar.current

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: rowSpacing) {
            GridRow {
                // Enumerated: "T" and "S" each appear twice.
                ForEach(Array(WorkoutCalendar.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                GridRow {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, cell in
                        Circle()
                            .fill(ActivityDotGrid.color(for: cell))
                            .overlay {
                                if cell?.isToday == true {
                                    Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                                }
                            }
                            .frame(width: dotSize, height: dotSize)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Rows of 7, the last padded so every row has a cell per weekday.
    private var weeks: [[CalendarDayCell?]] {
        stride(from: 0, to: cells.count, by: 7).map { start in
            let row = Array(cells[start..<min(start + 7, cells.count)])
            return row + Array(repeating: nil, count: 7 - row.count)
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let months = (0..<3).reversed().compactMap { back -> ActivityMonth? in
        guard let month = calendar.date(byAdding: .month, value: -back, to: .now) else { return nil }
        let start = WorkoutCalendar.startOfMonth(month)
        let cells = WorkoutCalendar.monthCells(
            for: start,
            workouts: [SampleData.recentDay],
            historyStart: calendar.date(byAdding: .month, value: -2, to: .now)
        )
        return ActivityMonth(
            id: start,
            label: start.formatted(.dateTime.month(.abbreviated)),
            weeks: WorkoutCalendar.weeks(cells)
        )
    }
    return AnalyticsCard {
        ActivityDotGrid(months: months)
    }
    .padding()
    .modelContainer(SampleData.container)
}
