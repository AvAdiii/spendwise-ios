# Spendwise v1 — Design

Date: 2026-10-25 · Source: `Student Expense Tracker Product Plan.md` · Scope: plan phases 1–3

## Constraints

- Personal sideload to one iPhone 17 (iOS 26). No App Store, no TestFlight.
- Developer has no Mac. Code is written on Linux; iOS targets are built on GitHub Actions macOS runners (public repo). Install the unsigned `.ipa` with SideStore (free Apple ID, on-device 7-day refresh).
- Free Apple ID → no iCloud/CloudKit, no push. Local notifications, App Groups, App Intents and WidgetKit are fine.
- Bank: SBI. UPI SMS carries no VPA (payee name truncated to 16 chars) and no balance.
- Top-ups are irregular; the user sets "next top-up date".
- No LLM categorisation: rules table, unknown merchants go to "Uncategorised" and the user picks once.

## Architecture

```
project.yml                 XcodeGen spec (app + widget + tests)
Packages/SpendCore/         Pure Swift (Foundation only); tested on Linux in Docker (swift:6.2)
App/                        SwiftUI app, SwiftData models, App Intents, snippets
Widget/                     WidgetKit extension
.github/workflows/ios.yml   Build, test, screenshots, unsigned .ipa
docs/SHORTCUTS_SETUP.md     Automation setup guide
```

SpendCore works on value types only. The app maps SwiftData `@Model`s to/from them. The SwiftData store lives in the App Group container `group.<bundle>.shared` so the app, intents and widget share one database.

### SpendCore modules

| Module | Responsibility |
|---|---|
| Parsing | `SBISMSParser`: debit/credit SMS → `ParsedSMS {direction, amount, date, payee, ref, account}`; unknown → nil |
| Categorize | `RulesCategorizer`: case-insensitive substring rules, longest match wins; `learn(payee:category:)` |
| Ledger | `SplitCalculator`, `FriendBalances`, `SettlementMatcher` |
| Budget | `SafeToSpendEngine` |
| Forecast | `BaselineForecaster`, `RunOutProjector` |
| Alerts | `PaceAlertEngine`, `AnomalyDetector`, `CollectionNudge` |
| UPI | `UPILinkBuilder` |

## Money model

Transaction kinds and their effects:

| Kind | Bank | Cash | Spending |
|---|---|---|---|
| `spend` (source upi) | −amount | 0 | myShare |
| `spend` (source cash) | 0 | −amount | myShare |
| `friendPaid` | 0 | 0 | myShare; creates payable |
| `income` | +amount | 0 | 0 |
| `settleOut` | −amount | 0 | 0; reduces payable |
| `settleIn` | +amount | 0 | 0; reduces receivable |
| `transfer` (ATM) | −amount | +amount | 0 |
| `transfer` (self, out of tracked account) | −amount | 0 | 0 |

"I paid for group": bank −total, myShare = total − Σ friend shares, receivables per friend.

Safe-to-spend:

```
liquid    = checkpoint.balance + Σ bank deltas of txns after checkpoint.date + cashWallet
committed = Σ open payables + Σ fixed costs due in [today, nextTopUp) + Σ planned events in [today, nextTopUp)
available = liquid − committed
safeToday = available / max(1, days(today → nextTopUp))
```

Receivables are never added. The cash wallet is derived the same way from its own checkpoint.

### Settlement matching (on debit/credit SMS)

1. Find the friend whose alias matches the payee (case-insensitive; alias equal to payee, or one is a prefix of the other ≥ 8 chars, because SBI truncates).
2. Debit + friend has open payable with amount == payable total (±₹1) → auto `settleOut`.
3. Debit + friend has an open payable but amounts differ → log `spend`, `needsReview = true` with suggestion "Settling?".
4. Credit + friend has receivables → `settleIn` up to the receivable amount; any excess is `income`.
5. Credit without a friend match and amount ≥ ₹1000 → `income`, prompt for next top-up date.

Duplicate `ref` → ignored. Unparseable text → stored as `UnparsedMessage`.

## Capture

- `LogBankSMSIntent(text)`: parse → match → categorise → save → reload widgets → interactive snippet (category chips, Split, Not spending, settle confirmation).
- `QuickLogIntent(mode: cash/friendPaid/paidForGroup, amount, category, friends, people, myShare)`: for the Action Button.
- `SettleIOUIntent`, `SetCategoryIntent`, `MarkTransferIntent`: used by snippet buttons.
- `AppShortcutsProvider` exposes Log Bank SMS / Quick Log / Safe to Spend.

## UI

Tabs: Today, Activity, Friends, Plan, Settings. Widget: systemSmall, systemMedium, accessoryRectangular/Inline/Circular. HIG: system fonts, semantic colours, SF Symbols, Dynamic Type, dark mode.

## Forecasting (phase 3)

- History < 28 days: pace = spending since last top-up / days elapsed (min 1).
- Otherwise multiplicative baseline per category: `base × dow[weekday] × phase[bucket] × Π tag[tag]`. Buckets are days since last top-up: 0–3, 4–10, 11–20, 21+. Factor = (sum_obs + k·1·expected) / ((n + k)·expected) with k = 4 (shrinkage toward 1).
- Pessimism scale = q80 of daily actual/expected ratios (≥ 1.0, clamp ≤ 3.0).
- Run-out: step day by day from tomorrow; first day cumulative pessimistic spend > available → run-out date; none before nextTopUp → "lasts".
- Tags: manual (day or range), EventKit keyword match (party, club, trip, travel, exam, fest, felicity, holiday), anomaly prompt answers.
- Anomaly: day actual > 2× expected and ≥ ₹300 → next-morning notification with text input → tag.

## Alerts (local)

- Pace: spentFraction − timeFraction > 0.15 → fire once per top-up period per 10% band.
- Tagged-event warning: tag within next 3 days whose learned extra cost > remaining safe budget share.
- Collection nudge: days 1–3 of the month when receivables or payables are open (once per day).

## Testing

- SpendCore: swift-testing, run on Linux via `docker run swift:6.2 swift test`.
- CI (macos-26, Xcode 26): `swift test` for SpendCore, then xcodegen → build-for-testing → test on iPhone 17 simulator → demo-data launch + `simctl io screenshot` → unsigned `.ipa` artifact.

## Out of scope (v1)

LightGBM, SBI statement import (awaits a sample), Live Activity, weekly digest, subscription detection, Gmail, Splitwise sync.
