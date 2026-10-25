import Foundation
import SpendCore
import SwiftData

/// JSON export/import. Sideloaded builds have no iCloud, so this is the only backup.
@MainActor
enum BackupService {
    struct Backup: Codable {
        var version = 1
        var exportedAt: Date
        var transactions: [TransactionRecord]
        var friends: [Friend]
        var ious: [IOUBackup]
        var fixedCosts: [FixedCost]
        var events: [PlannedEvent]
        var tags: [TagBackup]
        var rules: [CategoryRule]
        var checkpoints: [BalanceCheckpoint]
        var nextTopUp: Date?
        var lastTopUp: Date?
        var userName: String
        var userVPA: String
    }

    struct IOUBackup: Codable {
        var iou: IOU
        var sourceTxID: UUID?
    }

    struct TagBackup: Codable {
        var day: Date
        var tag: String
        var source: String
    }

    static func export(context: ModelContext) throws -> URL {
        let s = LedgerSnapshot.load(from: context)
        let ious = try context.fetch(FetchDescriptor<IOUModel>()).map { IOUBackup(iou: $0.iou, sourceTxID: $0.sourceTxID) }
        let tags = try context.fetch(FetchDescriptor<TagModel>()).map { TagBackup(day: $0.day, tag: $0.tag, source: $0.sourceRaw) }
        let checkpoints = try context.fetch(FetchDescriptor<CheckpointModel>()).map(\.checkpoint)
        let backup = Backup(exportedAt: .now, transactions: s.transactions, friends: s.friends, ious: ious,
                            fixedCosts: s.fixedCosts, events: s.events, tags: tags, rules: s.rules,
                            checkpoints: checkpoints, nextTopUp: AppSettings.nextTopUp, lastTopUp: AppSettings.lastTopUp,
                            userName: AppSettings.userName, userVPA: AppSettings.userVPA)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let url = URL.temporaryDirectory.appending(path: "Spendwise-\(stamp).json")
        try encoder.encode(backup).write(to: url)
        return url
    }

    /// Replaces all data with the backup's contents.
    static func restore(from url: URL, context: ModelContext) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let b = try decoder.decode(Backup.self, from: Data(contentsOf: url))

        try deleteAll(TxModel.self, in: context)
        try deleteAll(FriendModel.self, in: context)
        try deleteAll(IOUModel.self, in: context)
        try deleteAll(FixedCostModel.self, in: context)
        try deleteAll(EventModel.self, in: context)
        try deleteAll(TagModel.self, in: context)
        try deleteAll(RuleModel.self, in: context)
        try deleteAll(CheckpointModel.self, in: context)

        for t in b.transactions { context.insert(TxModel(record: t)) }
        for f in b.friends {
            let m = FriendModel(name: f.name, aliases: f.aliases, vpa: f.vpa)
            m.id = f.id
            context.insert(m)
        }
        for i in b.ious {
            let m = IOUModel(friendID: i.iou.friendID, direction: i.iou.direction, amount: i.iou.amount,
                             createdAt: i.iou.createdAt, note: i.iou.note, sourceTxID: i.sourceTxID)
            m.id = i.iou.id
            m.settledPaise = i.iou.settled.paise
            context.insert(m)
        }
        for c in b.fixedCosts {
            var onceDate: Date?, monthlyDay: Int?
            switch c.schedule {
            case .once(let d): onceDate = d
            case .monthly(let day): monthlyDay = day
            }
            let m = FixedCostModel(name: c.name, amount: c.amount, onceDate: onceDate, monthlyDay: monthlyDay, payeeKeyword: c.payeeKeyword)
            m.id = c.id
            m.paidThrough = c.paidThrough
            context.insert(m)
        }
        for e in b.events {
            let m = EventModel(name: e.name, date: e.date, estimate: e.estimate, tag: e.tag)
            m.id = e.id
            context.insert(m)
        }
        for t in b.tags { context.insert(TagModel(day: t.day, tag: t.tag, source: TagModel.Source(rawValue: t.source) ?? .manual)) }
        for r in b.rules { context.insert(RuleModel(keyword: r.keyword, category: r.category, exact: r.exact)) }
        for c in b.checkpoints { context.insert(CheckpointModel(date: c.date, bank: c.bank, cash: c.cash)) }
        AppSettings.nextTopUp = b.nextTopUp
        AppSettings.lastTopUp = b.lastTopUp
        AppSettings.userName = b.userName
        AppSettings.userVPA = b.userVPA
        AppSettings.onboarded = true
        try context.save()
    }

    /// Row-by-row delete; batch delete is not supported by every store type.
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<T>()) { context.delete(item) }
    }
}
