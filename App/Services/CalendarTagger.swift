import EventKit
import Foundation
import SpendCore
import SwiftData

/// Turns calendar events with telling titles ("Felicity", "Goa trip", "Midsem") into day tags.
@MainActor
enum CalendarTagger {
    static let keywords: [(tag: String, words: [String])] = [
        ("party", ["party", "birthday", "bday"]),
        ("club", ["club", "pub", "night out"]),
        ("travel", ["trip", "travel", "flight", "train", "vacation"]),
        ("exam", ["exam", "midsem", "mid-sem", "endsem", "end-sem", "quiz", "finals"]),
        ("fest", ["fest", "felicity", "concert"]),
        ("holiday", ["holiday", "break", "diwali", "holi"]),
    ]

    static func tag(for title: String) -> String? {
        let t = title.lowercased()
        return keywords.first { $0.words.contains { t.contains($0) } }?.tag
    }

    static func requestAccess() async -> Bool {
        (try? await EKEventStore().requestFullAccessToEvents()) ?? false
    }

    /// Replaces all calendar-derived tags with a fresh scan of the last 6 months and next 2 months.
    static func sync(context: ModelContext, now: Date = .now) {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        let store = EKEventStore()
        let start = IST.addDays(-180, to: now), end = IST.addDays(60, to: now)
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))

        let source = TagModel.Source.calendar.rawValue
        for old in (try? context.fetch(FetchDescriptor<TagModel>(predicate: #Predicate { $0.sourceRaw == source }))) ?? [] {
            context.delete(old)
        }
        var seen = Set<String>()
        for event in events {
            guard let title = event.title, let tag = tag(for: title) else { continue }
            var day = IST.startOfDay(event.startDate)
            let last = IST.startOfDay(event.endDate.addingTimeInterval(-1))
            while day <= last {
                if seen.insert("\(day.timeIntervalSince1970)-\(tag)").inserted {
                    context.insert(TagModel(day: day, tag: tag, source: .calendar))
                }
                day = IST.addDays(1, to: day)
            }
        }
        try? context.save()
    }
}
