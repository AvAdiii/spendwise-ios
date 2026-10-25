import Foundation

public struct ParsedSMS: Hashable, Sendable {
    public enum Direction: String, Sendable { case debit, credit }
    public enum Kind: String, Sendable { case upi, atm }

    public var direction: Direction
    public var kind: Kind
    public var amount: Money
    public var date: Date
    public var payee: String?
    public var ref: String?
    public var accountSuffix: String?
    public var availableBalance: Money?
}

public protocol BankSMSParser: Sendable {
    func parse(_ text: String, receivedAt: Date) -> ParsedSMS?
}

/// Parses SBI UPI debit/credit and ATM withdrawal alerts.
public struct SBISMSParser: BankSMSParser {
    public init() {}

    private static let amount = #"(?:Rs\.?\s*|INR\s*)?([\d,]+(?:\.\d{1,2})?)"#
    private static let date = #"(\d{1,2}[A-Za-z]{3}\d{2})"#

    // "Dear UPI user A/C X4321 debited by 239.00 on date 25Oct26 trf to PRIYA SHARMA Refno 600000000101 ..."
    private static let debit = try! NSRegularExpression(pattern:
        #"A/C\s*X?(\d{3,6})\s+debited\s+by\s+"# + amount + #"\s+on\s+(?:date\s+)?"# + date +
        #"\s+trf\s+to\s+(.+?)\s+Ref\s*no\.?\s*:?\s*(\d{6,})"#, options: [.caseInsensitive])

    // "... A/c X4321-credited by Rs.500 on 25Oct26 transfer from RAHUL KUMAR Ref No 629729731099"
    // "... A/cX4321 credited by Rs5000 on 25Oct26 by  (Ref no 629729731100)"
    private static let credit = try! NSRegularExpression(pattern:
        #"A/c\s*X?(\d{3,6})[\s-]*credited\s+by\s+"# + amount + #"\s+on\s+(?:date\s+)?"# + date +
        #"\s*(?:(?:transfer\s+from|from|by)\s+(.*?))?\s*\(?\s*Ref\s*no\.?\s*:?\s*(\d{6,})"#, options: [.caseInsensitive])

    // "Rs.2,000 withdrawn at SBI ATM S1NW000123 from A/cX4321 on 25Oct26 Transaction Number 4521."
    private static let atm = try! NSRegularExpression(pattern:
        #"Rs\.?\s*([\d,]+(?:\.\d{1,2})?)\s+withdrawn\s+at\s+(.+?)\s+from\s+A/c\s*X?(\d{3,6})\s+on\s+"# + date +
        #"(?:.*?Transaction\s+Number\s+(\d+))?"#, options: [.caseInsensitive])

    private static let balance = try! NSRegularExpression(pattern:
        #"(?:Avl\.?\s*Bal|Available\s+Balance)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d{1,2})?)"#, options: [.caseInsensitive])

    public func parse(_ text: String, receivedAt: Date) -> ParsedSMS? {
        let text = text.replacingOccurrences(of: "\n", with: " ")
        let balance = Self.capture(Self.balance, in: text)?[0].flatMap { Money(parsing: $0) }

        if let g = Self.capture(Self.debit, in: text),
           let amount = g[1].flatMap(Money.init(parsing:)) {
            return ParsedSMS(direction: .debit, kind: .upi, amount: amount,
                             date: Self.resolveDate(g[2], receivedAt: receivedAt),
                             payee: Self.clean(g[3]), ref: g[4], accountSuffix: g[0],
                             availableBalance: balance)
        }
        if let g = Self.capture(Self.credit, in: text),
           let amount = g[1].flatMap(Money.init(parsing:)) {
            return ParsedSMS(direction: .credit, kind: .upi, amount: amount,
                             date: Self.resolveDate(g[2], receivedAt: receivedAt),
                             payee: Self.clean(g[3]), ref: g[4], accountSuffix: g[0],
                             availableBalance: balance)
        }
        if let g = Self.capture(Self.atm, in: text),
           let amount = g[0].flatMap(Money.init(parsing:)) {
            let ref = g[4].map { "ATM-\(g[3] ?? "")-\($0)" }
            return ParsedSMS(direction: .debit, kind: .atm, amount: amount,
                             date: Self.resolveDate(g[3], receivedAt: receivedAt),
                             payee: "ATM", ref: ref, accountSuffix: g[2],
                             availableBalance: balance)
        }
        return nil
    }

    /// Capture groups 1…n as optional strings (nil when a group did not participate).
    private static func capture(_ re: NSRegularExpression, in text: String) -> [String?]? {
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (1..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
    }

    private static func clean(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "(-.,")))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return t.isEmpty ? nil : t
    }

    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    /// "25Oct26" → that day. Same day as receipt keeps the receipt time; other days use noon.
    /// Dates after the receipt are treated as parse errors and fall back to the receipt time.
    static func resolveDate(_ token: String?, receivedAt: Date) -> Date {
        guard let token, (6...7).contains(token.count) else { return receivedAt }
        let chars = Array(token)
        let dayDigits = chars.count == 6 ? 1 : 2
        guard let day = Int(String(chars[0..<dayDigits])),
              let month = months.firstIndex(of: String(chars[dayDigits..<dayDigits + 3]).lowercased()),
              let yy = Int(String(chars[(dayDigits + 3)...])) else { return receivedAt }
        let date = IST.date(2000 + yy, month + 1, day, 12, 0)
        if IST.isSameDay(date, receivedAt) || date > receivedAt { return receivedAt }
        return date
    }
}
