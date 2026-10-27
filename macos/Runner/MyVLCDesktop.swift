import AppKit
import FlutterMacOS

/// Moves one stable video canvas between its Flutter host and a native mini-player.
/// Every window shares the owning libVLC instance and transport.
private final class TangerineHostView: NSView {
    var attached: (() -> Void)?
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); attached?() }
}

/// Intercepts only a secondary player window, forwarding the Flutter window's
/// existing delegate behavior until the durable progress flush has completed.
private final class TangerineCloseDelegate: NSObject, NSWindowDelegate {
    weak var previous: NSWindowDelegate?
    var request: (() -> Void)?
    func windowShouldClose(_ sender: NSWindow) -> Bool { request?(); return false }
    override func responds(to selector: Selector!) -> Bool { super.responds(to: selector) || (previous?.responds(to: selector) ?? false) }
    override func forwardingTarget(for selector: Selector!) -> Any? { previous }
}

final class MyVLCDesktop: NSObject, NSWindowDelegate {
    private let windowProvider: () -> NSWindow?
    var window:NSWindow? {host.window ?? windowProvider()}
    private let engine: VLCEngine
    let host: NSView
    private let canvas: NSView
    private var mini: NSPanel?
    private var timer: Timer?
    private var playButton: NSButton?
    private var timeline: NSSlider?
    var onSeek: (() -> Void)?
    var onTransport: ((Bool) -> Void)?
    var onPointer: ((String) -> Void)?
    private var closeDelegate:TangerineCloseDelegate?
    private weak var delegatedWindow:NSWindow?
    private var pointerMonitor: Any?
    private var singleClick: Timer?
    private var lastHover = Date.distantPast
    var fullscreen: Bool { window?.styleMask.contains(.fullScreen) == true }

    @MainActor init(engine: VLCEngine, windowProvider: @escaping () -> NSWindow? = { nil }) {
        self.engine = engine;self.windowProvider=windowProvider
        host = TangerineHostView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        canvas = NSView(frame: host.bounds)
        super.init()
        host.wantsLayer = true; canvas.wantsLayer = true
        host.layer?.backgroundColor = NSColor.black.cgColor; canvas.layer?.backgroundColor = NSColor.black.cgColor
        canvas.autoresizingMask = [.width, .height]; host.addSubview(canvas)
        engine.attach(to: canvas)
        (host as? TangerineHostView)?.attached = { [weak self] in guard let self else { return }; self.applyPreferences(self.preferences) }
        pointerMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .scrollWheel, .mouseMoved]) { [weak self] event in
            guard let self, event.window === self.host.window, self.host.bounds.contains(self.host.convert(event.locationInWindow, from: nil)) else { return event }
            if event.type == .leftMouseDown {
                self.singleClick?.invalidate()
                if event.clickCount >= 2 { self.onPointer?("pointer.double") }
                else { self.singleClick = Timer.scheduledTimer(withTimeInterval: NSEvent.doubleClickInterval, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.onPointer?("pointer.single") } } }
                return nil
            }
            if event.type == .scrollWheel { self.onPointer?("pointer.scroll:\(event.scrollingDeltaX):\(event.scrollingDeltaY)"); return nil }
            if Date().timeIntervalSince(self.lastHover) > 0.2 { self.lastHover = Date(); self.onPointer?("pointer.hover") }
            return event
        }
    }
    private var preferences: [String: String] = [:]
    var currentPreferences: [String: String] { preferences }
    @MainActor private static let resizedWindows = NSHashTable<NSWindow>.weakObjects()
    private var restoredFrameName: String?
    private var notifications: [NSObjectProtocol] = []
    @MainActor func applyPreferences(_ values: [String: String]) {
        preferences = values; applyWindowPreferences()
        notifications.forEach { NotificationCenter.default.removeObserver($0) }; notifications.removeAll()
        if let window = window {
            notifications.append(NotificationCenter.default.addObserver(forName: NSWindow.didMiniaturizeNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { if self?.preferences["pauseMinimized"] == "true" { self?.engine.pause(true); self?.onTransport?(false) } }
            })
        }
    }
    @MainActor private func applyWindowPreferences() {
        guard let window = window else { return }
        if preferences["independentPlaybackWindow"]=="true", closeDelegate==nil {
            let delegate=TangerineCloseDelegate();delegate.previous=window.delegate
            delegate.request={ [weak self] in self?.onPointer?("window.close") }
            closeDelegate=delegate;delegatedWindow=window;window.delegate=delegate
        }
        window.acceptsMouseMovedEvents = true
        window.alphaValue = min(1,max(0.1,Double(preferences["opacity"] ?? "1") ?? 1))
        if preferences["frontPlayback"] == "true" { window.makeKeyAndOrderFront(nil) }
        window.title = preferences["filenameTitle"] == "false" ? "Tangerine" : (preferences["windowTitle"] ?? "Tangerine")
        window.level = preferences["alwaysOnTop"] == "true" ? .floating : .normal
        if preferences["rememberWindow"] != "false" {
            let name = preferences["windowFrameKey"] ?? "Tangerine.player"
            if restoredFrameName != name { _ = window.setFrameUsingName(name); window.setFrameAutosaveName(name); restoredFrameName = name }
        }
        window.titleVisibility = preferences["decorations"] == "false" ? .hidden : .visible
        if preferences["resizeVideo"] == "Always" || (preferences["resizeVideo"] == "On first video" && !Self.resizedWindows.contains(window)) {
            let size = engine.videoSize
            if size.width > 0 && size.height > 0 { let bounds=window.screen?.visibleFrame.size ?? NSSize(width:1600,height:1000);let scale=min(1,min(bounds.width*0.85/size.width,bounds.height*0.85/(size.height+140)));window.setContentSize(NSSize(width:max(480,size.width*scale),height:max(300,size.height*scale+140)));Self.resizedWindows.add(window) }
        }
    }
    @MainActor func toggleMini() {
        if let mini { mini.close(); return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = "Tangerine · Picture-in-picture"; panel.level = .floating; panel.isReleasedWhenClosed = false; panel.delegate = self
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 340))
        let video = NSView(frame: NSRect(x: 0, y: 52, width: 520, height: 288)); video.autoresizingMask = [.width, .height]
        content.addSubview(video)
        canvas.removeFromSuperview(); canvas.frame = video.bounds; video.addSubview(canvas)
        let play = NSButton(title: "Pause", target: self, action: #selector(togglePlay)); play.frame = NSRect(x: 8, y: 10, width: 70, height: 32)
        content.addSubview(play); playButton = play
        let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: self, action: #selector(seek)); slider.frame = NSRect(x: 90, y: 12, width: 320, height: 28); slider.autoresizingMask = [.width]
        content.addSubview(slider); timeline = slider
        let back = NSButton(title: "Return", target: self, action: #selector(closeMini)); back.frame = NSRect(x: 425, y: 10, width: 85, height: 32); back.autoresizingMask = [.minXMargin]
        content.addSubview(back)
        panel.contentView = content; panel.center(); panel.makeKeyAndOrderFront(nil); mini = panel
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.playButton?.title = self.engine.isPlaying ? "Pause" : "Play"
                self.timeline?.doubleValue = self.engine.duration > 0 ? Double(self.engine.time) / Double(self.engine.duration) : 0
            }
        }
    }
    @MainActor @objc private func togglePlay() { let playing = !engine.isPlaying; playing ? engine.play() : engine.pause(true); onTransport?(playing) }
    @MainActor @objc private func seek() { onSeek?(); engine.seek(to: Int64((timeline?.doubleValue ?? 0) * Double(engine.duration))) }
    @objc private func closeMini() { mini?.close() }
    func windowWillClose(_ notification: Notification) {
        timer?.invalidate(); timer = nil
        canvas.removeFromSuperview(); canvas.frame = host.bounds; host.addSubview(canvas)
        mini = nil; playButton = nil; timeline = nil
    }
    @MainActor func exitPresentation() { if fullscreen { window?.toggleFullScreen(nil) } else { mini?.close() } }
    @MainActor func close() { if let window=delegatedWindow, window.delegate === closeDelegate {window.delegate=closeDelegate?.previous};closeDelegate=nil;delegatedWindow=nil;singleClick?.invalidate(); if let pointerMonitor { NSEvent.removeMonitor(pointerMonitor) }; pointerMonitor = nil; mini?.close(); timer?.invalidate(); notifications.forEach { NotificationCenter.default.removeObserver($0) }; notifications.removeAll() }
    @MainActor func toggleFullscreen() {
        if !fullscreen, preferences["fullscreenScreen"] == "Main screen", let screen = NSScreen.screens.first { window?.setFrameOrigin(screen.visibleFrame.origin) }
        window?.toggleFullScreen(nil)
    }
    var miniature: Bool { mini != nil }
}
