import Foundation

/// Rupee amount stored as integer paise so arithmetic never drifts.
public struct Money: Hashable, Comparable, Codable, Sendable, AdditiveArithmetic {
    public var paise: Int

    public init(paise: Int) { self.paise = paise }
    public init(rupees: Int) { self.paise = rupees * 100 }

    /// Parses "1,240.50", "5", "5.5". Returns nil for anything else.
    public init?(parsing text: String) {
        let cleaned = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count),
              !parts[0].isEmpty, parts[0].allSatisfy(\.isNumber),
              let whole = Int(parts[0]) else { return nil }
        var fraction = 0
        if parts.count == 2 {
            let f = parts[1]
            guard (1...2).contains(f.count), f.allSatisfy(\.isNumber), let v = Int(f) else { return nil }
            fraction = f.count == 1 ? v * 10 : v
        }
        self.paise = whole * 100 + fraction
    }

    public static let zero = Money(paise: 0)

    public var rupees: Double { Double(paise) / 100 }
    public var isPositive: Bool { paise > 0 }

    /// "1240.50" — used for UPI links and exports.
    public var plainString: String {
        let sign = paise < 0 ? "-" : ""
        let a = abs(paise)
        return "\(sign)\(a / 100).\(String(format: "%02d", a % 100))"
    }

    public static func + (l: Money, r: Money) -> Money { Money(paise: l.paise + r.paise) }
    public static func - (l: Money, r: Money) -> Money { Money(paise: l.paise - r.paise) }
    public static prefix func - (m: Money) -> Money { Money(paise: -m.paise) }
    public static func < (l: Money, r: Money) -> Bool { l.paise < r.paise }
    public static func * (l: Money, r: Double) -> Money { Money(paise: Int((Double(l.paise) * r).rounded())) }
    public static func / (l: Money, r: Int) -> Money { Money(paise: r == 0 ? 0 : l.paise / r) }

    /// Splits into `count` parts that sum exactly to self; remainder paise go to the first parts.
    public func split(into count: Int) -> [Money] {
        guard count > 0 else { return [] }
        let base = paise / count
        let rem = paise % count
        return (0..<count).map { Money(paise: base + ($0 < rem ? 1 : 0)) }
    }

    public func clamped(min lower: Money) -> Money { Swift.max(self, lower) }
}

extension Sequence where Element == Money {
    public func sum() -> Money { reduce(.zero, +) }
}
