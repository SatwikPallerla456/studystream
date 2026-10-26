import AppKit
import Carbon

struct ShortcutKey {
    let code: UInt16
    let flags: NSEvent.ModifierFlags
    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }; if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }; if flags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }
    func matches(_ event: NSEvent) -> Bool { code == event.keyCode && event.modifierFlags.intersection([.command, .control, .option, .shift]) == flags }
    static let codes: [String: UInt16] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,"9":25,"7":26,"8":28,"0":29,"o":31,"u":32,"i":34,"p":35,"return":36,"l":37,"j":38,"k":40,"n":45,"m":46,"tab":48,"space":49,"escape":53,"left":123,"right":124,"down":125,"up":126]
    static func parse(_ string: String) -> ShortcutKey? {
        var parts = string.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let last = parts.popLast(), let code = codes[last] else { return nil }
        var flags: NSEvent.ModifierFlags = []
        for part in parts {
            switch part { case "command", "cmd", "⌘": flags.insert(.command); case "control", "ctrl", "⌃": flags.insert(.control)
            case "option", "alt", "⌥": flags.insert(.option); case "shift", "⇧": flags.insert(.shift); default: return nil }
        }
        return ShortcutKey(code: code, flags: flags)
    }
}


@MainActor final class MyVLCGlobalShortcuts {
    let token = UUID()
    let bindings: [String: String]
    let window: () -> NSWindow?
    let action: (String) -> Void
    var errors: [String] = []
    init(bindings: [String: String], window: @escaping () -> NSWindow? = { nil }, action: @escaping (String) -> Void) {
        self.bindings = bindings; self.window = window; self.action = action
        ShortcutBroker.shared.add(self)
    }
    deinit { let id = token; Task { @MainActor in ShortcutBroker.shared.remove(id) } }
}

private final class WeakShortcutOwner {
    weak var value: MyVLCGlobalShortcuts?
    init(_ value: MyVLCGlobalShortcuts) { self.value = value }
}

/// Register each physical global key once, then route to the focused or last
/// active player. Opening another player cannot steal or duplicate its hotkeys.
@MainActor private final class ShortcutBroker {
    static let shared = ShortcutBroker()
    private var owners: [UUID: WeakShortcutOwner] = [:]
    private var keys: [(UInt16, UInt32)] = []
    private var registrations: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var lastActive: UUID?
    private var focusObserver: NSObjectProtocol?
    private init() {
        focusObserver=NotificationCenter.default.addObserver(forName:NSWindow.didBecomeKeyNotification,object:nil,queue:.main) { [weak self] notification in
            MainActor.assumeIsolated { guard let self, let window=notification.object as? NSWindow else{return};if let owner=self.owners.values.compactMap(\.value).first(where:{$0.window()===window}){self.lastActive=owner.token} }
        }
    }
    func add(_ owner: MyVLCGlobalShortcuts) { owners[owner.token] = WeakShortcutOwner(owner); lastActive = owner.token; rebuild() }
    func remove(_ id: UUID) { owners.removeValue(forKey: id); if lastActive == id { lastActive = owners.keys.first }; rebuild() }
    private func rebuild() {
        registrations.forEach { UnregisterEventHotKey($0) }; registrations.removeAll(); keys.removeAll()
        owners = owners.filter { $0.value.value != nil }
        if owners.isEmpty { if let handler { RemoveEventHandler(handler) }; handler = nil; return }
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return noErr }
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                let owner = Unmanaged<ShortcutBroker>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async { [weak owner] in owner?.dispatch(Int(id.id)) }
                return noErr
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        var seen = Set<String>()
        for weakOwner in owners.values {
            guard let owner = weakOwner.value else { continue }; owner.errors.removeAll()
            for text in owner.bindings.values where !text.isEmpty {
                guard let key = ShortcutKey.parse(text), key.carbonModifiers != 0 else { owner.errors.append("Invalid global shortcut: \(text)"); continue }
                let normalized = "\(key.code):\(key.carbonModifiers)"
                if !seen.insert(normalized).inserted { continue }
                let index = keys.count; keys.append((key.code, key.carbonModifiers))
                var reference: EventHotKeyRef?
                let status = RegisterEventHotKey(UInt32(key.code), key.carbonModifiers, EventHotKeyID(signature: 0x54414E47, id: UInt32(index)), GetApplicationEventTarget(), 0, &reference)
                if status == noErr, let reference { registrations.append(reference) }
                else { owner.errors.append("Global shortcut \(text) is already in use or unavailable.") }
            }
        }
    }
    private func dispatch(_ index: Int) {
        guard keys.indices.contains(index) else { return }
        let focused = owners.values.compactMap(\.value).first { $0.window() === NSApp.keyWindow && $0.window() != nil }
        let owner = focused ?? lastActive.flatMap { owners[$0]?.value }
        guard let owner else { return }; lastActive = owner.token
        let key = keys[index]
        for (action, text) in owner.bindings {
            if let candidate = ShortcutKey.parse(text), candidate.code == key.0, candidate.carbonModifiers == key.1 { owner.action(action); return }
        }
    }
}
