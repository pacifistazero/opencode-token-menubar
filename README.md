# opencode-token-menubar

A tiny macOS menu bar app that shows how much you've spent on
[opencode](https://opencode.ai) today, as a dollar amount and as a percent of a
daily USD budget. It resets at local midnight.

The menu bar shows something like `$57 · 23%` (spend today, percent of budget).
Click it for a breakdown:

- `Today: $57.49 / $250  (23.0%)`
- `Tokens: 81.3M`
- per-model spend

The bar turns orange at 70% of budget and red at 100%.

## How it works

opencode stores every message in a local SQLite database at
`~/.local/share/opencode/opencode.db`. Each assistant message carries a `cost`
(USD) and a `tokens.total`. The app opens that database read-only, sums up every
message created since midnight, and shows the total. Nothing leaves your
machine.

## Build

Requires macOS 12+ and the Swift toolchain (`xcode-select --install` is enough,
no full Xcode).

```bash
./build.sh
open ~/Applications/OpencodeTokens.app
```

## Set your daily budget

The default is $250/day. Change it without recompiling:

```bash
defaults write com.local.OpencodeTokens DailyBudgetUSD 250
```

Then quit and reopen the app.

## Start at login

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"'"$HOME"'/Applications/OpencodeTokens.app", hidden:true}'
```

## Notes

- Read-only: it never writes to the opencode database.
- Refreshes every 30 seconds, or on demand via "Refresh now".
- No dock icon (`LSUIElement`).
