import SwiftUI
import TempoCore

struct WeekStripView: View {
    @EnvironmentObject var model: TempoModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(Theme.ui(14, .semibold))
                Spacer()
                Text(Format.duration(model.week.reduce(0) { $0 + $1.total })).font(Theme.mono(12)).foregroundStyle(Theme.muted)
            }
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(model.week.enumerated()), id: \.offset) { index, day in
                    if index > 0 { Spacer(minLength: 0) }
                    WeekDayColumn(day: day,
                                  isShown: model.calendar.isDate(day.day.start, inSameDayAs: model.shownDay),
                                  isFuture: day.day.start > model.now,
                                  calendar: model.calendar) { model.goToDay(day.day.start) }
                }
            }
        }
        .card()
    }
}

struct WeekDayColumn: View {
    let day: WeekDay
    let isShown: Bool
    let isFuture: Bool
    let calendar: Calendar
    let action: () -> Void

    private static let letters = ["S", "M", "T", "W", "T", "F", "S"]
    private var letter: String { Self.letters[calendar.component(.weekday, from: day.day.start) - 1] }
    private var date: String { String(calendar.component(.day, from: day.day.start)) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(letter).font(Theme.mono(10.5)).foregroundStyle(Theme.muted)
                ZStack(alignment: .bottom) {
                    Theme.track
                    VStack(spacing: 1) {
                        ForEach(CategoryID.allCases.reversed(), id: \.self) { c in
                            if let d = day.totals[c], d > 0 {
                                CategoryFill(category: c).frame(height: max(1, 84 * d / 36_000))
                            }
                        }
                    }
                }
                .frame(width: 12, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(date)
                    .font(Theme.mono(12, .semibold))
                    .frame(width: 26, height: 22)
                    .foregroundStyle(isShown ? Theme.panel : (day.total > 0 ? Theme.ink : Theme.muted))
                    .background(isShown ? Theme.ink : Color.clear, in: Capsule())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(day.total > 0 ? "\(Format.duration(day.total)) tracked on the \(date)" : "Nothing tracked on the \(date)")
    }
}
