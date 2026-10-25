import Foundation

public enum Categories {
    public static let defaults = [
        "Food", "Groceries", "Transport", "Shopping", "Entertainment",
        "Bills & Recharge", "Travel", "Health", "Education", "Personal", "Other",
    ]

    public static func symbol(for category: String?) -> String {
        switch category {
        case "Food": "fork.knife"
        case "Groceries": "basket"
        case "Transport": "car"
        case "Shopping": "bag"
        case "Entertainment": "popcorn"
        case "Bills & Recharge": "bolt"
        case "Travel": "tram"
        case "Health": "cross.case"
        case "Education": "book"
        case "Personal": "person"
        case nil: "questionmark.circle"
        default: "tag"
        }
    }
}

public struct CategoryRule: Hashable, Codable, Sendable {
    /// Normalised (lowercased, single-spaced) keyword or full payee.
    public var keyword: String
    public var category: String
    /// Exact rules match the whole payee and come from user corrections.
    public var exact: Bool

    public init(keyword: String, category: String, exact: Bool) {
        self.keyword = RulesCategorizer.normalize(keyword)
        self.category = category
        self.exact = exact
    }
}

/// Payee → category. Exact (learned) rules win, then the longest matching keyword.
public struct RulesCategorizer: Sendable {
    public private(set) var rules: [CategoryRule]

    public init(rules: [CategoryRule]) { self.rules = rules }

    public static func withDefaults() -> RulesCategorizer {
        RulesCategorizer(rules: defaultKeywords.flatMap { category, words in
            words.map { CategoryRule(keyword: $0, category: category, exact: false) }
        })
    }

    public static let defaultKeywords: [(String, [String])] = [
        ("Food", ["swiggy", "zomato", "kitchen", "canteen", "cafe", "restaurant", "dominos", "domino",
                  "mcdonald", "kfc", "pizza", "burger", "biryani", "bakery", "tea", "chai", "juice",
                  "food", "mess", "dhaba", "eatery", "starbucks", "subway", "eatsure"]),
        ("Groceries", ["blinkit", "zepto", "instamart", "bigbasket", "dmart", "grocery", "supermarket",
                       "kirana", "ratnadeep", "more retail", "jiomart"]),
        ("Transport", ["uber", "ola", "rapido", "metro", "namma yatri", "petrol", "fuel", "auto", "hpcl",
                       "bpcl", "indian oil", "fastag"]),
        ("Travel", ["irctc", "redbus", "makemytrip", "goibibo", "indigo", "air india", "akasa", "ixigo",
                    "abhibus", "cleartrip", "oyo"]),
        ("Shopping", ["amazon", "flipkart", "myntra", "ajio", "meesho", "nykaa", "decathlon", "croma",
                      "reliance digital", "lenskart"]),
        ("Bills & Recharge", ["jio", "airtel", "vi", "vodafone", "bsnl", "recharge", "electricity",
                              "broadband", "act fibernet", "postpaid", "prepaid"]),
        ("Entertainment", ["netflix", "spotify", "hotstar", "prime video", "bookmyshow", "pvr", "inox",
                           "youtube", "steam", "playstation", "district"]),
        ("Health", ["pharmacy", "apollo", "medplus", "netmeds", "pharmeasy", "1mg", "hospital", "clinic",
                    "medical", "chemist", "gym", "cult"]),
        ("Education", ["udemy", "coursera", "xerox", "stationery", "book", "printout", "iiit"]),
        ("Personal", ["salon", "barber", "laundry", "dhobi"]),
    ]

    public func categorize(payee: String?) -> String? {
        guard let payee else { return nil }
        let p = Self.normalize(payee)
        if let exact = rules.last(where: { $0.exact && $0.keyword == p }) { return exact.category }
        let words = Set(p.split(separator: " ").map(String.init))
        return rules
            .filter { !$0.exact && Self.keyword($0.keyword, matches: p, words: words) }
            .max { $0.keyword.count < $1.keyword.count }?
            .category
    }

    /// Records a user correction as an exact rule, replacing any earlier one for that payee.
    public mutating func learn(payee: String, category: String) {
        let p = Self.normalize(payee)
        rules.removeAll { $0.exact && $0.keyword == p }
        rules.append(CategoryRule(keyword: p, category: category, exact: true))
    }

    private static func keyword(_ k: String, matches payee: String, words: Set<String>) -> Bool {
        // Short keywords ("vi", "ola", "tea") only match as whole words to avoid false hits.
        k.count <= 4 ? words.contains(k) || (k.contains(" ") && payee.contains(k)) : payee.contains(k)
    }

    public static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
