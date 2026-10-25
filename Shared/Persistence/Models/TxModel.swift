import Foundation
import SpendCore
import SwiftData

@Model
final class TxModel {
    var id: UUID = UUID()
    var date: Date = Date.now
    var amountPaise: Int = 0
    var kindRaw: String = TxKind.spend.rawValue
    var sourceRaw: String = TxSource.upi.rawValue
    var category: String?
    var payee: String?
    var ref: String?
    var mySharePaise: Int = 0
    var friendID: UUID?
    var needsReview: Bool = false
    var note: String?
    var rawSMS: String?
    var createdAt: Date = Date.now

    init(record: TransactionRecord, rawSMS: String? = nil) {
        id = record.id
        self.rawSMS = rawSMS
        apply(record)
    }

    func apply(_ r: TransactionRecord) {
        date = r.date
        amountPaise = r.amount.paise
        kindRaw = r.kind.rawValue
        sourceRaw = r.source.rawValue
        category = r.category
        payee = r.payee
        ref = r.ref
        mySharePaise = r.myShare.paise
        friendID = r.friendID
        needsReview = r.needsReview
        note = r.note
    }

    var kind: TxKind { TxKind(rawValue: kindRaw) ?? .spend }
    var source: TxSource { TxSource(rawValue: sourceRaw) ?? .none }
    var amount: Money { Money(paise: amountPaise) }
    var myShare: Money { Money(paise: mySharePaise) }

    var record: TransactionRecord {
        TransactionRecord(id: id, date: date, amount: amount, kind: kind, source: source, category: category,
                          payee: payee, ref: ref, myShare: myShare, friendID: friendID,
                          needsReview: needsReview, note: note)
    }
}
