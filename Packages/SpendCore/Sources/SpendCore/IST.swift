import Foundation

/// Calendar helpers pinned to India Standard Time; all day boundaries in SpendCore use this.
public enum IST {
    public static let timeZone = TimeZone(identifier: "Asia/Kolkata")!

    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.firstWeekday = 2
        return c
    }

    public static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    public static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    /// Whole calendar days from `a` to `b` (negative if b is earlier).
    public static func days(from a: Date, to b: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(a), to: startOfDay(b)).day ?? 0
    }

    public static func addDays(_ n: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: n, to: date)!
    }

    public static func isSameDay(_ a: Date, _ b: Date) -> Bool { calendar.isDate(a, inSameDayAs: b) }

    /// 1 = Monday … 7 = Sunday.
    public static func weekdayIndex(_ date: Date) -> Int {
        let w = calendar.component(.weekday, from: date) // 1 = Sunday
        return w == 1 ? 7 : w - 1
    }

    public static func dayOfMonth(_ date: Date) -> Int { calendar.component(.day, from: date) }
}
