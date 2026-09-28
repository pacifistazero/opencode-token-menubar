// OpencodeTokens - a tiny macOS menu bar app.
// Shows today's opencode token usage and cost as a percent of a daily USD budget.
// Resets at local midnight. Reads ~/.local/share/opencode/opencode.db read-only.

import AppKit
import SQLite3

// --- config ------------------------------------------------------------------
// Daily budget in USD. Override with defaults: `defaults write com.local.OpencodeTokens DailyBudgetUSD 250`
let defaultBudgetUSD = 250.0
// -----------------------------------------------------------------------------

let dbPath = ("~/.local/share/opencode/opencode.db" as NSString).expandingTildeInPath

struct DayUsage {
    var cost: Double = 0
    var tokens: Int = 0
    var models: [String: (tok: Int, cost: Double)] = [:]
}

func midnightMillis() -> Int64 {
    let cal = Calendar.current
    let start = cal.startOfDay(for: Date())
    return Int64(start.timeIntervalSince1970 * 1000)
}

// Minimal JSON pull: we only need cost, tokens.total, modelID. Use JSONSerialization.
func todayUsage() -> DayUsage {
    var u = DayUsage()
    var db: OpaquePointer?
    // read-only, immutable-safe open
    guard sqlite3_open_v2("file:\(dbPath)?mode=ro", &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
        return u
    }
    defer { sqlite3_close(db) }

    var stmt: OpaquePointer?
    let sql = "SELECT data FROM message WHERE time_created>=?"
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return u }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_int64(stmt, 1, midnightMillis())

    while sqlite3_step(stmt) == SQLITE_ROW {
        guard let c = sqlite3_column_text(stmt, 0) else { continue }
        let jsonStr = String(cString: c)
        guard let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = obj["tokens"] as? [String: Any] else { continue }
        let total = (tokens["total"] as? Int) ?? 0
        let cost = (obj["cost"] as? Double) ?? 0
        let model = (obj["modelID"] as? String) ?? "?"
        u.tokens += total
        u.cost += cost
        var m = u.models[model] ?? (0, 0)
        m.tok += total; m.cost += cost
        u.models[model] = m
    }
    return u
}

func human(_ n: Int) -> String {
    let d = Double(n)
    if d >= 1e9 { return String(format: "%.1fB", d/1e9) }
    if d >= 1e6 { return String(format: "%.1fM", d/1e6) }
    if d >= 1e3 { return String(format: "%.1fK", d/1e3) }
    return "\(n)"
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?

    func budget() -> Double {
        let v = UserDefaults.standard.double(forKey: "DailyBudgetUSD")
        return v > 0 ? v : defaultBudgetUSD
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let u = todayUsage()
        let bud = budget()
        let pct = bud > 0 ? u.cost / bud * 100 : 0

        // menu bar title: "$57 · 23%"
        let title = String(format: "$%.0f · %.0f%%", u.cost, pct)
        if let button = statusItem.button {
            button.contentTintColor = nil
            if pct >= 70 {
                let color: NSColor = pct >= 100 ? .systemRed : .systemOrange
                button.attributedTitle = NSAttributedString(string: title, attributes: [
                    .foregroundColor: color,
                    .font: NSFont.menuBarFont(ofSize: 0),
                ])
            } else {
                button.title = title
            }
        }

        let menu = NSMenu()
        menu.addItem(withTitle: String(format: "Today: $%.2f / $%.0f  (%.1f%%)", u.cost, bud, pct),
                     action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Tokens: \(human(u.tokens))  (\(u.tokens.formatted()))",
                     action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        for (m, v) in u.models.sorted(by: { $0.value.tok > $1.value.tok }) {
            menu.addItem(withTitle: String(format: "%@  %@  $%.2f", m, human(v.tok), v.cost),
                         action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        let r = NSMenuItem(title: "Refresh now", action: #selector(refreshNow), keyEquivalent: "r")
        r.target = self; menu.addItem(r)
        let q = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(q)
        statusItem.menu = menu
    }

    @objc func refreshNow() { refresh() }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
