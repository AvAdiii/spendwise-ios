import Foundation

public enum UPILinkBuilder {
    private static let allowed: CharacterSet = {
        var s = CharacterSet.alphanumerics
        s.insert(charactersIn: "-._~@")
        return s
    }()

    /// `upi://pay` deep link a friend can tap to pay the user.
    public static func payLink(vpa: String, name: String, amount: Money, note: String?) -> URL? {
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        var s = "upi://pay?pa=\(enc(vpa))&pn=\(enc(name))&am=\(amount.plainString)&cu=INR"
        if let note, !note.isEmpty { s += "&tn=\(enc(note))" }
        return URL(string: s)
    }
}

extension Money {
    /// Indian grouping: ₹1,00,000 · ₹1,240.50 · −₹50. Paise shown only when non-zero.
    public func formatted() -> String {
        let a = abs(paise)
        let digits = String(a / 100)
        var grouped = ""
        if digits.count <= 3 {
            grouped = digits
        } else {
            let last3 = digits.suffix(3)
            var head = String(digits.dropLast(3))
            var groups: [String] = []
            while head.count > 2 {
                groups.insert(String(head.suffix(2)), at: 0)
                head = String(head.dropLast(2))
            }
            if !head.isEmpty { groups.insert(head, at: 0) }
            grouped = groups.joined(separator: ",") + "," + last3
        }
        let frac = a % 100 == 0 ? "" : "." + String(format: "%02d", a % 100)
        return (paise < 0 ? "−" : "") + "₹" + grouped + frac
    }
}
