import Foundation
import SpendCore
import SwiftData

/// Seeds a realistic month for screenshots (`-demo` launch argument) and previews.
@MainActor
enum DemoData {
    static func seed(_ context: ModelContext, now: Date = .now) {
        let start = IST.addDays(-45, to: IST.startOfDay(now))
        context.insert(CheckpointModel(date: start, bank: Money(rupees: 9_000), cash: Money(rupees: 300)))
        AppSettings.lastTopUp = IST.addDays(-12, to: now)
        AppSettings.nextTopUp = IST.addDays(9, to: IST.startOfDay(now))
        AppSettings.userName = "Alex"
        AppSettings.userVPA = "alex@oksbi"
        AppSettings.onboarded = true

        let priya = FriendModel(name: "Priya", aliases: ["PRIYA SHARMA"], vpa: "priya@okaxis")
        let rahul = FriendModel(name: "Rahul", aliases: ["RAHUL KUMAR"], vpa: "rahul@ybl")
        let karthik = FriendModel(name: "Karthik", aliases: ["KARTHIK RAMESHWAR"])
        for friend in [priya, rahul, karthik] { context.insert(friend) }

        let merchants: [(String, String, ClosedRange<Int>)] = [
            ("SWIGGY", "Food", 180...420), ("MADRUS KITCHEN", "Food", 40...140), ("ZEPTO", "Groceries", 90...350),
            ("RAPIDO", "Transport", 40...120), ("CANTEEN IIIT", "Food", 20...90), ("AMAZON", "Shopping", 200...900),
        ]
        var rng = SeededGenerator(seed: 7)
        for offset in 0..<45 {
            let day = IST.addDays(offset, to: start)
            guard day < now else { break }
            let count = IST.weekdayIndex(day) >= 6 ? 3 : 2
            for n in 0..<count {
                let m = merchants[Int.random(in: 0..<merchants.count, using: &rng)]
                let time = IST.calendar.date(byAdding: .hour, value: 10 + n * 5, to: day) ?? day
                let r = TransactionRecord(date: time, amount: Money(rupees: Int.random(in: m.2, using: &rng)), kind: .spend,
                                          source: .upi, category: m.1, payee: m.0, ref: "DEMO\(offset)\(n)")
                context.insert(TxModel(record: r))
            }
        }
        let topUp = TransactionRecord(date: IST.addDays(-12, to: now), amount: Money(rupees: 8_000), kind: .income,
                                      source: .upi, payee: "PAPA", ref: "DEMO-TOPUP")
        context.insert(TxModel(record: topUp))

        let dinner = TransactionRecord(date: IST.addDays(-2, to: now), amount: Money(rupees: 1_240), kind: .spend, source: .upi,
                                       category: "Food", payee: "BARBEQUE NATION", ref: "DEMO-DINNER", myShare: Money(rupees: 310))
        context.insert(TxModel(record: dinner))
        context.insert(IOUModel(friendID: rahul.id, direction: .theyOwe, amount: Money(rupees: 310), createdAt: dinner.date,
                                note: "Barbeque Nation", sourceTxID: dinner.id))
        context.insert(IOUModel(friendID: priya.id, direction: .theyOwe, amount: Money(rupees: 310), createdAt: dinner.date,
                                note: "Barbeque Nation", sourceTxID: dinner.id))
        let movie = TransactionRecord(date: IST.addDays(-1, to: now), amount: Money(rupees: 239), kind: .friendPaid, source: .none,
                                      category: "Entertainment", payee: "Karthik", friendID: karthik.id)
        context.insert(TxModel(record: movie))
        context.insert(IOUModel(friendID: karthik.id, direction: .iOwe, amount: Money(rupees: 239), createdAt: movie.date,
                                note: "Movie", sourceTxID: movie.id))
        let unknown = TransactionRecord(date: now.addingTimeInterval(-3_600), amount: Money(rupees: 60), kind: .spend,
                                        source: .upi, payee: "SRI SAI STORES", ref: "DEMO-UNKNOWN")
        context.insert(TxModel(record: unknown))

        context.insert(FixedCostModel(name: "Jio recharge", amount: Money(rupees: 349), monthlyDay: IST.dayOfMonth(IST.addDays(4, to: now)),
                                      payeeKeyword: "jio"))
        context.insert(EventModel(name: "House party", date: IST.addDays(3, to: now), estimate: Money(rupees: 600), tag: "party"))
        context.insert(TagModel(day: IST.addDays(-9, to: now), tag: "club", source: .manual))
        try? context.save()
    }
}

/// Deterministic RNG so demo screenshots are stable between runs.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
