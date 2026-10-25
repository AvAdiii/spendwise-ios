# Shortcuts setup

Takes about five minutes. Open Spendwise once first so its actions appear in Shortcuts.

## 1. Debit SMS → Spendwise

1. **Shortcuts** › **Automation** › **+** › **Message**.
2. **Message Contains**: `debited`. Leave **Sender** empty, because SBI alerts come from several sender IDs (`JD-SBIUPI`, `VM-SBIUPI`…).
3. Choose **Run Immediately**. Turning off **Notify When Run** is optional.
4. **New Blank Automation** › add action **Spendwise › Log Bank SMS**.
5. Tap the **Message** field › **Shortcut Input**, then tap it again and choose **Message Content** (not the whole message object).
6. Done.

## 2. Credit SMS

Repeat with **Message Contains** `credited`. This catches friends paying you back (it closes their IOUs) and top-ups (the app asks for your next top-up date).

## 3. ATM withdrawals (optional)

Repeat with `withdrawn`. ATM cash moves into your cash wallet instead of counting as spending.

## 4. Action Button

**Settings › Action Button** › **Shortcut** › **Spendwise › Quick Log**. Pressing it asks:

- **Cash spend**: amount and category.
- **A friend paid for me**: amount, category, who paid, how many people. Your share becomes a payable immediately.
- **I paid for the group**: amount, category, friends, how many people. If you paid by UPI in the last 20 minutes, the split attaches to that SMS transaction instead of creating a new one.

You can also use Back Tap (**Settings › Accessibility › Touch › Back Tap**).

## 5. Widgets

Long-press the home screen › **Edit** › **Add Widget** › Spendwise. The lock screen supports inline, circular and rectangular widgets.

## Checks

- **Transactions filter**: iOS can file bank alerts under Messages › Transactions. After setup, make a ₹1 UPI payment and confirm Spendwise logged it.
- **Failure fallback**: SMS that can't be parsed are kept under **Settings › Unparsed messages**, never dropped. **Settings › Paste an SMS** logs one manually.
- **Reconciliation**: about weekly, the Today tab asks you to confirm your bank balance. A mismatch means an automation missed something.
- **UPI Lite** payments don't produce per-payment SMS. Disable UPI Lite, or log those with Quick Log.

## Friends and settlement matching

SBI SMS shows the payee *name* (cut to 16 characters), not their UPI ID. In **Friends › Edit**, add each friend's name exactly as it appears after `trf to` (e.g. `PRIYA SHARMA`). Recent person-like payees are suggested. Once added:

- Paying a friend **exactly** what you owe auto-settles.
- Paying a friend a different amount while you owe them is flagged: "Is this settling the ₹X you owe?"
- A friend paying you settles what they owe; any extra is logged as income.
