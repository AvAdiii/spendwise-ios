import Foundation
import Testing
@testable import SpendCore

@Suite struct SBISMSParserTests {
    let parser = SBISMSParser()
    let received = IST.date(2026, 10, 25, 21, 30)

    @Test func parsesRealDebitToPerson() throws {
        let sms = "Dear UPI user A/C X4321 debited by 239.00 on date 25Oct26 trf to PRIYA SHARMA Refno 600000000101 If not u? call-1800111109 for other services-18001234-SBI"
        let p = try #require(parser.parse(sms, receivedAt: received))
        #expect(p.direction == .debit)
        #expect(p.amount == Money(rupees: 239))
        #expect(p.payee == "PRIYA SHARMA")
        #expect(p.ref == "600000000101")
        #expect(p.accountSuffix == "4321")
        #expect(p.kind == .upi)
        // Same calendar day as receipt → keeps receipt time.
        #expect(p.date == received)
    }

    @Test func parsesTruncatedPayeeAndOlderDate() throws {
        let sms = "Dear UPI user A/C X4321 debited by 20.00 on date 24Oct26 trf to KARTHIK RAMESHWA Refno 600000000102 If not u? call-1800111109 for other services-18001234-SBI"
        let p = try #require(parser.parse(sms, receivedAt: received))
        #expect(p.amount == Money(rupees: 20))
        #expect(p.payee == "KARTHIK RAMESHWA")
        #expect(p.date == IST.date(2026, 10, 24, 12, 0))
    }

    @Test func parsesMerchantDebit() throws {
        let sms = "Dear UPI user A/C X4321 debited by 5.00 on date 22Oct26 trf to MADRUS KITCHEN Refno 600000000103 If not u? call-1800111109 for other services-18001234-SBI"
        let p = try #require(parser.parse(sms, receivedAt: received))
        #expect(p.amount == Money(paise: 500))
        #expect(p.payee == "MADRUS KITCHEN")
    }

    @Test func parsesPaiseAndThousandsSeparators() throws {
        let sms = "Dear UPI user A/C X4321 debited by 1,240.50 on date 25Oct26 trf to SWIGGY Refno 123456789012 If not u? call-1800111109"
        let p = try #require(parser.parse(sms, receivedAt: received))
        #expect(p.amount == Money(paise: 124_050))
    }

    @Test func parsesCreditWithSender() throws {
        let sms = "Dear SBI User, your A/c X4321-credited by Rs.500 on 25Oct26 transfer from RAHUL KUMAR Ref No 629729731099 -SBI"
        let p = try #require(parser.parse(sms, receivedAt: received))
        #expect(p.direction == .credit)
        #expect(p.amount == Money(rupees: 500))
        #expect(p.payee == "RAHUL KUMAR")
        #expect(p.ref == "629729731099")
    }

    @Test func parsesCreditWithoutSender() throws {
        let sms = "Dear SBI UPI User, ur A/cX4321 credited by Rs5000 on 25Oct26 by  (Ref no 629729731100)"
        let p = try #require(parser.parse(sms, receivedAt: received))
        #expect(p.direction == .credit)
        #expect(p.amount == Money(rupees: 5000))
        #expect(p.payee == nil)
        #expect(p.ref == "629729731100")
    }

    @Test func parsesATMWithdrawal() throws {
        let sms = "Dear Customer, Rs.2,000 withdrawn at SBI ATM S1NW000123 from A/cX4321 on 25Oct26 Transaction Number 4521. Available Balance Rs.3,410.25. If not withdrawn by you, call 1800111109 -SBI"
        let p = try #require(parser.parse(sms, receivedAt: received))
        #expect(p.direction == .debit)
        #expect(p.kind == .atm)
        #expect(p.amount == Money(rupees: 2000))
        #expect(p.availableBalance == Money(paise: 341_025))
    }

    @Test func capturesAvailableBalanceWhenPresent() throws {
        let sms = "Dear UPI user A/C X4321 debited by 100.00 on date 25Oct26 trf to ZOMATO Refno 111122223333 Avl Bal Rs 4,512.00 -SBI"
        let p = try #require(parser.parse(sms, receivedAt: received))
        #expect(p.availableBalance == Money(rupees: 4512))
        #expect(p.payee == "ZOMATO")
    }

    @Test func rejectsNonTransactionText() {
        #expect(parser.parse("Your OTP for login is 482913. Do not share. -SBI", receivedAt: received) == nil)
        #expect(parser.parse("", receivedAt: received) == nil)
    }

    @Test func futureDateBeyondReceiptClampsToReceipt() throws {
        // A malformed year must not produce a transaction in the future.
        let sms = "Dear UPI user A/C X4321 debited by 10.00 on date 25Oct27 trf to X Refno 999988887777"
        let p = try #require(parser.parse(sms, receivedAt: received))
        #expect(p.date == received)
    }
}

@Suite struct MoneyTests {
    @Test func parsesAndFormats() {
        #expect(Money(parsing: "1,240.50") == Money(paise: 124_050))
        #expect(Money(parsing: "5") == Money(rupees: 5))
        #expect(Money(parsing: "5.5") == Money(paise: 550))
        #expect(Money(parsing: "abc") == nil)
        #expect(Money(paise: 124_050).plainString == "1240.50")
    }

    @Test func splitsEvenlyWithRemainderOnFirst() {
        let parts = Money(paise: 1000).split(into: 3)
        #expect(parts == [Money(paise: 334), Money(paise: 333), Money(paise: 333)])
    }
}

@Suite struct SBIDateTokenTests {
    @Test func singleDigitDay() {
        let received = IST.date(2026, 10, 25, 9, 0)
        #expect(SBISMSParser.resolveDate("4Oct26", receivedAt: received) == IST.date(2026, 10, 4, 12, 0))
        #expect(SBISMSParser.resolveDate("garbage", receivedAt: received) == received)
    }
}
