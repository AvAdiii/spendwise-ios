import Foundation
import Testing
@testable import SpendCore

@Suite struct SafeToSpendTests {
    let now = IST.date(2026, 10, 25, 18, 0)
    let friend = UUID()

    func input(txs: [TransactionRecord] = [], ious: [IOU] = [], fixed: [FixedCost] = [],
               events: [PlannedEvent] = [], topUp: Date? = IST.date(2026, 11, 1)) -> BudgetInput {
        BudgetInput(checkpoint: BalanceCheckpoint(date: IST.date(2026, 10, 20), bank: Money(rupees: 5000), cash: Money(rupees: 500)),
                    transactions: txs, ious: ious, fixedCosts: fixed, events: events, now: now, nextTopUp: topUp)
    }

    @Test func plainBalanceDividedByDays() {
        let b = SafeToSpendEngine.compute(input())
        #expect(b.liquid == Money(rupees: 5500))
        #expect(b.daysLeft == 7) // 25th … 31st
        #expect(b.dailyAllowance == Money(paise: 550_000 / 7))
        #expect(b.topUpStale == false)
    }

    @Test func transactionsBeforeCheckpointAreIgnored() {
        let old = TransactionRecord(date: IST.date(2026, 10, 19), amount: Money(rupees: 999), kind: .spend, source: .upi)
        #expect(SafeToSpendEngine.compute(input(txs: [old])).bank == Money(rupees: 5000))
    }

    @Test func payablesFixedAndEventsAreCommitted() {
        let iou = IOU(friendID: friend, direction: .iOwe, amount: Money(rupees: 400), createdAt: now)
        let owedToMe = IOU(friendID: friend, direction: .theyOwe, amount: Money(rupees: 1000), createdAt: now)
        let jio = FixedCost(name: "Jio", amount: Money(rupees: 349), schedule: .monthly(day: 28))
        let netflix = FixedCost(name: "Netflix", amount: Money(rupees: 199), schedule: .monthly(day: 5)) // after top-up
        let party = PlannedEvent(name: "House party", date: IST.date(2026, 10, 31), estimate: Money(rupees: 800))
        let b = SafeToSpendEngine.compute(input(ious: [iou, owedToMe], fixed: [jio, netflix], events: [party]))
        #expect(b.payables == Money(rupees: 400))
        #expect(b.receivables == Money(rupees: 1000))
        #expect(b.fixedDue == Money(rupees: 349))
        #expect(b.eventsDue == Money(rupees: 800))
        #expect(b.available == Money(rupees: 5500 - 400 - 349 - 800)) // receivables never added
    }

    @Test func todaysSpendReducesLeftTodayNotAllowance() {
        let lunch = TransactionRecord(date: IST.date(2026, 10, 25, 13, 0), amount: Money(rupees: 700), kind: .spend, source: .upi)
        let b = SafeToSpendEngine.compute(input(txs: [lunch]))
        #expect(b.spentToday == Money(rupees: 700))
        #expect(b.dailyAllowance == Money(paise: 550_000 / 7))
        #expect(b.leftToday == Money(paise: 550_000 / 7) - Money(rupees: 700))
    }

    @Test func splitBillCountsOnlyMyShareAsSpending() {
        let dinner = TransactionRecord(date: IST.date(2026, 10, 25, 13, 0), amount: Money(rupees: 1200), kind: .spend,
                                       source: .upi, myShare: Money(rupees: 300))
        let b = SafeToSpendEngine.compute(input(txs: [dinner]))
        #expect(b.bank == Money(rupees: 3800))
        #expect(b.spentToday == Money(rupees: 300))
    }

    @Test func cashAndAtmFlowThroughWallets() {
        let atm = TransactionRecord(date: IST.date(2026, 10, 22), amount: Money(rupees: 1000), kind: .transfer, source: .atm)
        let chai = TransactionRecord(date: IST.date(2026, 10, 23), amount: Money(rupees: 20), kind: .spend, source: .cash)
        let b = SafeToSpendEngine.compute(input(txs: [atm, chai]))
        #expect(b.bank == Money(rupees: 4000))
        #expect(b.cash == Money(rupees: 1480))
        #expect(b.liquid == Money(rupees: 5480))
    }

    @Test func missingOrPastTopUpIsStale() {
        #expect(SafeToSpendEngine.compute(input(topUp: nil)).topUpStale)
        #expect(SafeToSpendEngine.compute(input(topUp: IST.date(2026, 10, 24))).topUpStale)
        #expect(SafeToSpendEngine.compute(input(topUp: IST.date(2026, 10, 26))).daysLeft == 1)
    }
}

@Suite struct ForecastTests {
    let today = IST.date(2026, 10, 25, 10, 0)

    func spend(_ day: Date, _ rupees: Int, _ cat: String = "Food") -> TransactionRecord {
        TransactionRecord(date: IST.calendar.date(byAdding: .hour, value: 13, to: IST.startOfDay(day))!,
                          amount: Money(rupees: rupees), kind: .spend, source: .upi, category: cat)
    }

    @Test func coldStartUsesPace() {
        let txs = (1...10).map { spend(IST.addDays(-$0, to: today), 200) }
        let m = Forecaster.fit(transactions: txs, tags: [], topUps: [], today: today)
        #expect(m.mode == .pace)
        #expect(m.expected(on: today) == Money(rupees: 200))
    }

    @Test func emptyHistoryHasNoData() {
        let m = Forecaster.fit(transactions: [], tags: [], topUps: [], today: today)
        #expect(m.mode == .noData)
        #expect(m.expected(on: today) == .zero)
    }

    @Test func baselineLearnsWeekendAndTagMultipliers() {
        var txs: [TransactionRecord] = []
        var tags: [DayTag] = []
        for i in 1...84 {
            let d = IST.addDays(-i, to: today)
            let weekend = IST.weekdayIndex(d) >= 6
            var amount = weekend ? 400 : 200
            if i % 9 == 0 { tags.append(DayTag(day: d, tag: "Club")); amount += 1000 }
            txs.append(spend(d, amount))
        }
        let m = Forecaster.fit(transactions: txs, tags: tags, topUps: [], today: today)
        #expect(m.mode == .baseline)
        let saturday = IST.date(2026, 10, 31)
        let wednesday = IST.date(2026, 10, 28)
        #expect(m.expected(on: saturday) > m.expected(on: wednesday) * 1.5)
        #expect(m.expected(on: wednesday, tags: ["club"]) > m.expected(on: wednesday) * 2)
        #expect(m.tagExtraCost("club", on: [wednesday]) > Money(rupees: 300))
        #expect(m.pessimism >= 1.0 && m.pessimism <= 3.0)
    }

    @Test func runOutProjection() {
        let txs = (1...10).map { spend(IST.addDays(-$0, to: today), 200) }
        let m = Forecaster.fit(transactions: txs, tags: [], topUps: [], today: today)
        // 200/day × pessimism; 700 available lasts ~3 days.
        let short = RunOutProjector.project(available: Money(rupees: 700), spentToday: .zero, model: m,
                                            today: today, nextTopUp: IST.date(2026, 11, 10))
        guard case .runsOut(let date) = short else { Issue.record("expected run-out"); return }
        #expect(date > IST.startOfDay(today) && date < IST.date(2026, 10, 29))

        let long = RunOutProjector.project(available: Money(rupees: 50_000), spentToday: .zero, model: m,
                                           today: today, nextTopUp: IST.date(2026, 11, 1))
        #expect(long == .lasts)
        let broke = RunOutProjector.project(available: Money(rupees: -10), spentToday: .zero, model: m,
                                            today: today, nextTopUp: IST.date(2026, 11, 1))
        #expect(broke == .runsOut(IST.startOfDay(today)))
    }
}

@Suite struct AlertTests {
    @Test func paceAlertFiresOncePerBand() {
        let start = IST.date(2026, 10, 1)
        let end = IST.date(2026, 10, 31)
        let now = IST.date(2026, 10, 6, 20, 0) // day 6 of 30 → 20% time
        let a = PaceAlertEngine.evaluate(periodStart: start, nextTopUp: end, now: now,
                                         spentSinceStart: Money(rupees: 4000), available: Money(rupees: 6000), lastBand: nil)
        #expect(a?.band == 4)
        #expect(a?.message == "You've spent 40% of this top-up in 6 days.")
        #expect(PaceAlertEngine.evaluate(periodStart: start, nextTopUp: end, now: now,
                                         spentSinceStart: Money(rupees: 4000), available: Money(rupees: 6000), lastBand: 4) == nil)
        // On pace → silent.
        #expect(PaceAlertEngine.evaluate(periodStart: start, nextTopUp: end, now: now,
                                         spentSinceStart: Money(rupees: 2000), available: Money(rupees: 8000), lastBand: nil) == nil)
        #expect(PaceAlertEngine.evaluate(periodStart: start, nextTopUp: end, now: now,
                                         spentSinceStart: Money(rupees: 4000), available: Money(rupees: 6000), lastBand: 3)?.band == 4)
    }

    @Test func anomalyNeedsDoubleForecastAndFloor() {
        #expect(AnomalyDetector.isAnomaly(actual: Money(rupees: 900), expected: Money(rupees: 300), alreadyTagged: false))
        #expect(!AnomalyDetector.isAnomaly(actual: Money(rupees: 250), expected: Money(rupees: 100), alreadyTagged: false))
        #expect(!AnomalyDetector.isAnomaly(actual: Money(rupees: 900), expected: Money(rupees: 300), alreadyTagged: true))
        #expect(!AnomalyDetector.isAnomaly(actual: Money(rupees: 500), expected: Money(rupees: 300), alreadyTagged: false))
    }

    @Test func collectionNudgeOnlyFirstThreeDays() {
        let msg = CollectionNudge.message(now: IST.date(2026, 11, 2), receivable: Money(rupees: 1400),
                                          debtors: 3, payable: Money(rupees: 200))
        #expect(msg == "Payday week: collect ₹1,400 from 3 friends and clear ₹200 you owe.")
        #expect(CollectionNudge.message(now: IST.date(2026, 11, 4), receivable: Money(rupees: 1400), debtors: 3, payable: .zero) == nil)
        #expect(CollectionNudge.message(now: IST.date(2026, 11, 1), receivable: .zero, debtors: 0, payable: .zero) == nil)
    }
}

@Suite struct UPILinkTests {
    @Test func buildsEncodedPayLink() {
        let url = UPILinkBuilder.payLink(vpa: "rahul@okaxis", name: "Alex Rao", amount: Money(paise: 124_000), note: "Dinner & drinks")
        #expect(url?.absoluteString == "upi://pay?pa=rahul@okaxis&pn=Alex%20Rao&am=1240.00&cu=INR&tn=Dinner%20%26%20drinks")
    }

    @Test func formatsRupees() {
        #expect(Money(paise: 124_050).formatted() == "₹1,240.50")
        #expect(Money(rupees: 100_000).formatted() == "₹1,00,000")
        #expect(Money(rupees: -50).formatted() == "−₹50")
    }
}
