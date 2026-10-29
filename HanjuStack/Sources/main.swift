import Cocoa
import WebKit
import WidgetKit
import CoreText

// 한 주 쌓기 — the board is a local web page; this shell saves it and trades changes with the widget.
// The widget edits its own copy directly (no app launch); the app picks those edits up.
let widgetBundleID = "local.hanju.stack.widget"

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var loaded = false
    var pending: [String] = []
    var lastWidgetStamp: Date?
    var watcher: Timer?
    var clockTimer: Timer?
    lazy var lesser = MenuBarLesser()
    lazy var walker = DesktopLesser()

    let stateURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("HanjuStack/state.json")
    let widgetDocs: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Containers/\(widgetBundleID)/Data/Documents")
    var widgetCopy: URL { widgetDocs.appendingPathComponent("state.json") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        _ = adoptWidgetChanges()   // taps made while the app was closed

        window = NSWindow(contentRect: NSRect(x: 160, y: 160, width: 1040, height: 820),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "한 주 쌓기"
        window.minSize = NSSize(width: 600, height: 560)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("HanjuStackWindow")
        // 투명 매트: frosted window, the page draws on top without its own background.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        let frost = NSVisualEffectView()
        frost.material = .underWindowBackground
        frost.blendingMode = .behindWindow
        frost.state = .active
        window.contentView = frost

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "native")
        let state = (try? String(contentsOf: stateURL, encoding: .utf8)) ?? "null"
        config.userContentController.addUserScript(WKUserScript(source: "window.savedState = \(state);",
                                                                injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
        web.translatesAutoresizingMaskIntoConstraints = false
        frost.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: frost.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: frost.trailingAnchor),
            web.topAnchor.constraint(equalTo: frost.topAnchor, constant: 28),
            web.bottomAnchor.constraint(equalTo: frost.bottomAnchor),
        ])
        let page = Bundle.main.url(forResource: "index", withExtension: "html")!
        let html = (try? String(contentsOf: page, encoding: .utf8)) ?? ""
        web.loadHTMLString("<!doctype html>\n<html lang=\"ko\">\n" + html, baseURL: page.deletingLastPathComponent())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        syncWidget()

        lesser.onOpen = { [weak self] in self?.showWindow() }
        lesser.onCharacter = { [weak self] c in self?.run("window.hanjuSetMascot && window.hanjuSetMascot('\(c)')") }
        let savedPlace = DesktopLesserPlace(rawValue: UserDefaults.standard.string(forKey: "desktopLesser") ?? "") ?? .desktop
        lesser.place = savedPlace
        walker.playback = lesser.playback
        walker.place = savedPlace
        lesser.onPlace = { [weak self] place in
            UserDefaults.standard.set(place.rawValue, forKey: "desktopLesser")
            self?.walker.place = place
        }
        refreshLesser()
        // The 레서 works while a block's time is running, so look again as the clock moves.
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refreshLesser() }

        // While the app is open, pick up widget taps within a second or two.
        watcher = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.pullFromWidget()
        }
    }

    func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "한 주 쌓기 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "편집")
        for (title, sel, key) in [("실행 취소", "undo:", "z"), ("잘라내기", "cut:", "x"), ("복사", "copy:", "c"),
                                  ("붙여넣기", "paste:", "v"), ("전체 선택", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(sel), keyEquivalent: key)
        }
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    // The page posts {action:"save", state:{...}} after every change.
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], body["action"] as? String == "save",
              let state = body["state"], JSONSerialization.isValidJSONObject(state) else { return }
        do {
            try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
            try data.write(to: stateURL, options: .atomic)
            syncWidget()
            refreshLesser()
        } catch {
            NSLog("Save failed: %@", String(describing: error))
        }
    }

    func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// The widget is sandboxed, so it keeps its own copy inside its container. Push ours there.
    func syncWidget() {
        guard FileManager.default.fileExists(atPath: widgetDocs.deletingLastPathComponent().path) else { return }
        do {
            try FileManager.default.createDirectory(at: widgetDocs, withIntermediateDirectories: true)
            let data = (try? Data(contentsOf: stateURL)) ?? Data("{}".utf8)
            try data.write(to: widgetCopy, options: .atomic)
            lastWidgetStamp = modified(widgetCopy)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            NSLog("Widget sync failed: %@", String(describing: error))
        }
    }

    /// If the widget changed its copy since we last wrote it, take the widget's version.
    func adoptWidgetChanges() -> Bool {
        guard let stamp = modified(widgetCopy), stamp != lastWidgetStamp else { return false }
        lastWidgetStamp = stamp
        let ours = modified(stateURL) ?? .distantPast
        guard stamp > ours, let data = try? Data(contentsOf: widgetCopy),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { return false }
        try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: stateURL, options: .atomic)
        return true
    }

    func pullFromWidget() {
        guard adoptWidgetChanges(), let json = try? String(contentsOf: stateURL, encoding: .utf8) else { return }
        run("window.hanjuLoad && window.hanjuLoad(\(json))")
        refreshLesser()
    }

    /// Menu bar 레서 + window look follow the saved state (character, 절전/라이트).
    func refreshLesser() {
        let root = (try? Data(contentsOf: stateURL)).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] } ?? [:]
        lesser.character = root["mascot"] as? String == "passion" ? "passion" : "planner"
        let saver = root["theme"] as? String == "saver"
        walker.character = lesser.character
        if root["theme"] != nil { window?.appearance = NSAppearance(named: saver ? .darkAqua : .aqua) }
        lesser.update(root)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        let queued = pending; pending = []
        queued.forEach { web.evaluateJavaScript($0) }
    }

    func run(_ js: String) {
        if loaded { web.evaluateJavaScript(js) } else { pending.append(js) }
    }

    // hanju://day/2026-10-29 (a weekday name in the widget) opens that week.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, url.scheme == "hanju", url.host == "day" else { return }
        showWindow()
        let day = url.lastPathComponent
        if day.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil {
            run("window.hanjuShowDate && window.hanjuShowDate('\(day)')")
        }
    }

    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) { pullFromWidget() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
