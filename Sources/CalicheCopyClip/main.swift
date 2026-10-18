import AppKit
import Combine
import SwiftUI

/// Menu bar app (no Dock icon): a status item that opens the history popover.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ClipStore(demo: CommandLine.arguments.contains("--demo"))
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var hotKey: HotKey?
    private var defaultsObserver: AnyCancellable?
    private let settingsTab = SettingsTabState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Caliche CopyClip")
            button.toolTip = "Caliche CopyClip"
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover.behavior = .transient
        let hosting = NSHostingController(rootView: HistoryView(
            store: store,
            openSettings: { [weak self] in self?.openSettings() },
            close: { [weak self] in self?.popover.performClose(nil) }
        ))
        // A fixed size keeps SwiftUI from resizing the popover after it opens,
        // which pushed its top above the screen.
        hosting.sizingOptions = []
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 360, height: 480)

        store.startMonitoring()

        hotKey = HotKey { [weak self] in self?.togglePopover() }
        registerHotKey()
        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.registerHotKey() }

        // Used to take README screenshots: open the list or the settings right away.
        if CommandLine.arguments.contains("--show-history") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.togglePopover() }
        }
        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.openSettings() }
        }
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"),
           index + 1 < CommandLine.arguments.count {
            takeSnapshots(into: URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true))
        }
    }

    /// Renders the app's own windows to PNG for the README (no Screen Recording permission needed).
    private func takeSnapshots(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Screenshots always use dark mode, which is how Caliche uses the Mac.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        popover.appearance = NSAppearance(named: .darkAqua)
        let steps: [(delay: Double, action: () -> Void)] = [
            (0.5, { self.togglePopover() }),
            (1.5, { self.snapshot(self.popover.contentViewController?.view, to: directory.appendingPathComponent("lista.png")) }),
            (1.6, { self.openSettings(tab: .general) }),
            (2.6, { self.snapshot(self.settingsWindow?.contentView?.superview, to: directory.appendingPathComponent("preferencias.png")) }),
            (2.7, { self.openSettings(tab: .about) }),
            (3.7, { self.snapshot(self.settingsWindow?.contentView?.superview, to: directory.appendingPathComponent("acerca-de.png")) }),
            (3.8, { NSApp.terminate(nil) }),
        ]
        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay, execute: step.action)
        }
    }

    /// cacheDisplay leaves out the translucent material behind the popover, so the view is drawn
    /// over a solid window background in the view's own appearance.
    private func snapshot(_ view: NSView?, to url: URL) {
        guard let view, let content = view.bitmapImageRepForCachingDisplay(in: view.bounds),
              let output = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: content)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: output.size).fill()
        }
        content.draw(in: NSRect(origin: .zero, size: output.size), from: .zero,
                     operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
        try? output.representation(using: .png, properties: [:])?.write(to: url)
    }

    private var currentShortcut: String?

    private func registerHotKey() {
        let defaults = UserDefaults.standard
        let letter = defaults.string(forKey: "hotKeyLetter") ?? HotKey.defaultLetter
        let modifier = defaults.string(forKey: "hotKeyModifier").flatMap(HotKeyModifier.init(rawValue:))
            ?? HotKey.defaultModifier
        let shortcut = modifier.symbol + letter
        guard shortcut != currentShortcut else { return }
        currentShortcut = shortcut
        hotKey?.register(letter: letter, modifier: modifier)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func openSettings(tab: SettingsTab = .general) {
        popover.performClose(nil)
        settingsTab.selection = tab
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store, tab: settingsTab)))
            window.title = "Preferencias de Caliche CopyClip"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
