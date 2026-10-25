import Foundation

public struct FriendBalance: Hashable, Sendable {
    public var payable: Money
    public var receivable: Money

    public init(payable: Money, receivable: Money) {
        self.payable = payable
        self.receivable = receivable
    }

    /// Positive: friend owes the user. Negative: user owes the friend.
    public var net: Money { receivable - payable }
}

public struct IOUSettlement: Hashable, Sendable {
    public var iouID: UUID
    public var amount: Money

    public init(iouID: UUID, amount: Money) {
        self.iouID = iouID
        self.amount = amount
    }
}

public enum Ledger {
    public static func balances(_ ious: [IOU]) -> [UUID: FriendBalance] {
        var out: [UUID: FriendBalance] = [:]
        for iou in ious where iou.isOpen {
            var b = out[iou.friendID] ?? FriendBalance(payable: .zero, receivable: .zero)
            switch iou.direction {
            case .iOwe: b.payable = b.payable + iou.outstanding
            case .theyOwe: b.receivable = b.receivable + iou.outstanding
            }
            out[iou.friendID] = b
        }
        return out
    }

    public static func totalPayable(_ ious: [IOU]) -> Money {
        ious.filter { $0.direction == .iOwe }.map(\.outstanding).sum()
    }

    public static func totalReceivable(_ ious: [IOU]) -> Money {
        ious.filter { $0.direction == .theyOwe }.map(\.outstanding).sum()
    }

    /// Distributes a payment across a friend's open IOUs in one direction, oldest first.
    public static func settlementPlan(amount: Money, friendID: UUID, direction: IOUDirection,
                                      ious: [IOU]) -> (applied: [IOUSettlement], excess: Money) {
        var remaining = amount
        var applied: [IOUSettlement] = []
        let open = ious
            .filter { $0.friendID == friendID && $0.direction == direction && $0.isOpen }
            .sorted { $0.createdAt < $1.createdAt }
        for iou in open where remaining.isPositive {
            let take = min(remaining, iou.outstanding)
            applied.append(IOUSettlement(iouID: iou.id, amount: take))
            remaining = remaining - take
        }
        return (applied, remaining)
    }
}

public enum SplitCalculator {
    /// User paid the whole bill. Each tracked friend owes one share; untracked people's shares stay on the user.
    public static func paidForGroup(total: Money, people: Int? = nil, myShare: Money? = nil,
                                    friends: [UUID]) -> (myShare: Money, friendShares: [UUID: Money]) {
        guard !friends.isEmpty else { return (total, [:]) }
        var shares: [UUID: Money] = [:]
        if let myShare {
            let parts = (total - myShare).clamped(min: .zero).split(into: friends.count)
            for (f, s) in zip(friends, parts) { shares[f] = s }
        } else {
            let n = max(people ?? friends.count + 1, friends.count + 1)
            let parts = total.split(into: n)
            // parts[0] carries any remainder paise; give it to the user.
            for (f, s) in zip(friends, parts.dropFirst()) { shares[f] = s }
        }
        return (total - shares.values.sum(), shares)
    }

    /// Friend paid; the user's share becomes a payable.
    public static func friendPaid(total: Money, people: Int, myShare: Money? = nil) -> Money {
        myShare ?? total.split(into: max(1, people)).first ?? total
    }
}

extension Friend {
    /// SBI truncates payee names to 16 chars, so prefixes of at least 8 chars also count.
    public func matches(payee: String?) -> Bool {
        guard let payee else { return false }
        let p = RulesCategorizer.normalize(payee)
        guard !p.isEmpty else { return false }
        return ([name] + aliases).contains { alias in
            let a = RulesCategorizer.normalize(alias)
            guard !a.isEmpty else { return false }
            if a == p { return true }
            let (short, long) = a.count < p.count ? (a, p) : (p, a)
            return short.count >= 8 && long.hasPrefix(short)
        }
    }
}
