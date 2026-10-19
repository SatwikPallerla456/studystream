import AppKit
import FlutterMacOS
import CLibVLC

/// All libVLC ownership and calls stay on Flutter's macOS platform thread.
final class MyVLCBridge: NSObject, FlutterPlugin, FlutterPlatformViewFactory {
    private var engines: [Int64: VLCEngine] = [:]
    private var surfaces: [Int64: NSView] = [:]
    private var nextID: Int64 = 0
    private var desktops: [Int64: MyVLCDesktop] = [:]
    private var sources: [Int64: URL] = [:]
    private var jobs: [Int64: [OutputJob]] = [:]
    private var recording: [Int64: OutputJob] = [:]
    private var shortcuts: [Int64: MyVLCGlobalShortcuts] = [:]
    private var channel: FlutterMethodChannel?
    private var casters: [Int64: CastBrowser] = [:]

    static func register(with registrar: FlutterPluginRegistrar) {
        let bridge = MyVLCBridge()
        let channel = FlutterMethodChannel(name: "tangerine/playback", binaryMessenger: registrar.messenger)
        bridge.channel = channel
        registrar.addMethodCallDelegate(bridge, channel: channel)
        registrar.register(bridge, withId: "tangerine/vlc-video")
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? { FlutterStandardMessageCodec.sharedInstance() }
    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        guard let id = (args as? [String: Any])?["id"] as? Int64, let surface = surfaces[id] else { return NSView() }
        return surface
    }

    private static var engineFields: [PreferenceSpec] {
        SettingsCatalog.fields.filter { field in
            guard field.unavailable == nil, field.key != "proxy" else { return false }
            if case .secret = field.kind { return false }
            return (field.option.map { SettingsCatalog.supportedOptions.contains($0) } ?? false) || ["hardware", "decoder", "buffering", "subtitleUnits", "subtitleSize"].contains(field.key)
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        MainActor.assumeIsolated {
            do {
                let args = call.arguments as? [String: Any] ?? [:]
                if call.method == "preferences.importPreview" {
                    let panel = NSOpenPanel(); panel.allowedFileTypes = ["plist", "json"]; panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url else { result(nil); return }
                    guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 1024 * 1024 else { throw PlayerError.media }
                    let data = try Data(contentsOf: url)
                    var values: [String: String] = [:]
                    var local: [String: String] = [:], global: [String: String] = [:]
                    if let preferences = try? JSONDecoder().decode(PlayerPreferences.self, from: data) { values = preferences.values }
                    else if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        if let stored = plist["playerPreferences"] as? Data, let preferences = try? JSONDecoder().decode(PlayerPreferences.self, from: stored) { values = preferences.values }
                        if let stored = plist["shortcutBindings"] as? Data,
                           let bindings = try? JSONSerialization.jsonObject(with: stored) as? [String: [String: String]] {
                            for (action, binding) in bindings { local[action] = binding["local"]; global[action] = binding["global"] }
                        }
                    } else { throw PlayerError.media }
                    let allowed = Set(Self.engineFields.map { $0.key })
                    result(["preferences": values.filter { allowed.contains($0.key) }, "local": local, "global": global,
                        "speed": values["speed"] ?? "", "source": url.lastPathComponent]); return
                }
                if call.method == "preferences.catalog" {
                    result(Self.engineFields.map { field -> [String: Any] in
                        var row: [String: Any] = ["key": field.key, "title": field.title, "category": field.category.rawValue, "initial": field.initial]
                        switch field.kind {
                        case .toggle: row["type"] = "toggle"
                        case .choice(let choices): row["type"] = "choice"; row["choices"] = choices
                        case .slider(let min, let max, let step): row["type"] = "slider"; row["min"] = min; row["max"] = max; row["step"] = step
                        default: row["type"] = "text"
                        }
                        return row
                    }); return
                }
                if call.method == "create" {
                    var preferences = PlayerPreferences()
                    let provided = args["preferences"] as? [String: String] ?? [:]
                    for field in Self.engineFields { if let value = provided[field.key] { preferences[field.key] = value } }
                    let engine = try VLCEngine(preferences: preferences)
                    let desktop = MyVLCDesktop(engine: engine)
                    let view = desktop.host
                    nextID += 1
                    engines[nextID] = engine
                    surfaces[nextID] = view
                    desktops[nextID] = desktop
                    let playerID = nextID
                    desktop.onSeek = { [weak self] in self?.recording.removeValue(forKey: playerID)?.finish() }
                    desktop.onTransport = { [weak self] playing in if playing { self?.recording[playerID]?.engine.play() } else { self?.recording[playerID]?.engine.pause(true) } }
                    shortcuts[playerID] = MyVLCGlobalShortcuts(bindings: args["globalShortcuts"] as? [String: String] ?? [:]) { [weak self] action in
                        self?.channel?.invokeMethod("shortcut", arguments: ["id": playerID, "action": action])
                    }
                    result(nextID)
                    return
                }
                guard let id = args["id"] as? Int64, let engine = engines[id] else {
                    result(FlutterError(code: "PLAYER_CLOSED", message: "The native player has closed.", details: nil)); return
                }
                switch call.method {
                case "open":
                    guard let source = args["uri"] as? String, let url = URL(string: source), ["file", "http", "https"].contains(url.scheme ?? "") else {
                        result(FlutterError(code: "MEDIA", message: "Invalid media address.", details: nil)); return
                    }
                    recording.removeValue(forKey: id)?.finish()
                    sources[id] = url
                    try engine.open(url)
                case "state":
                    result([
                        "position": engine.time, "duration": engine.duration, "playing": engine.isPlaying,
                        "completed": engine.state == libvlc_Ended, "buffering": engine.state == libvlc_Buffering,
                        "error": engine.state == libvlc_Error, "volume": engine.volume, "rate": engine.rate,
                        "width": Int(engine.videoSize.width), "height": Int(engine.videoSize.height),
                        "hasVideoOutput": engine.hasVideoOutput, "version": engine.version,
                        "audio": engine.audioTracks.map { ["id": $0.id, "title": $0.name] },
                        "subtitles": engine.subtitleTracks.map { ["id": $0.id, "title": $0.name] },
                        "audioTrack": engine.audioTrack, "subtitleTrack": engine.subtitleTrack,
                        "chapter": engine.chapter, "chapters": engine.chapterCount, "statistics": engine.statistics,
                        "miniature": desktops[id]?.miniature ?? false,
                        "shortcutErrors": shortcuts[id]?.errors ?? [],
                        "jobs": (jobs[id] ?? []).map { ["id": $0.id.uuidString, "title": $0.title, "progress": $0.progress, "finished": $0.finished, "state": $0.state, "error": $0.failure ?? "", "path": $0.destination?.path ?? ""] },
                        "castStatus": casters[id]?.status ?? "Not scanning",
                        "castDevices": (casters[id]?.devices ?? []).map { ["id": $0.id, "name": $0.name] }
                    ]); return
                case "pause": engine.pause(true); recording[id]?.engine.pause(true)
                case "play": engine.play(); recording[id]?.engine.play()
                case "seek":
                    recording.removeValue(forKey: id)?.finish()
                    engine.seek(to: (args["value"] as? NSNumber)?.int64Value ?? 0)
                case "rate":
                    let rate = (args["value"] as? NSNumber)?.floatValue ?? 1
                    guard rate >= 0.25, rate <= 4, engine.setRate(rate) else {
                        result(FlutterError(code: "RATE", message: "This playback rate is unavailable.", details: nil)); return
                    }
                case "volume": engine.volume = (args["value"] as? NSNumber)?.int32Value ?? 100
                case "audioTrack": engine.audioTrack = (args["value"] as? NSNumber)?.int32Value ?? -1
                case "subtitleTrack": engine.subtitleTrack = (args["value"] as? NSNumber)?.int32Value ?? -1
                case "subtitle":
                    guard let path = args["value"] as? String else { throw PlayerError.subtitle }
                    try engine.addSubtitle(URL(fileURLWithPath: path))
                case "frame": engine.nextFrame()
                case "chapter":
                    let chapter = (args["value"] as? NSNumber)?.int32Value ?? 0
                    if chapter >= 0 && chapter < engine.chapterCount { engine.chapter = chapter }
                case "equalizer":
                    let bands = (args["bands"] as? [NSNumber] ?? []).map { max(-20, min(20, $0.floatValue)) }
                    engine.applyEqualizer(EqualizerSettings(enabled: args["enabled"] as? Bool ?? false,
                        preamp: (args["preamp"] as? NSNumber)?.floatValue ?? 0, bands: bands))
                case "picture":
                    var preferences = PlayerPreferences()
                    for key in ["brightness", "contrast", "saturation", "gamma", "hue", "aspect", "crop", "zoom", "audioDelay", "subtitleDelay"] {
                        if let value = args[key] { preferences[key] = String(describing: value) }
                    }
                    engine.applyLive(preferences)
                case "mini": desktops[id]?.toggleMini()
                case "fullscreen": desktops[id]?.toggleFullscreen()
                case "snapshot":
                    guard engine.hasVideoOutput else { throw PlayerError.media }
                    let panel = NSSavePanel(); panel.nameFieldStringValue = "Tangerine-snapshot.png"; panel.allowedFileTypes = ["png"]
                    guard panel.runModal() == .OK, let destination = panel.url else { result(nil); return }
                    guard engine.snapshot(to: destination) else { throw PlayerError.playback }
                    result(destination.path); return
                case "output.start":
                    guard let source = sources[id] else { throw PlayerError.media }
                    let mode = args["mode"] as? String ?? "convert"
                    guard ["convert", "record", "stream"].contains(mode) else { throw PlayerError.media }
                    let formats: [String: OutputFormat] = ["mp4": .mp4, "webm": .webm, "mp3": .mp3, "flac": .flac, "ts": .original]
                    guard let format = formats[args["format"] as? String ?? "mp4"] else { throw PlayerError.media }
                    if mode == "record" && !engine.isPlaying { throw PlayerError.playback }
                    if mode == "record", let active = recording[id], !active.finished {
                        result(FlutterError(code: "RECORDING_ACTIVE", message: "Finish the current recording first.", details: nil)); return
                    }
                    guard (jobs[id] ?? []).filter({ !$0.finished }).count < 3 else {
                        result(FlutterError(code: "OUTPUT_LIMIT", message: "Finish an output job before starting another.", details: nil)); return
                    }
                    var destination: URL?
                    var stream: String?
                    if mode == "stream" {
                        stream = try OutputBuilder.stream(host: args["host"] as? String ?? "127.0.0.1", port: (args["port"] as? NSNumber)?.intValue ?? 8090,
                            audio: args["audio"] as? Bool ?? true, video: args["video"] as? Bool ?? true, subtitles: args["subtitles"] as? Bool ?? false)
                    } else if let path = args["destination"] as? String {
                        destination = URL(fileURLWithPath: path)
                    } else {
                        let panel = NSSavePanel(); panel.nameFieldStringValue = "Tangerine-\(mode)-\(Int(Date().timeIntervalSince1970)).\(format.fileExtension)"; panel.allowedFileTypes = [format.fileExtension]
                        guard panel.runModal() == .OK, let selected = panel.url else { result(nil); return }
                        destination = selected
                    }
                    let job = try OutputJob(source: source, destination: destination, format: format,
                        preferences: PlayerPreferences(), start: mode == "record" ? engine.time : 0,
                        stream: stream, realtime: mode != "convert")
                    let previous = jobs[id] ?? []
                    jobs[id] = previous.filter { !$0.finished } + Array(previous.filter { $0.finished }.suffix(3)) + [job]
                    if mode == "record" { recording[id] = job }
                    result(job.id.uuidString); return
                case "output.finish":
                    if let jobID = args["jobId"] as? String, let job = jobs[id]?.first(where: { $0.id.uuidString == jobID }) {
                        if args["cancel"] as? Bool == true { job.cancel() } else { job.finish() }
                        if recording[id]?.id == job.id { recording.removeValue(forKey: id) }
                    }
                case "cast.scan":
                    let browser = casters[id] ?? CastBrowser(); casters[id] = browser; browser.start(engine: engine)
                case "cast.stop": casters.removeValue(forKey: id)?.stop()
                case "cast.select":
                    let selectedID = args["deviceId"] as? String
                    guard let source = sources[id] else { throw PlayerError.media }
                    let browser = casters[id]
                    let device = browser?.devices.first { $0.id == selectedID }
                    if selectedID != nil && device == nil { throw PlayerError.media }
                    let replacement = try VLCEngine()
                    if let device, libvlc_media_player_set_renderer(replacement.player, device.item) != 0 { throw PlayerError.playback }
                    let time = engine.time, volume = engine.volume, rate = engine.rate, paused = !engine.isPlaying
                    let audioTrack = engine.audioTrack, subtitleTrack = engine.subtitleTrack
                    recording.removeValue(forKey: id)?.finish(); engine.stop()
                    desktops[id]?.close()
                    let desktop = MyVLCDesktop(engine: replacement)
                    // Preserve the platform-view host rather than replacing it.
                    let oldHost = surfaces[id]!
                    for child in oldHost.subviews { child.removeFromSuperview() }
                    let newHost = desktop.host; newHost.frame = oldHost.bounds; newHost.autoresizingMask = [.width, .height]; oldHost.addSubview(newHost)
                    desktops[id] = desktop; engines[id] = replacement
                    replacement.volume = 0
                    try replacement.open(source)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak replacement] in
                        MainActor.assumeIsolated { replacement?.seek(to: time); _ = replacement?.setRate(rate); replacement?.audioTrack = audioTrack; replacement?.subtitleTrack = subtitleTrack; if paused { replacement?.pause(true) }; replacement?.volume = volume }
                    }
                case "dispose":
                    shortcuts.removeValue(forKey: id)
                    desktops.removeValue(forKey: id)?.close()
                    recording.removeValue(forKey: id)?.finish()
                    for job in jobs.removeValue(forKey: id) ?? [] where !job.finished { job.cancel() }
                    casters.removeValue(forKey: id)?.stop()
                    sources.removeValue(forKey: id)

                    engine.stop()
                    libvlc_media_player_set_nsobject(engine.player, nil)
                    engines.removeValue(forKey: id)
                    surfaces.removeValue(forKey: id)
                default: result(FlutterMethodNotImplemented); return
                }
                result(nil)
            } catch {
                result(FlutterError(code: "LIBVLC", message: error.localizedDescription, details: nil))
            }
        }
    }
}
