import Carbon.HIToolbox
import Foundation

/// Modifier keys the user can pick for the shortcut that opens the list.
enum HotKeyModifier: String, CaseIterable, Identifiable {
    case option
    case commandShift

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .option: return "⌥"
        case .commandShift: return "⌘⇧"
        }
    }

    var carbonFlags: UInt32 {
        switch self {
        case .option: return UInt32(optionKey)
        case .commandShift: return UInt32(cmdKey | shiftKey)
        }
    }
}

/// Global shortcut using Carbon's RegisterEventHotKey, which works without Accessibility permission.
final class HotKey {
    static let letters: [(name: String, keyCode: UInt32)] = [
        ("V", UInt32(kVK_ANSI_V)), ("C", UInt32(kVK_ANSI_C)), ("X", UInt32(kVK_ANSI_X)),
        ("K", UInt32(kVK_ANSI_K)), ("L", UInt32(kVK_ANSI_L)), ("H", UInt32(kVK_ANSI_H)),
    ]
    static let defaultLetter = "V"
    static let defaultModifier = HotKeyModifier.option

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &spec, selfPointer, &handlerRef)
    }

    /// Returns false when macOS rejects the shortcut.
    @discardableResult
    func register(letter: String, modifier: HotKeyModifier) -> Bool {
        unregister()
        guard let keyCode = HotKey.letters.first(where: { $0.name == letter })?.keyCode else { return false }
        // "CALI" as the hotkey signature.
        let id = EventHotKeyID(signature: OSType(0x43414C49), id: 1)
        let status = RegisterEventHotKey(keyCode, modifier.carbonFlags, id, GetEventDispatcherTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
