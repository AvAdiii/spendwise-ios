import SpendCore
import SwiftData
import SwiftUI
import WidgetKit

struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FixedCostModel.name) private var fixedCosts: [FixedCostModel]
    @Query(sort: \EventModel.date) private var events: [EventModel]
    @Query(sort: \TagModel.day) private var tags: [TagModel]

    @State private var nextTopUp = AppSettings.nextTopUp ?? IST.addDays(7, to: IST.startOfDay(.now))
    @State private var editingCost: FixedCostModel?
    @State private var showNewCost = false
    @State private var showNewEvent = false
    @State private var showNewTag = false
    @State private var confirmTopUp = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Next top-up", selection: $nextTopUp, in: tomorrow..., displayedComponents: .date)
                    Button("Money arrived today", systemImage: "arrow.down.circle") { confirmTopUp = true }
                } header: {
                    Text("Top-up")
                } footer: {
                    Text("Safe-to-spend divides what's left by the days until this date.")
                }

                Section {
                    ForEach(fixedCosts) { cost in
                        Button { editingCost = cost } label: {
                            LabeledContent {
                                Text(Money(paise: cost.amountPaise).formatted()).monospacedDigit()
                            } label: {
                                Text(cost.name)
                                Text(scheduleText(cost))
                            }
                        }
                        .tint(.primary)
                    }
                    .onDelete { delete(fixedCosts, at: $0) }
                    Button("Add fixed cost", systemImage: "plus") { showNewCost = true }
                } header: {
                    Text("Fixed costs")
                } footer: {
                    Text("Recharges, subscriptions, a ticket home. Unpaid ones due before your top-up are set aside.")
                }

                Section {
                    ForEach(upcomingEvents) { event in
                        LabeledContent {
                            Text(Money(paise: event.estimatePaise).formatted()).monospacedDigit()
                        } label: {
                            Text(event.name)
                            Text(event.date.formatted(.dateTime.weekday().day().month()))
                        }
                    }
                    .onDelete { delete(upcomingEvents, at: $0) }
                    Button("Add event", systemImage: "plus") { showNewEvent = true }
                } header: {
                    Text("Planned events")
                } footer: {
                    Text("House parties, club nights, trips. Their estimate is set aside until the day.")
                }

                Section {
                    ForEach(upcomingTagDays, id: \.self) { day in
                        LabeledContent(day.formatted(.dateTime.weekday().day().month()),
                                       value: tagsOn(day).formatted())
                    }
                    Button("Tag days", systemImage: "tag") { showNewTag = true }
                } header: {
                    Text("Upcoming tags")
                } footer: {
                    Text("Tags like exam, fest or travel teach the forecast how those days cost you. Calendar events are tagged automatically when Calendar sync is on.")
                }
            }
            .navigationTitle("Plan")
            .onChange(of: nextTopUp) { _, newValue in
                AppSettings.nextTopUp = newValue
                WidgetCenter.shared.reloadAllTimelines()
            }
            .confirmationDialog("Mark top-up as received today?", isPresented: $confirmTopUp, titleVisibility: .visible) {
                Button("Yes, next one on \(nextTopUp.formatted(.dateTime.day().month()))") {
                    SpendService(context: context).recordTopUp(next: nextTopUp)
                }
            } message: {
                Text("Starts a new budget period. Check your next top-up date first.")
            }
            .sheet(isPresented: $showNewCost) { FixedCostEditor(cost: nil) }
            .sheet(item: $editingCost) { FixedCostEditor(cost: $0) }
            .sheet(isPresented: $showNewEvent) { EventEditor() }
            .sheet(isPresented: $showNewTag) { TagEditor() }
        }
    }

    private var tomorrow: Date { IST.addDays(1, to: IST.startOfDay(.now)) }

    private var upcomingEvents: [EventModel] {
        events.filter { $0.date >= IST.startOfDay(.now) }
    }

    private var upcomingTagDays: [Date] {
        let today = IST.startOfDay(.now)
        return Array(Set(tags.map(\.day).filter { $0 >= today })).sorted().prefix(14).map { $0 }
    }

    private func tagsOn(_ day: Date) -> [String] {
        Array(Set(tags.filter { $0.day == day }.map(\.tag))).sorted()
    }

    private func scheduleText(_ cost: FixedCostModel) -> String {
        if let day = cost.monthlyDay { return "Monthly on day \(day)" }
        return cost.onceDate.map { "Once on \($0.formatted(.dateTime.day().month()))" } ?? "Once"
    }

    private func delete<T: PersistentModel>(_ items: [T], at offsets: IndexSet) {
        for i in offsets { context.delete(items[i]) }
        SpendService(context: context).commit()
    }
}
