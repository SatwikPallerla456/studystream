import AppKit
import FlutterMacOS

/// Moves one stable video canvas between its Flutter host and a native mini-player.
/// Every window shares the owning libVLC instance and transport.
final class MyVLCDesktop: NSObject, NSWindowDelegate {
    private let engine: VLCEngine
    let host: NSView
    private let canvas: NSView
    private var mini: NSPanel?
    private var timer: Timer?
    private var playButton: NSButton?
    private var timeline: NSSlider?
    var onSeek: (() -> Void)?
    var onTransport: ((Bool) -> Void)?

    @MainActor init(engine: VLCEngine) {
        self.engine = engine
        host = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        canvas = NSView(frame: host.bounds)
        super.init()
        host.wantsLayer = true; canvas.wantsLayer = true
        host.layer?.backgroundColor = NSColor.black.cgColor; canvas.layer?.backgroundColor = NSColor.black.cgColor
        canvas.autoresizingMask = [.width, .height]; host.addSubview(canvas)
        engine.attach(to: canvas)
    }
    @MainActor func toggleMini() {
        if let mini { mini.close(); return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        panel.title = "Tangerine · Mini-player"; panel.level = .floating; panel.isReleasedWhenClosed = false; panel.delegate = self
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
    @MainActor func close() { mini?.close(); timer?.invalidate() }
    @MainActor func toggleFullscreen() { host.window?.toggleFullScreen(nil) }
    var miniature: Bool { mini != nil }
}
