import Foundation
import SpendCore
import SwiftData

@Model
final class IOUModel {
    var id: UUID = UUID()
    var friendID: UUID = UUID()
    var directionRaw: String = IOUDirection.iOwe.rawValue
    var amountPaise: Int = 0
    var settledPaise: Int = 0
    var createdAt: Date = Date.now
    var note: String?
    /// Transaction that created this IOU (a split or a friend-paid log); deleting it removes the IOU.
    var sourceTxID: UUID?

    init(friendID: UUID, direction: IOUDirection, amount: Money, createdAt: Date, note: String? = nil, sourceTxID: UUID? = nil) {
        self.friendID = friendID
        directionRaw = direction.rawValue
        amountPaise = amount.paise
        self.createdAt = createdAt
        self.note = note
        self.sourceTxID = sourceTxID
    }

    var direction: IOUDirection { IOUDirection(rawValue: directionRaw) ?? .iOwe }

    var iou: IOU {
        IOU(id: id, friendID: friendID, direction: direction, amount: Money(paise: amountPaise),
            settled: Money(paise: settledPaise), createdAt: createdAt, note: note)
    }
}
