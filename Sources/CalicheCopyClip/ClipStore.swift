import AppKit
import Combine

/// One copied piece of text, like CopyClip's CopiedObj (text, count, bookmark, time).
struct Clip: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var count: Int = 1
    var isBookmark: Bool = false
    var time: Date = Date()
}

enum ClipFilter: String, CaseIterable, Identifiable {
    case all = "Todo"
    case bookmarks = "Favoritos de Caliche"
    var id: String { rawValue }
}

/// Owns the clipboard history: watching the pasteboard, persisting to disk and the user's settings.
final class ClipStore: ObservableObject {
    @Published private(set) var clips: [Clip] = []
    @Published var mostCopiedOnTop: Bool {
        didSet { UserDefaults.standard.set(mostCopiedOnTop, forKey: "mostCopiedOnTop") }
    }
    @Published var maxItems: Int {
        didSet {
            UserDefaults.standard.set(maxItems, forKey: "maxItems")
            trim()
            save()
        }
    }

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    /// Set when we write to the pasteboard ourselves, so re-copying an item only bumps it.
    private var ignoreNextChange = false

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CalicheCopyClip", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }()

    /// Demo mode shows sample clips for README screenshots; it never reads or writes real history.
    private let isDemo: Bool

    init(demo: Bool = false) {
        isDemo = demo
        let defaults = UserDefaults.standard
        mostCopiedOnTop = defaults.bool(forKey: "mostCopiedOnTop")
        let storedMax = defaults.integer(forKey: "maxItems")
        maxItems = storedMax > 0 ? storedMax : 200
        lastChangeCount = pasteboard.changeCount
        if demo { clips = ClipStore.demoClips } else { load() }
    }

    private static let demoClips: [Clip] = [
        Clip(text: "¡Hola! Soy Caliche y este es mi portapapeles 💚", count: 3, time: Date().addingTimeInterval(-40)),
        Clip(text: "git commit -m \"feat: nueva versión de Caliche CopyClip\"", isBookmark: true, time: Date().addingTimeInterval(-300)),
        Clip(text: "https://github.com/CalicheOrozco", count: 5, isBookmark: true, time: Date().addingTimeInterval(-1800)),
        Clip(text: "Reunión con el equipo mañana a las 10:00", time: Date().addingTimeInterval(-3600)),
        Clip(text: "npm run build && npm run test", count: 2, time: Date().addingTimeInterval(-7200)),
    ]

    func startMonitoring() {
        guard !isDemo else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        if ignoreNextChange {
            ignoreNextChange = false
            return
        }
        // Skip content that password managers mark as concealed or transient.
        let types = pasteboard.types ?? []
        if types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
            || types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) {
            return
        }
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        add(text)
    }

    private func add(_ text: String) {
        if let index = clips.firstIndex(where: { $0.text == text }) {
            var existing = clips.remove(at: index)
            existing.count += 1
            existing.time = Date()
            clips.insert(existing, at: 0)
        } else {
            clips.insert(Clip(text: text), at: 0)
        }
        trim()
        save()
    }

    /// Puts a clip back on the pasteboard so it is ready to paste with Cmd+V.
    func copyToPasteboard(_ clip: Clip) {
        ignoreNextChange = true
        pasteboard.clearContents()
        pasteboard.setString(clip.text, forType: .string)
        if let index = clips.firstIndex(where: { $0.id == clip.id }) {
            var copied = clips.remove(at: index)
            copied.count += 1
            copied.time = Date()
            clips.insert(copied, at: 0)
        }
        save()
    }

    func toggleBookmark(_ clip: Clip) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        clips[index].isBookmark.toggle()
        save()
    }

    func delete(_ clip: Clip) {
        clips.removeAll { $0.id == clip.id }
        save()
    }

    func deleteAll(keepBookmarks: Bool) {
        clips.removeAll { keepBookmarks ? !$0.isBookmark : true }
        save()
    }

    func visibleClips(filter: ClipFilter, search: String) -> [Clip] {
        var result = clips
        if filter == .bookmarks { result = result.filter(\.isBookmark) }
        let query = search.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter { $0.text.localizedCaseInsensitiveContains(query) }
        }
        if mostCopiedOnTop {
            result.sort { $0.count != $1.count ? $0.count > $1.count : $0.time > $1.time }
        }
        return result
    }

    /// Drops the oldest non-bookmarked clips beyond the limit; bookmarks are never trimmed.
    private func trim() {
        var unbookmarked = clips.filter { !$0.isBookmark }.count
        while unbookmarked > maxItems, let index = clips.lastIndex(where: { !$0.isBookmark }) {
            clips.remove(at: index)
            unbookmarked -= 1
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Clip].self, from: data) else { return }
        clips = decoded
    }

    private func save() {
        guard !isDemo, let data = try? JSONEncoder().encode(clips) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
