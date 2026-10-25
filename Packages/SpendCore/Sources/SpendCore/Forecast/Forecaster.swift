import Foundation

/// Interpretable spend forecast: per-category base rate × weekday × top-up phase × event tags.
public struct ForecastModel: Hashable, Sendable {
    public enum Mode: String, Sendable { case noData, pace, baseline }

    public var mode: Mode
    /// Average daily spend per category.
    var base: [String: Double]
    /// [category][weekday 1…7]
    var dow: [String: [Int: Double]]
    /// [category][phase bucket 0…3]
    var phase: [String: [Int: Double]]
    /// [category][tag]
    var tagFactors: [String: [String: Double]]
    var lastTopUp: Date?
    /// Multiplier from the 80th percentile of actual/expected; makes projections deliberately pessimistic.
    public var pessimism: Double
    public var historyDays: Int

    public var knownTags: Set<String> { Set(tagFactors.values.flatMap(\.keys)) }

    public func expected(on day: Date, tags: Set<String> = []) -> Money {
        Money(paise: Int(expectedValue(on: day, tags: tags).rounded()))
    }

    func expectedValue(on day: Date, tags: Set<String>) -> Double {
        let w = IST.weekdayIndex(day)
        let p = Forecaster.phaseBucket(day: day, lastTopUp: lastTopUp)
        return base.reduce(0) { total, entry in
            let (cat, b) = entry
            var v = b * (dow[cat]?[w] ?? 1) * (phase[cat]?[p] ?? 1)
            for t in tags { v *= tagFactors[cat]?[t.lowercased()] ?? 1 }
            return total + v
        }
    }

    /// Extra spend a tag adds over the given days, versus the same days untagged.
    public func tagExtraCost(_ tag: String, on days: [Date]) -> Money {
        let extra = days.reduce(0.0) { $0 + expectedValue(on: $1, tags: [tag]) - expectedValue(on: $1, tags: []) }
        return Money(paise: Int(max(0, extra).rounded()))
    }
}

public enum Forecaster {
    public static let minimumBaselineDays = 28
    static let shrinkage = 2.0

    public static func fit(transactions: [TransactionRecord], tags: [DayTag], topUps: [Date], today: Date) -> ForecastModel {
        let todayStart = IST.startOfDay(today)
        let spends = transactions.filter { $0.spending.isPositive && IST.startOfDay($0.date) < todayStart }
        let lastTopUp = topUps.filter { $0 <= today }.max()
        guard let first = spends.map(\.date).min() else {
            return ForecastModel(mode: .noData, base: [:], dow: [:], phase: [:], tagFactors: [:],
                                 lastTopUp: lastTopUp, pessimism: 1.25, historyDays: 0)
        }

        let days = (0..<max(1, IST.days(from: first, to: todayStart))).map { IST.addDays($0, to: IST.startOfDay(first)) }
        var daily: [Date: [String: Double]] = [:]
        for t in spends {
            daily[IST.startOfDay(t.date), default: [:]][t.category ?? "Uncategorised", default: 0] += Double(t.spending.paise)
        }
        var tagsByDay: [Date: Set<String>] = [:]
        for t in tags { tagsByDay[t.day, default: []].insert(t.tag) }

        if days.count < minimumBaselineDays {
            // Pace: spending since last top-up (or whole history) per elapsed day, as one bucket.
            let windowStart = lastTopUp.map(IST.startOfDay).flatMap { $0 > days[0] ? $0 : nil } ?? days[0]
            let window = days.filter { $0 >= windowStart }
            let total = window.reduce(0.0) { $0 + (daily[$1]?.values.reduce(0, +) ?? 0) }
            let rate = total / Double(max(1, window.count))
            return ForecastModel(mode: .pace, base: ["All": rate], dow: [:], phase: [:], tagFactors: [:],
                                 lastTopUp: lastTopUp, pessimism: 1.25, historyDays: days.count)
        }

        let categories = Set(daily.values.flatMap(\.keys))
        let n = Double(days.count)
        var base: [String: Double] = [:]
        var dow: [String: [Int: Double]] = [:]
        var phase: [String: [Int: Double]] = [:]
        var tagFactors: [String: [String: Double]] = [:]

        let dowKeys = days.map { [IST.weekdayIndex($0)] }
        let phaseKeys = days.map { day in [phaseBucket(day: day, lastTopUp: topUps.filter { $0 <= day }.max())] }
        let tagKeys = days.map { Array(tagsByDay[$0] ?? []) }

        for cat in categories {
            let actual = days.map { daily[$0]?[cat] ?? 0 }
            let total = actual.reduce(0, +)
            var b = total / n
            guard b > 0 else { base[cat] = 0; continue }

            // Backfitting: refit each factor group against the others, then rescale the base
            // so fitted totals match actual totals.
            var d: [Int: Double] = [:], p: [Int: Double] = [:], t: [String: Double] = [:]
            for _ in 0..<8 {
                d = fitFactor(actual: actual, keys: dowKeys) { b * product(phaseKeys[$0], p) * product(tagKeys[$0], t) }
                p = fitFactor(actual: actual, keys: phaseKeys) { b * product(dowKeys[$0], d) * product(tagKeys[$0], t) }
                t = fitFactor(actual: actual, keys: tagKeys) { b * product(dowKeys[$0], d) * product(phaseKeys[$0], p) }
                let shape = actual.indices.reduce(0.0) {
                    $0 + product(dowKeys[$1], d) * product(phaseKeys[$1], p) * product(tagKeys[$1], t)
                }
                if shape > 0 { b = total / shape }
            }
            base[cat] = b
            dow[cat] = d
            phase[cat] = p
            if !t.isEmpty { tagFactors[cat] = t }
        }

        var model = ForecastModel(mode: .baseline, base: base, dow: dow, phase: phase, tagFactors: tagFactors,
                                  lastTopUp: lastTopUp, pessimism: 1, historyDays: days.count)
        let ratios = days.compactMap { d -> Double? in
            let e = model.expectedValue(on: d, tags: tagsByDay[d] ?? [])
            return e > 0 ? (daily[d]?.values.reduce(0, +) ?? 0) / e : nil
        }.sorted()
        if !ratios.isEmpty {
            let q80 = ratios[min(ratios.count - 1, Int(Double(ratios.count) * 0.8))]
            model.pessimism = min(3, max(1, q80))
        }
        return model
    }

    /// Shrunk ratio of actual to expected (from the other factors) per key.
    private static func fitFactor<K: Hashable>(actual: [Double], keys: [[K]],
                                               expected: (Int) -> Double) -> [K: Double] {
        var obs: [K: Double] = [:], exp: [K: Double] = [:], count: [K: Double] = [:]
        for i in actual.indices {
            let e = expected(i)
            for k in keys[i] {
                obs[k, default: 0] += actual[i]
                exp[k, default: 0] += e
                count[k, default: 0] += 1
            }
        }
        var factors: [K: Double] = [:]
        for (k, e) in exp where e > 0 {
            let mean = e / count[k]!
            let f = (obs[k]! + shrinkage * mean) / (e + shrinkage * mean)
            factors[k] = min(5, max(0.2, f))
        }
        return factors
    }

    private static func product<K: Hashable>(_ keys: [K], _ factors: [K: Double]) -> Double {
        keys.reduce(1) { $0 * (factors[$1] ?? 1) }
    }

    /// Days since last top-up → 0: 0–3, 1: 4–10, 2: 11–20, 3: 21+. Falls back to day of month.
    static func phaseBucket(day: Date, lastTopUp: Date?) -> Int {
        let since = lastTopUp.map { IST.days(from: $0, to: day) } ?? (IST.dayOfMonth(day) - 1)
        switch since {
        case ..<4: return 0
        case 4...10: return 1
        case 11...20: return 2
        default: return 3
        }
    }
}

public enum RunOutResult: Hashable, Sendable {
    case noData
    /// Money lasts until the next top-up.
    case lasts
    /// First day the pessimistic projection goes negative.
    case runsOut(Date)
}

public enum RunOutProjector {
    public static func project(available: Money, spentToday: Money, model: ForecastModel, today: Date,
                               nextTopUp: Date?, tagsByDay: [Date: Set<String>] = [:]) -> RunOutResult {
        let start = IST.startOfDay(today)
        if available < .zero { return .runsOut(start) }
        guard model.mode != .noData else { return .noData }
        let end = nextTopUp.map(IST.startOfDay).flatMap { $0 > start ? $0 : nil } ?? IST.addDays(120, to: start)
        var remaining = Double(available.paise)
        var day = start
        while day < end {
            var need = model.expectedValue(on: day, tags: tagsByDay[day] ?? []) * model.pessimism
            if day == start { need = max(0, need - Double(spentToday.paise)) }
            remaining -= need
            if remaining < 0 { return .runsOut(day) }
            day = IST.addDays(1, to: day)
        }
        return nextTopUp == nil ? .runsOut(end) : .lasts
    }
}
