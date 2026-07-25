import Cocoa
import Foundation
import Darwin

private struct Arguments {
    var root: String
    var event: String
    var message: String
    var timeout: TimeInterval

    static func parse() -> Arguments {
        var root = FileManager.default.currentDirectoryPath
        var event = "stop"
        var message = "Claude is ready for input"
        var timeout: TimeInterval = 18

        var index = 1
        let args = CommandLine.arguments
        while index < args.count {
            let key = args[index]
            let value = index + 1 < args.count ? args[index + 1] : ""
            switch key {
            case "--root":
                root = value
                index += 2
            case "--event":
                event = value
                index += 2
            case "--message":
                message = value
                index += 2
            case "--timeout":
                timeout = TimeInterval(value) ?? timeout
                index += 2
            default:
                index += 1
            }
        }

        return Arguments(root: root, event: event, message: message, timeout: timeout)
    }
}

private final class ProcessLock {
    private var fd: Int32 = -1

    func acquire() -> Bool {
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("claude-pet-overlays.lock")
        fd = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        if fd < 0 {
            return true
        }
        return flock(fd, LOCK_EX | LOCK_NB) == 0
    }

    deinit {
        if fd >= 0 {
            flock(fd, LOCK_UN)
            close(fd)
        }
    }
}

private struct UsageConfig {
    var sessionLimit: Double = 8_000_000
    var weeklyLimit: Double = 60_000_000
    var modelLimit: Double = 15_000_000
    var modelKeyword: String = "auto"
    var weeklyResetDay: Int?
    var weeklyResetHour: Int = 20

    static func load() -> UsageConfig {
        var config = UsageConfig()

        let env = ProcessInfo.processInfo.environment
        if let value = env["CLAUDE_PET_SESSION_LIMIT"], let parsed = Double(value) {
            config.sessionLimit = parsed
        }
        if let value = env["CLAUDE_PET_WEEKLY_LIMIT"], let parsed = Double(value) {
            config.weeklyLimit = parsed
        }
        if let value = env["CLAUDE_PET_OPUS_LIMIT"], let parsed = Double(value) {
            config.modelLimit = parsed
        }
        if let value = env["CLAUDE_PET_MODEL"], !value.isEmpty {
            config.modelKeyword = value.lowercased()
        }

        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude_pet.json")
        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return config
        }

        if let value = number(object["session_limit"]) {
            config.sessionLimit = value
        }
        if let value = number(object["weekly_limit"]) {
            config.weeklyLimit = value
        }
        if let value = number(object["opus_limit"]) {
            config.modelLimit = value
        }
        if let value = object["model_keyword"] as? String, !value.isEmpty {
            config.modelKeyword = value.lowercased()
        }
        if let value = number(object["weekly_reset_day"]) {
            config.weeklyResetDay = Int(value)
        }
        if let value = number(object["weekly_reset_hour"]) {
            config.weeklyResetHour = Int(value)
        }

        return config
    }
}

private struct UsageEntry {
    let date: Date
    let weighted: Double
    let model: String
}

private struct Gauge {
    let title: String
    let pct: Double
    let detail: String
}

private struct UsageSnapshot {
    let gauges: [Gauge]
    let maxPct: Double
    let modelKeyword: String
    let lastActivity: Date?
    let hasData: Bool
    let source: String
}

private enum TokenScanner {
    private static let sessionHours: TimeInterval = 5 * 60 * 60
    private static let premiumFamilies = ["fable", "mythos", "opus"]
    private static let oauthUsageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func snapshot() -> UsageSnapshot {
        if let exact = fetchExactGauges(), !exact.isEmpty {
            return UsageSnapshot(
                gauges: exact,
                maxPct: exact.map(\.pct).max() ?? 0,
                modelKeyword: exact.first(where: { !["Session", "Weekly", "Credit"].contains($0.title) })?.title.lowercased() ?? "opus",
                lastActivity: nil,
                hasData: true,
                source: "Exact mode"
            )
        }

        let config = UsageConfig.load()
        let now = Date()
        let since = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let entries = parseEntries(since: since)
        let weekStart = weeklyWindowStart(config: config, now: now)
        let weeklyEntries = entries.filter { entry in
            guard let weekStart else { return true }
            return entry.date >= weekStart
        }
        let modelKeyword = resolveModelKeyword(config.modelKeyword, weeklyEntries: weeklyEntries, allEntries: entries)

        let weeklyUsed = weeklyEntries.reduce(0) { $0 + $1.weighted }
        let modelUsed = weeklyEntries
            .filter { $0.model.contains(modelKeyword) }
            .reduce(0) { $0 + $1.weighted }

        let session = currentSession(entries: entries, now: now)
        let weeklyReset: Date?
        if let weekStart {
            weeklyReset = weekStart.addingTimeInterval(7 * 24 * 60 * 60)
        } else {
            weeklyReset = entries.first?.date.addingTimeInterval(7 * 24 * 60 * 60)
        }

        let gauges = [
            localGauge(title: "Session", used: session.used, limit: config.sessionLimit, reset: session.reset),
            localGauge(title: "Weekly", used: weeklyUsed, limit: config.weeklyLimit, reset: weeklyReset),
            localGauge(title: modelKeyword.capitalized, used: modelUsed, limit: config.modelLimit, reset: weeklyReset)
        ]

        return UsageSnapshot(
            gauges: gauges,
            maxPct: gauges.map(\.pct).max() ?? 0,
            modelKeyword: modelKeyword,
            lastActivity: entries.last?.date,
            hasData: !entries.isEmpty,
            source: "Log estimate"
        )
    }

    private static func localGauge(title: String, used: Double, limit: Double, reset: Date?) -> Gauge {
        let pct = limit > 0 ? min(100, max(0, used / limit * 100)) : 0
        let left = max(0, limit - used)
        let detail = "\(formatTokens(left)) left" + resetText(reset)
        return Gauge(title: title, pct: pct, detail: detail)
    }

    private static func fetchExactGauges() -> [Gauge]? {
        guard let token = oauthToken() else {
            return nil
        }

        var request = URLRequest(url: oauthUsageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var responseData: Data?
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                responseData = data
            }
            semaphore.signal()
        }
        task.resume()
        if semaphore.wait(timeout: .now() + 8) == .timedOut {
            task.cancel()
            return nil
        }

        guard let data = responseData,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return parseExactGauges(object)
    }

    private static func oauthToken() -> String? {
        if let token = tokenFromCredentialsFile() {
            return token
        }
        return tokenFromSecurityTool()
    }

    private static func tokenFromCredentialsFile() -> String? {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        guard let data = try? Data(contentsOf: path),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = object["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty else {
            return nil
        }
        return token
    }

    private static func tokenFromSecurityTool() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }

        if semaphore.wait(timeout: .now() + 8) == .timedOut {
            process.terminate()
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauth = object["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty else {
            return nil
        }
        return token
    }

    private static func parseExactGauges(_ object: [String: Any]) -> [Gauge]? {
        var rows: [(order: Int, gauge: Gauge)] = []

        if let limits = object["limits"] as? [[String: Any]] {
            for limit in limits {
                guard let kind = limit["kind"] as? String,
                      let percent = number(limit["percent"]) else {
                    continue
                }
                let lowerKind = kind.lowercased()
                let reset = parseReset(limit["resets_at"])
                let pct = min(100, max(0, percent))

                if lowerKind.contains("session") || lowerKind.contains("five_hour") {
                    rows.append((0, Gauge(title: "Session", pct: pct, detail: exactDetail(reset: reset))))
                } else if lowerKind.contains("weekly") || lowerKind.contains("seven") {
                    if lowerKind.contains("scoped") || lowerKind.contains("model") {
                        if let title = scopedModelTitle(limit) {
                            rows.append((2, Gauge(title: title, pct: pct, detail: exactDetail(reset: reset))))
                        }
                    } else {
                        rows.append((1, Gauge(title: "Weekly", pct: pct, detail: exactDetail(reset: reset))))
                    }
                } else if lowerKind.contains("extra") || lowerKind.contains("credit") {
                    rows.append((9, Gauge(title: "Credit", pct: pct, detail: exactDetail(reset: reset))))
                }
            }
        }

        if let extra = object["extra_usage"] as? [String: Any],
           let enabled = extra["is_enabled"] as? Bool,
           enabled,
           let percent = number(extra["utilization"]) {
            rows.append((9, Gauge(title: "Credit", pct: min(100, max(0, percent)), detail: exactDetail(reset: parseReset(extra["resets_at"])))))
        }

        if rows.isEmpty {
            rows = legacyUtilizationRows(object)
        }

        guard !rows.isEmpty else {
            return nil
        }

        var seen = Set<String>()
        return rows
            .sorted { $0.order < $1.order }
            .compactMap { row in
                if seen.contains(row.gauge.title) {
                    return nil
                }
                seen.insert(row.gauge.title)
                return row.gauge
            }
    }

    private static func scopedModelTitle(_ limit: [String: Any]) -> String? {
        guard let scope = limit["scope"] as? [String: Any],
              let model = scope["model"] as? [String: Any] else {
            return nil
        }
        return model["display_name"] as? String ?? model["id"] as? String
    }

    private static func legacyUtilizationRows(_ object: [String: Any]) -> [(order: Int, gauge: Gauge)] {
        var rows: [(order: Int, gauge: Gauge)] = []

        func walk(_ value: Any, hint: String) {
            if let array = value as? [Any] {
                for item in array {
                    walk(item, hint: hint)
                }
                return
            }

            guard let dict = value as? [String: Any] else {
                return
            }

            if let utilization = number(dict["utilization"]) {
                let lowerHint = hint.lowercased()
                let reset = parseReset(dict["resets_at"] ?? dict["reset_at"] ?? dict["resets"])
                let pct = min(100, max(0, utilization))
                let title: String
                let order: Int

                if lowerHint.contains("session") || lowerHint.contains("five_hour") {
                    title = "Session"
                    order = 0
                } else if lowerHint.contains("weekly") || lowerHint.contains("seven_day") {
                    if let family = premiumFamilies.first(where: { lowerHint.contains($0) }) {
                        title = family.capitalized
                        order = 2
                    } else {
                        title = "Weekly"
                        order = 1
                    }
                } else if lowerHint.contains("credit") || lowerHint.contains("extra") {
                    title = "Credit"
                    order = 9
                } else {
                    title = hint
                    order = 5
                }

                rows.append((order, Gauge(title: title, pct: pct, detail: exactDetail(reset: reset))))
                return
            }

            for (key, child) in dict {
                walk(child, hint: hint.isEmpty ? key : "\(hint)_\(key)")
            }
        }

        walk(object, hint: "")
        return rows
    }

    private static func parseReset(_ value: Any?) -> Date? {
        if let string = value as? String {
            return parseDate(string)
        }
        if let timestamp = number(value) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }

    private static func exactDetail(reset: Date?) -> String {
        var detail = "server value"
        let reset = resetText(reset)
        if !reset.isEmpty {
            detail += reset
        }
        return detail
    }

    private static func parseEntries(since: Date) -> [UsageEntry] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let roots = [
            "\(home)/.claude/projects",
            "\(home)/.config/claude/projects"
        ]
        let decoder = JSONLineDecoder()
        var entries: [UsageEntry] = []
        var seen = Set<String>()

        for root in roots where FileManager.default.fileExists(atPath: root) {
            guard let enumerator = FileManager.default.enumerator(atPath: root) else {
                continue
            }
            for case let relPath as String in enumerator {
                guard relPath.hasSuffix(".jsonl") else { continue }
                let path = (root as NSString).appendingPathComponent(relPath)
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let modified = attrs[.modificationDate] as? Date,
                      modified >= since else {
                    continue
                }
                decoder.read(path: path) { object in
                    guard let rawTimestamp = object["timestamp"] as? String,
                          let date = parseDate(rawTimestamp),
                          date >= since else {
                        return
                    }
                    let message = object["message"] as? [String: Any] ?? [:]
                    let usage = message["usage"] as? [String: Any] ?? object["usage"] as? [String: Any] ?? [:]
                    guard !usage.isEmpty else { return }

                    let messageID = message["id"] as? String
                    let requestID = object["requestId"] as? String
                    if messageID != nil || requestID != nil {
                        let key = "\(messageID ?? "")|\(requestID ?? "")"
                        if seen.contains(key) {
                            return
                        }
                        seen.insert(key)
                    }

                    let input = number(usage["input_tokens"]) ?? 0
                    let output = (number(usage["output_tokens"]) ?? 0) * 5.0
                    let cacheCreate = (number(usage["cache_creation_input_tokens"]) ?? 0) * 1.25
                    let cacheRead = (number(usage["cache_read_input_tokens"]) ?? 0) * 0.1
                    let total = input + output + cacheCreate + cacheRead
                    guard total > 0 else { return }

                    let model = (message["model"] as? String ?? object["model"] as? String ?? "").lowercased()
                    entries.append(UsageEntry(date: date, weighted: total, model: model))
                }
            }
        }

        return entries.sorted { $0.date < $1.date }
    }

    private static func currentSession(entries: [UsageEntry], now: Date) -> (used: Double, reset: Date?) {
        guard !entries.isEmpty else {
            return (0, nil)
        }

        let calendar = Calendar.current
        var blockStart: Date?
        var blockEnd: Date?

        for entry in entries {
            if blockEnd == nil || entry.date >= blockEnd! {
                let start = calendar.dateInterval(of: .hour, for: entry.date)?.start ?? entry.date
                blockStart = start
                blockEnd = start.addingTimeInterval(sessionHours)
            }
        }

        guard let start = blockStart, let end = blockEnd, now < end else {
            return (0, nil)
        }

        let used = entries
            .filter { $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.weighted }

        return (used, end)
    }

    private static func weeklyWindowStart(config: UsageConfig, now: Date) -> Date? {
        guard let resetDay = config.weeklyResetDay else {
            return nil
        }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let weekday = calendar.component(.weekday, from: now)
        let mondayIndex = (weekday + 5) % 7
        let daysBack = (mondayIndex - resetDay + 7) % 7

        guard var start = calendar.date(byAdding: .day, value: -daysBack, to: now) else {
            return nil
        }

        var parts = calendar.dateComponents([.year, .month, .day], from: start)
        parts.hour = config.weeklyResetHour
        parts.minute = 0
        parts.second = 0
        start = calendar.date(from: parts) ?? start
        if start > now {
            start = calendar.date(byAdding: .day, value: -7, to: start) ?? start
        }
        return start
    }

    private static func resolveModelKeyword(_ configured: String, weeklyEntries: [UsageEntry], allEntries: [UsageEntry]) -> String {
        let configured = configured.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !configured.isEmpty && configured != "auto" {
            return configured
        }

        for pool in [weeklyEntries, allEntries] {
            for family in premiumFamilies where pool.contains(where: { $0.model.contains(family) }) {
                return family
            }
        }
        return "opus"
    }
}

private final class JSONLineDecoder {
    func read(path: String, handler: @escaping ([String: Any]) -> Void) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let content = String(data: data, encoding: .utf8) else {
            return
        }

        content.enumerateLines { line, _ in
            guard let lineData = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                return
            }
            handler(object)
        }
    }
}

private final class OverlayView: NSView {
    var showsContent = false
    var frames: [NSImage] = []
    var frameIndex = 0
    var message = ""
    var event = "stop"
    var snapshot = UsageSnapshot(gauges: [], maxPct: 0, modelKeyword: "opus", lastActivity: nil, hasData: false, source: "Log estimate")
    var dismiss: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        dismiss?()
    }

    override func mouseDown(with event: NSEvent) {
        dismiss?()
    }

    override func rightMouseDown(with event: NSEvent) {
        dismiss?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.0, alpha: 0.76).setFill()
        bounds.fill()

        guard showsContent else {
            return
        }

        let panelWidth = min(840, max(560, bounds.width - 120))
        let panelHeight = min(440, max(360, bounds.height - 120))
        let panel = NSRect(
            x: bounds.midX - panelWidth / 2,
            y: bounds.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )

        drawPanel(panel)

        let leftX = panel.minX + 42
        let topY = panel.maxY - 54
        drawText(statusTitle(), in: NSRect(x: leftX, y: topY, width: panel.width - 84, height: 28), size: 24, weight: .semibold, color: .white)
        drawText(message, in: NSRect(x: leftX, y: topY - 36, width: panel.width - 84, height: 24), size: 15, weight: .regular, color: color(0.72, 0.74, 0.80, 1))

        let petSize = min(230, max(170, panel.width * 0.29))
        let petRect = NSRect(
            x: panel.maxX - petSize - 52,
            y: panel.minY + 64,
            width: petSize,
            height: petSize * 208.0 / 192.0
        )
        drawPet(in: petRect)

        let gaugeWidth = max(300, panel.width - petSize - 150)
        var gaugeY = panel.maxY - 152
        if snapshot.gauges.isEmpty {
            drawText("No Claude Code usage logs found yet.", in: NSRect(x: leftX, y: gaugeY, width: gaugeWidth, height: 24), size: 15, weight: .medium, color: color(0.84, 0.85, 0.89, 1))
            drawText("Start using Claude Code and this overlay will show token gauges here.", in: NSRect(x: leftX, y: gaugeY - 28, width: gaugeWidth, height: 24), size: 13, weight: .regular, color: color(0.58, 0.60, 0.66, 1))
        } else {
            for gauge in snapshot.gauges {
                drawGauge(gauge, in: NSRect(x: leftX, y: gaugeY, width: gaugeWidth, height: 62))
                gaugeY -= 78
            }
        }

        let footer = footerText()
        drawText(footer, in: NSRect(x: leftX, y: panel.minY + 32, width: panel.width - 84, height: 20), size: 12, weight: .regular, color: color(0.48, 0.50, 0.56, 1))
    }

    private func drawPanel(_ rect: NSRect) {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.38)
        shadow.shadowBlurRadius = 28
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.set()

        let panelPath = NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22)
        color(0.08, 0.09, 0.12, 0.96).setFill()
        panelPath.fill()
        NSShadow().set()

        color(0.30, 0.32, 0.38, 0.42).setStroke()
        panelPath.lineWidth = 1
        panelPath.stroke()
    }

    private func drawPet(in rect: NSRect) {
        guard !frames.isEmpty else {
            return
        }
        let image = frames[frameIndex % frames.count]
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
    }

    private func drawGauge(_ gauge: Gauge, in rect: NSRect) {
        let title = gauge.title
        let value = "\(formatPct(gauge.pct)) used"
        let detail = gauge.detail

        drawText(title, in: NSRect(x: rect.minX, y: rect.maxY - 22, width: 150, height: 20), size: 17, weight: .semibold, color: .white)
        drawText(value, in: NSRect(x: rect.minX + 126, y: rect.maxY - 21, width: 110, height: 20), size: 14, weight: .medium, color: color(0.76, 0.77, 0.82, 1))
        drawText(detail, in: NSRect(x: rect.minX + 238, y: rect.maxY - 21, width: rect.width - 238, height: 20), size: 13, weight: .regular, color: color(0.58, 0.60, 0.66, 1))

        let track = NSRect(x: rect.minX, y: rect.minY + 14, width: rect.width, height: 12)
        let trackPath = NSBezierPath(roundedRect: track, xRadius: 6, yRadius: 6)
        color(0.28, 0.29, 0.34, 1).setFill()
        trackPath.fill()

        let fillWidth = max(8, track.width * CGFloat(gauge.pct / 100.0))
        let fill = NSRect(x: track.minX, y: track.minY, width: min(track.width, fillWidth), height: track.height)
        let fillPath = NSBezierPath(roundedRect: fill, xRadius: 6, yRadius: 6)
        gaugeColor(gauge.pct).setFill()
        fillPath.fill()
    }

    private func statusTitle() -> String {
        if snapshot.maxPct >= 85 {
            return "Claude Pet: token limit is tight"
        }
        if snapshot.maxPct >= 50 {
            return "Claude Pet: usage is warming up"
        }
        if event == "ask" {
            return "Claude Pet: answer needed"
        }
        return "Claude Pet: ready"
    }

    private func footerText() -> String {
        if snapshot.source == "Exact mode" {
            return "Exact mode from Claude Code. Click, press any key, or wait to dismiss."
        }
        guard let last = snapshot.lastActivity else {
            return "Click, press any key, or wait to dismiss."
        }
        return "Last Claude Code activity \(relativeTime(last)) ago. Click, press any key, or wait to dismiss."
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let args: Arguments
    private let lock: ProcessLock
    private let snapshot: UsageSnapshot
    private let animationState: String
    private var windows: [NSWindow] = []
    private var timer: Timer?
    private var views: [OverlayView] = []

    init(args: Arguments, lock: ProcessLock) {
        self.args = args
        self.lock = lock
        self.snapshot = TokenScanner.snapshot()
        self.animationState = chooseAnimation(event: args.event, maxPct: snapshot.maxPct)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let screens = NSScreen.screens
        let mainScreen = NSScreen.main ?? screens.first

        for screen in screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = .init(Int(CGWindowLevelForKey(.screenSaverWindow)))
            window.isOpaque = false
            window.backgroundColor = .clear
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false

            let view = OverlayView(frame: screen.frame)
            view.showsContent = screen == mainScreen
            view.frames = loadFrames(root: args.root, state: animationState)
            view.message = args.message
            view.event = args.event
            view.snapshot = snapshot
            view.dismiss = { [weak self] in
                self?.dismiss()
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)

            windows.append(window)
            views.append(view)
        }

        NSApp.activate(ignoringOtherApps: true)

        let frameInterval = interval(for: animationState)
        timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }

        if args.timeout > 0 {
            Timer.scheduledTimer(withTimeInterval: args.timeout, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    private func tick() {
        for view in views {
            guard !view.frames.isEmpty else { continue }
            view.frameIndex = (view.frameIndex + 1) % view.frames.count
            view.needsDisplay = true
        }
    }

    private func dismiss() {
        timer?.invalidate()
        timer = nil
        NSApp.terminate(nil)
    }

    private func loadFrames(root: String, state: String) -> [NSImage] {
        let fileManager = FileManager.default
        let stateDir = (root as NSString).appendingPathComponent("frames/\(state)")
        let fallbackDir = (root as NSString).appendingPathComponent("frames/idle")
        let dir = fileManager.fileExists(atPath: stateDir) ? stateDir : fallbackDir
        guard let names = try? fileManager.contentsOfDirectory(atPath: dir) else {
            return []
        }
        return names
            .filter { $0.hasSuffix(".png") }
            .sorted()
            .compactMap { NSImage(contentsOfFile: (dir as NSString).appendingPathComponent($0)) }
    }
}

private func chooseAnimation(event: String, maxPct: Double) -> String {
    if maxPct >= 85 {
        return "failed"
    }
    if maxPct >= 50 {
        return "waiting"
    }
    if event == "ask" {
        return "review"
    }
    return "waving"
}

private func interval(for state: String) -> TimeInterval {
    switch state {
    case "failed":
        return 0.09
    case "waiting":
        return 0.13
    case "review":
        return 0.16
    case "waving":
        return 0.18
    default:
        return 0.20
    }
}

private func number(_ value: Any?) -> Double? {
    if let value = value as? Double {
        return value
    }
    if let value = value as? Int {
        return Double(value)
    }
    if let value = value as? String {
        return Double(value)
    }
    if let value = value as? NSNumber {
        return value.doubleValue
    }
    return nil
}

private let isoWithFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let isoBasic = ISO8601DateFormatter()

private func parseDate(_ value: String) -> Date? {
    isoWithFractional.date(from: value) ?? isoBasic.date(from: value)
}

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

private func gaugeColor(_ pct: Double) -> NSColor {
    if pct >= 85 {
        return color(1.0, 0.29, 0.33, 1)
    }
    if pct >= 50 {
        return color(1.0, 0.72, 0.30, 1)
    }
    return color(0.22, 0.86, 0.42, 1)
}

private func drawText(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    (text as NSString).draw(in: rect, withAttributes: attrs)
}

private func formatPct(_ value: Double) -> String {
    if value >= 10 {
        return "\(Int(round(value)))%"
    }
    return String(format: "%.1f%%", value)
}

private func formatTokens(_ value: Double) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1fM", value / 1_000_000)
    }
    if value >= 1_000 {
        return String(format: "%.0fK", value / 1_000)
    }
    return "\(Int(value))"
}

private func resetText(_ date: Date?) -> String {
    guard let date else {
        return ""
    }
    let remaining = max(0, date.timeIntervalSinceNow)
    let minutes = Int(remaining / 60)
    let hours = minutes / 60
    let days = hours / 24
    if days > 0 {
        return " - reset in \(days)d \(hours % 24)h"
    }
    if hours > 0 {
        return " - reset in \(hours)h \(minutes % 60)m"
    }
    return " - reset in \(max(1, minutes))m"
}

private func relativeTime(_ date: Date) -> String {
    let seconds = max(0, Int(Date().timeIntervalSince(date)))
    if seconds < 60 {
        return "\(seconds)s"
    }
    let minutes = seconds / 60
    if minutes < 60 {
        return "\(minutes)m"
    }
    let hours = minutes / 60
    if hours < 24 {
        return "\(hours)h"
    }
    return "\(hours / 24)d"
}

private let args = Arguments.parse()
private let lock = ProcessLock()
guard lock.acquire() else {
    exit(0)
}

private let app = NSApplication.shared
private let delegate = AppDelegate(args: args, lock: lock)
app.delegate = delegate
app.run()
