# Spendwise

A personal iOS expense tracker built around one number: **how much you can safely spend today** without running out before your next top-up. It counts what you owe friends, learns your spending patterns, and logs UPI payments automatically from SBI bank SMS through a Shortcuts automation.

Not on the App Store. This is built for one phone and sideloaded.

## What it does

- **Safe to spend today** on the Today tab, home screen widget and lock screen: `(bank + cash − owed to friends − fixed costs − planned events) ÷ days to top-up`. Receivables are never counted.
- **Run-out date**: "At this pace you run out on the 22nd".
- **Automatic capture** from SBI UPI debit/credit and ATM SMS. A Shortcuts *Message* automation calls the **Log Bank SMS** action, and an interactive snippet lets you set the category, split, or mark a transfer without opening the app.
- **Quick Log** for the Action Button: cash spend, "a friend paid for me", "I paid for the group".
- **Friends & IOUs**: debts count against your budget when they're created. Paying a friend the exact amount you owe closes the IOU from the SMS (matched on the payee name). You can send `upi://pay` request links, and the app nudges you to collect on days 1–3 of the month.
- **Forecast**: per-category base rate × weekday × days-since-top-up × event tags (party, exam, fest…), learned from your history and pessimistic by design (80th percentile).
- **Tags** from manual entry, Calendar keywords, and "What was happening on Oct 12?" prompts when a day costs more than 2× its forecast.
- **Pace alerts** instead of fixed limits; JSON backup and restore.

## Install on your iPhone (no Mac)

1. Every push to `main` builds on GitHub Actions and publishes **Spendwise.ipa** to the [`latest` release](../../releases/tag/latest).
2. Install [SideStore](https://sidestore.io) once, using `iloader` from a Linux/Windows/Mac computer for the initial pairing.
3. On the iPhone, open the `latest` release in Safari, download `Spendwise.ipa`, share it to SideStore and install.
4. SideStore re-signs the app every 7 days on the phone with your free Apple ID; keep it refreshed.

Then follow [docs/SHORTCUTS_SETUP.md](docs/SHORTCUTS_SETUP.md) to set up the SMS automations and the Action Button.

## Development

```
Packages/SpendCore/   Pure-Swift logic: SMS parser, ledger, safe-to-spend, forecaster, alerts
Shared/               SwiftData models + summary, used by app and widget
App/                  SwiftUI app, App Intents, services
Widget/               WidgetKit extension
AppTests/             App-level tests (run on CI simulator)
project.yml           XcodeGen spec
```

Run the logic tests on any OS with Docker:

```sh
cd Packages/SpendCore && docker run --rm -v "$PWD":/pkg -w /pkg swift:6.2 swift test
```

On a Mac: `brew install xcodegen && xcodegen generate && open Spendwise.xcodeproj`.

CI (`.github/workflows/ios.yml`) runs the SpendCore tests on Linux, then on macOS generates the project, runs app tests on a simulator, captures demo screenshots (`-demo -tab <name>` launch arguments), and packages an ad-hoc-signed IPA.

### Adding a new SMS format

Paste the failing SMS (it's kept under Settings › Unparsed messages) into a test in `Packages/SpendCore/Tests/SpendCoreTests/SBISMSParserTests.swift`, extend `SBISMSParser`, and push. After updating, tap **Retry** on the Unparsed screen.
