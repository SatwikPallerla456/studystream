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
    private var registrations: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var actions: [String] = []
    private let action: (String) -> Void
    private(set) var errors: [String] = []
    init(bindings: [String: String], action: @escaping (String) -> Void) {
        self.action = action
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let owner = Unmanaged<MyVLCGlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { [weak owner] in
                guard let owner, Int(id.id) < owner.actions.count else { return }
                owner.action(owner.actions[Int(id.id)])
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        for (name, text) in bindings.sorted(by: { $0.key < $1.key }) where !text.isEmpty {
            guard let key = ShortcutKey.parse(text), key.carbonModifiers != 0 else { errors.append("Invalid global shortcut: \(text)"); continue }
            let index = actions.count
            actions.append(name)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(key.code), key.carbonModifiers, EventHotKeyID(signature: 0x54414E47, id: UInt32(index)), GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference { registrations.append(reference) }
            else { errors.append("Global shortcut \(text) is already in use or unavailable.") }
        }
    }
    deinit { registrations.forEach { UnregisterEventHotKey($0) }; if let handler { RemoveEventHandler(handler) } }
}
