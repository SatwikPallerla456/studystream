import Foundation
import Combine
import CLibVLC

enum OutputFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4 · H.264 + AAC", webm = "WebM · VP8 + Vorbis", mp3 = "MP3 audio", flac = "FLAC audio", original = "Original streams · TS"
    var id: String { rawValue }
    var fileExtension: String { switch self { case .mp4: return "mp4"; case .webm: return "webm"; case .mp3: return "mp3"; case .flac: return "flac"; case .original: return "ts" } }
    var mux: String { switch self { case .mp4: return "mp4"; case .webm: return "webm"; case .mp3: return "raw"; case .flac: return "raw"; case .original: return "ts" } }
    var transcode: String {
        switch self {
        case .mp4: return "transcode{vcodec=h264,vb=2500,acodec=mp4a,ab=192,channels=2}"
        case .webm: return "transcode{vcodec=VP80,vb=2000,acodec=vorb,ab=160,channels=2}"
        case .mp3: return "transcode{vcodec=none,acodec=mp3,ab=192,channels=2}"
        case .flac: return "transcode{vcodec=none,acodec=flac}"
        case .original: return ""
        }
    }
}

enum OutputBuilder {
    static func quote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'" }
    static func file(_ destination: URL, format: OutputFormat, realtime: Bool = false) -> String {
        let sink = "standard{access=file,mux=\(format.mux),dst=\(quote(destination.path))}"
        return "#" + (format.transcode.isEmpty ? "" : format.transcode + ":") + (realtime ? "duplicate{dst=display,dst=\(sink)}" : sink)
    }
    static func stream(host: String, port: Int, audio: Bool, video: Bool, subtitles: Bool) throws -> String {
        guard (1024...65535).contains(port), host.range(of: #"^[A-Za-z0-9.:-]+$"#, options: .regularExpression) != nil,
              audio || video else { throw NSError(domain: "Output", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enter a valid host, a port from 1024 to 65535, and at least one media track."]) }
        let codec = "transcode{vcodec=\(video ? "h264" : "none"),acodec=\(audio ? "mp4a" : "none"),vb=2000,ab=128\(subtitles ? ",soverlay" : "")}"
        return "#\(codec):duplicate{dst=display,dst=standard{access=http,mux=ts,dst=\(host):\(port)/stream}}"
    }
}

@MainActor
final class OutputJob: ObservableObject, Identifiable {
    let id = UUID()
    let title: String
    let destination: URL?
    let engine: VLCEngine
    @Published var progress: Double = 0
    @Published var state = "Starting…"
    @Published var finished = false
    @Published var failure: String?
    private var timer: Timer?
    private var startedAt = Date()
    private let realtime: Bool

    init(source: URL, destination: URL?, format: OutputFormat, preferences: PlayerPreferences, start: Int64 = 0,
         stream: String? = nil, realtime: Bool = false) throws {
        self.destination = destination; self.realtime = realtime
        title = stream != nil ? "Stream output" : (realtime ? "Recording" : "Convert \(source.lastPathComponent)")
        engine = try VLCEngine(headless: true, preferences: preferences, extraArguments: ["--aout=dummy"])
        guard destination != nil || stream != nil else { throw PlayerError.media }
        if let destination, FileManager.default.fileExists(atPath: destination.path) {
            throw NSError(domain: "Output", code: 2, userInfo: [NSLocalizedDescriptionKey: "Choose a new output filename. An existing file will not be overwritten."])
        }
        let chain = stream ?? OutputBuilder.file(destination!, format: format, realtime: realtime)
        var options = [":sout=\(chain)", ":no-sout-all", ":sout-keep"]
        if !realtime { options += [":no-sout-transcode-high-priority", ":no-sout-keep", ":no-sout-display"] }
        if start > 0 { options.append(":start-time=\(Double(start) / 1000)") }
        if !realtime { options.append(":no-input-clock") }
        try engine.open(source, options: options)
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.poll() } }
    }
    private func poll() {
        progress = engine.duration > 0 ? Double(engine.time) / Double(engine.duration) : 0
        if engine.state == libvlc_Error { finish(error: "libVLC could not create the output. Check codec support, destination permissions, and network binding.") }
        else if engine.state == libvlc_Ended { finish() }
        else if engine.isPlaying { state = realtime ? "Recording / streaming" : "Converting…" }
        else if Date().timeIntervalSince(startedAt) > 30, engine.time == 0 { finish(error: "Output did not start within 30 seconds.") }
    }
    func cancel() { engine.stop(); timer?.invalidate(); finished = true; state = "Cancelled" }
    func finish(error: String? = nil) {
        engine.stop(); timer?.invalidate(); finished = true; failure = error
        if let error { state = "Failed"; failure = error }
        else if let destination, ((try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) == 0 {
            state = "Failed"; failure = "The output file was empty. The selected source may not support this output format."
        } else { state = "Complete"; progress = 1 }
    }
}

final class CastDevice: Identifiable {
    let item: OpaquePointer
    var id: String { String(UInt(bitPattern: item)) }
    let name: String
    init(_ pointer: OpaquePointer) { item = pointer; name = String(cString: libvlc_renderer_item_name(pointer)) }
    deinit { libvlc_renderer_item_release(item) }
}

@MainActor
final class CastBrowser: ObservableObject {
    @Published var devices: [CastDevice] = []
    @Published var status = "Not scanning"
    private var discoverer: OpaquePointer?
    private var engine: VLCEngine?
    private static let callback: @convention(c) (UnsafePointer<libvlc_event_t>?, UnsafeMutableRawPointer?) -> Void = { event, context in
        guard let event, let context else { return }
        let added = event.pointee.type == Int32(libvlc_RendererDiscovererItemAdded.rawValue)
        let pointer = added ? event.pointee.u.renderer_discoverer_item_added.item : event.pointee.u.renderer_discoverer_item_deleted.item
        guard let pointer, let held = libvlc_renderer_item_hold(pointer) else { return }
        let browser = Unmanaged<CastBrowser>.fromOpaque(context).takeUnretainedValue()
        DispatchQueue.main.async { [weak browser] in
            guard let browser else { libvlc_renderer_item_release(held); return }
            if added {
                let device = CastDevice(held)
                if !browser.devices.contains(where: { $0.id == device.id }) { browser.devices.append(device) }
            } else {
                browser.devices.removeAll { $0.item == held }; libvlc_renderer_item_release(held)
            }
        }
    }
    func start(engine: VLCEngine) {
        stop(); self.engine = engine
        guard let discoverer = libvlc_renderer_discoverer_new(engine.instance, "microdns_renderer") else { status = "Cast discovery is unavailable in this VLC installation."; return }
        self.discoverer = discoverer
        let manager = libvlc_renderer_discoverer_event_manager(discoverer)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for event in [libvlc_RendererDiscovererItemAdded, libvlc_RendererDiscovererItemDeleted] { libvlc_event_attach(manager, Int32(event.rawValue), Self.callback, context) }
        status = libvlc_renderer_discoverer_start(discoverer) == 0 ? "Searching your local network…" : "Discovery could not start. Check Local Network access in System Settings."
    }
    func cast(_ device: CastDevice?) -> Bool { guard let engine else { return false }; return libvlc_media_player_set_renderer(engine.player, device?.item) == 0 }
    func stop() {
        if let discoverer {
            libvlc_renderer_discoverer_stop(discoverer)
            let manager = libvlc_renderer_discoverer_event_manager(discoverer)
            let context = Unmanaged.passUnretained(self).toOpaque()
            for event in [libvlc_RendererDiscovererItemAdded, libvlc_RendererDiscovererItemDeleted] { libvlc_event_detach(manager, Int32(event.rawValue), Self.callback, context) }
            libvlc_renderer_discoverer_release(discoverer)
        }
        discoverer = nil; devices = []; engine = nil; status = "Not scanning"
    }
}
