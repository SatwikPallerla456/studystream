import AppKit
import FlutterMacOS
import CLibVLC
import CoreGraphics

/// All libVLC ownership and calls stay on Flutter's macOS platform thread.
final class MyVLCBridge: NSObject, FlutterPlugin, FlutterPlatformViewFactory {
    private var captureWindow: TangerineCapture?
    private var addonRunners: [UUID:TangerineAddonRunner] = [:]
    private var engines: [Int64: VLCEngine] = [:]
    private var surfaces: [Int64: NSView] = [:]
    private var nextID: Int64 = 0
    private var analyzingFile = false
    private var desktops: [Int64: MyVLCDesktop] = [:]
    private var sources: [Int64: URL] = [:]
    private var jobs: [Int64: [OutputJob]] = [:]
    private var recording: [Int64: OutputJob] = [:]
    private var shortcuts: [Int64: MyVLCGlobalShortcuts] = [:]
    private weak var flutterView:NSView?
    private var channel: FlutterMethodChannel?
    private var casters: [Int64: CastBrowser] = [:]

    static func register(with registrar: FlutterPluginRegistrar) {
        let bridge = MyVLCBridge();bridge.flutterView=registrar.view
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
            return (field.option.map { SettingsCatalog.supportedOptions.contains($0) } ?? false) || ["hardware", "decoder", "buffering", "subtitleUnits", "subtitleSize", "normalize", "nightMode", "compressor", "spatialAudio", "widening", "chorus", "karaoke", "pitchEnabled", "twoPass", "visualizer", "minorWarnings"].contains(field.key)
        }
    }

    /// Bounded local-only parsing in a separate libVLC instance. This never
    /// attaches a surface, starts playback, or applies the user's player effects.
    @MainActor
    private static func analyzeFile(_ path: String) async throws -> [String: Any] {
        let engine = try VLCEngine(headless: true)
        defer { withExtendedLifetime(engine) {} }
        guard let media = libvlc_media_new_path(engine.instance, path) else { throw PlayerError.media }
        defer { libvlc_media_parse_stop(media); libvlc_media_release(media) }
        guard libvlc_media_parse_with_options(media, libvlc_media_parse_local, 3000) == 0 else { throw PlayerError.media }
        let deadline = Date().addingTimeInterval(4)
        var status = libvlc_media_get_parsed_status(media)
        while status.rawValue == 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
            status = libvlc_media_get_parsed_status(media)
        }
        guard status == libvlc_media_parsed_status_done else { throw PlayerError.media }
        var tracks: UnsafeMutablePointer<UnsafeMutablePointer<libvlc_media_track_t>?>?
        let count = libvlc_media_tracks_get(media, &tracks)
        defer { if let tracks { libvlc_media_tracks_release(tracks, count) } }
        var streams: [[String: Any]] = []
        var payload: [String: Any] = ["container": URL(fileURLWithPath: path).pathExtension.lowercased(), "analysisState": "complete"]
        let duration = libvlc_media_get_duration(media)
        if duration > 0 { payload["durationSeconds"] = Double(duration) / 1000 }
        if let tracks {
            for index in 0..<min(Int(count), 128) {
                guard let track = tracks[index]?.pointee else { continue }
                let kind = track.i_type == libvlc_track_video ? "video" : track.i_type == libvlc_track_audio ? "audio" : track.i_type == libvlc_track_text ? "subtitle" : "unknown"
                var row: [String: Any] = ["id": Int(track.i_id), "kind": kind]
                if let codec = libvlc_media_get_codec_description(track.i_type, track.i_codec) {
                    row["codec"] = String(String(cString: codec).prefix(256))
                    if payload["codec"] == nil || kind == "video" { payload["codec"] = row["codec"] }
                }
                if track.i_bitrate > 0 { row["bitrate"] = Int(track.i_bitrate) }
                if let language = track.psz_language { row["language"] = String(String(cString: language).prefix(32)) }
                if track.i_type == libvlc_track_video, let video = track.video?.pointee {
                    row["width"] = Int(video.i_width); row["height"] = Int(video.i_height)
                    row["videoOrientation"] = Int(video.i_orientation.rawValue)
                    if video.i_frame_rate_den > 0 { row["frameRate"] = Double(video.i_frame_rate_num) / Double(video.i_frame_rate_den) }
                    if payload["width"] == nil {
                        payload["width"] = row["width"]; payload["height"] = row["height"]
                        payload["videoOrientation"] = row["videoOrientation"]
                    }
                }
                if track.i_type == libvlc_track_audio, let audio = track.audio?.pointee {
                    row["channels"] = Int(audio.i_channels); row["sampleRate"] = Int(audio.i_rate)
                    if payload["channels"] == nil {
                        payload["channels"] = row["channels"]; payload["sampleRate"] = row["sampleRate"]
                    }
                }
                streams.append(row)
            }
        }
        payload["streams"] = streams
        if streams.isEmpty { payload["analysisState"] = "unsupported" }
        return payload
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        MainActor.assumeIsolated {
            do {
                let args = call.arguments as? [String: Any] ?? [:]
                if call.method == "capture.show" {
                    if captureWindow == nil { captureWindow=TangerineCapture() }
                    captureWindow?.show();result(nil);return
                }
                if call.method == "services.status" {
                    let settings=UserDefaults.standard.dictionary(forKey:"tangerine.services") ?? [:]
                    result(settings.merging(["hasLastfmPassword":!CredentialStore.read("tangerine.lastfmPassword").isEmpty,"hasProxyPassword":!CredentialStore.read("tangerine.proxyPassword").isEmpty]) { _,new in new });return
                }
                if call.method == "services.save" {
                    let user=args["lastfmUser"] as? String ?? "", proxy=args["proxy"] as? String ?? "", proxyUser=args["proxyUser"] as? String ?? ""
                    guard user.count<=128, proxyUser.count<=128,proxyUser.rangeOfCharacter(from:.controlCharacters)==nil,proxy.count<=512, user.rangeOfCharacter(from:.controlCharacters)==nil,
                          proxy.rangeOfCharacter(from:.controlCharacters)==nil else { throw PlayerError.media }
                    if !proxy.isEmpty {
                        guard let url=URLComponents(string:proxy),url.scheme=="http",url.host?.isEmpty==false,url.user==nil,url.password==nil,url.query==nil,url.fragment==nil,(url.path.isEmpty || url.path=="/") else {
                            result(FlutterError(code:"PROXY",message:"Use an HTTP proxy address such as http://proxy.example:8080 without credentials or paths.",details:nil));return
                        }
                    }
                    for key in ["lastfmPassword","proxyPassword"] {
                        if let value=args[key] as? String,!value.isEmpty {
                            guard value.count<=1024,value.rangeOfCharacter(from:.controlCharacters)==nil,CredentialStore.write(value,key:"tangerine."+key) else {
                                result(FlutterError(code:"KEYCHAIN",message:"The account secret could not be saved in Keychain.",details:nil));return
                            }
                        }
                        if args["clear"+key] as? Bool == true { guard CredentialStore.write("",key:"tangerine."+key) else { throw PlayerError.media } }
                    }
                    let enabled=args["scrobble"] as? Bool ?? false
                    guard !enabled || (!user.isEmpty && !CredentialStore.read("tangerine.lastfmPassword").isEmpty) else {
                        result(FlutterError(code:"ACCOUNT",message:"Enter a Last.fm username and password before enabling scrobbling.",details:nil));return
                    }
                    UserDefaults.standard.set(["scrobble":enabled,"lastfmUser":user,"proxy":proxy,"proxyUser":proxyUser],forKey:"tangerine.services")
                    result(nil);return
                }
                if call.method=="app.show" {flutterView?.window?.deminiaturize(nil);flutterView?.window?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);result(nil);return}
                if call.method=="app.quit" {result(nil);DispatchQueue.main.async{NSApp.terminate(nil)};return}
                if call.method == "analyzeFile" {
                    guard !analyzingFile, let path = args["path"] as? String,
                          path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) else {
                        result(FlutterError(code: "ANALYSIS_BUSY", message: "File analysis is unavailable or already running.", details: nil)); return
                    }
                    analyzingFile = true
                    Task { @MainActor in
                        defer { self.analyzingFile = false }
                        do { result(try await Self.analyzeFile(path)) }
                        catch { result(FlutterError(code: "ANALYSIS", message: "This file could not be analyzed.", details: nil)) }
                    }
                    return
                }
                if call.method == "preferences.importPreview" {
                    let panel = NSOpenPanel(); panel.allowedFileTypes = ["plist", "json"]; panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url else { result(nil); return }
                    guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 1024 * 1024 else { throw PlayerError.media }
                    let data = try Data(contentsOf: url)
                    var values: [String: String] = [:]
                    var local: [String: String] = [:], global: [String: String] = [:]
                    var profiles: [PlayerProfile] = []
                    if let object = try? JSONSerialization.jsonObject(with: data) {
                        if let dictionary = object as? [String: Any] {
                            if let pref = try? JSONDecoder().decode(PlayerPreferences.self, from: data) { values = pref.values }
                            if let pref = dictionary["preferences"] ?? dictionary["playerPreferences"], JSONSerialization.isValidJSONObject(pref), let encoded = try? JSONSerialization.data(withJSONObject: pref), let decoded = try? JSONDecoder().decode(PlayerPreferences.self, from: encoded) { values = decoded.values }
                            if let list = dictionary["profiles"], let encoded = try? JSONSerialization.data(withJSONObject: list) { profiles = (try? JSONDecoder().decode([PlayerProfile].self, from: encoded)) ?? [] }
                            if let bindings = dictionary["shortcutBindings"] as? [String: [String: String]] { for (action, binding) in bindings { local[action] = binding["local"]; global[action] = binding["global"] } }
                        } else if object is [Any] { profiles = try JSONDecoder().decode([PlayerProfile].self, from: data) }
                    } else if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        if let stored = plist["playerPreferences"] as? Data, let preferences = try? JSONDecoder().decode(PlayerPreferences.self, from: stored) { values = preferences.values }
                        if let stored = plist["profiles"] as? Data { profiles = try JSONDecoder().decode([PlayerProfile].self, from: stored) }
                        if let stored = plist["shortcutBindings"] as? Data,
                           let bindings = try? JSONSerialization.jsonObject(with: stored) as? [String: [String: String]] {
                            for (action, binding) in bindings { local[action] = binding["local"]; global[action] = binding["global"] }
                        }
                    } else { throw PlayerError.media }
                    guard profiles.count <= 100 else { throw PlayerError.media }
                    let allowed = Set(Self.engineFields.map { $0.key }).union(["alwaysOnTop","rememberWindow","decorations","pauseMinimized","frontPlayback","filenameTitle","resizeVideo","fullscreenScreen","opacity","autoHide","hideAfter","controlsOpacity","fullscreenControls","coverArt","saveHistory","resume","historyExclusion","singleClick","doubleClick","scroll","horizontalScroll","reverseScroll","skipVeryShort","skipShort","skipMedium","skipLong","startPlaying","continue","stopEach","startFullscreen","preventSleep","rememberVolume","startupVolume","compactStartup","outputDevice","brightness","contrast","saturation","gamma","hue","aspect","crop","zoom","audioDelay","subtitleDelay","deinterlace","deinterlaceMode","embeddedVideo","finished","snapshotFolder","snapshotPrefix","snapshotFormat","snapshotWidth","snapshotSequential","snapshotPreview","trayIcon","startMinimized","trackPopup","popupDuration","playlistTree","repeat","shuffle","volumeStep"])
                    let safeProfiles: [[String: Any]] = profiles.map { profile in
                        ["id": profile.id.uuidString, "name": profile.name, "preferences": ["values": profile.preferences.values.filter { allowed.contains($0.key) || $0.key == "speed" }], "equalizer": ["enabled": profile.equalizer.enabled, "preamp": profile.equalizer.preamp, "bands": profile.equalizer.bands]]
                    }
                    result(["preferences": values.filter { allowed.contains($0.key) }, "local": local, "global": global, "profiles": safeProfiles,
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
                    for field in Self.engineFields {
                        guard let value=provided[field.key] else {continue}
                        guard value.count<=512, value.rangeOfCharacter(from:.controlCharacters)==nil else {throw PlayerError.media}
                        switch field.kind {
                        case .toggle: guard ["true","false"].contains(value) else {throw PlayerError.media}
                        case .choice(let choices): guard choices.contains(value) else {throw PlayerError.media}
                        case .slider(let minimum,let maximum,_): guard let number=Double(value),number.isFinite,number>=minimum,number<=maximum else {throw PlayerError.media}
                        default: break
                        }
                        preferences[field.key]=value
                    }
                    let service=UserDefaults.standard.dictionary(forKey:"tangerine.services") ?? [:]
                    var serviceArguments:[String]=[]
                    if service["scrobble"] as? Bool == true,let user=service["lastfmUser"] as? String,!user.isEmpty {
                        let secret=CredentialStore.read("tangerine.lastfmPassword")
                        if !secret.isEmpty { serviceArguments += ["--extraintf=audioscrobbler","--lastfm-username="+user,"--lastfm-password="+secret,"--scrobbler-url=post.audioscrobbler.com"] }
                    }
                    if let proxy=service["proxy"] as? String,!proxy.isEmpty {
                        var address=URLComponents(string:proxy)
                        if let user=service["proxyUser"] as? String,!user.isEmpty {address?.user=user}
                        serviceArguments.append("--http-proxy="+(address?.string ?? proxy))
                        let secret=CredentialStore.read("tangerine.proxyPassword")
                        if !secret.isEmpty { serviceArguments.append("--http-proxy-pwd="+secret) }
                    }
                    let engine = try VLCEngine(preferences: preferences,extraArguments:serviceArguments)
                    let desktop = MyVLCDesktop(engine: engine, windowProvider:{ [weak self] in self?.flutterView?.window })
                    let view = desktop.host
                    nextID += 1
                    engines[nextID] = engine
                    surfaces[nextID] = view
                    desktops[nextID] = desktop
                    let playerID = nextID
                    desktop.onPointer = { [weak self] action in self?.channel?.invokeMethod("shortcut", arguments: ["id": playerID, "action": action]) }
                    desktop.onSeek = { [weak self] in self?.recording.removeValue(forKey: playerID)?.finish() }
                    desktop.onTransport = { [weak self] playing in if playing { self?.recording[playerID]?.engine.play() } else { self?.recording[playerID]?.engine.pause(true) } }
                    shortcuts[playerID] = MyVLCGlobalShortcuts(bindings: args["globalShortcuts"] as? [String: String] ?? [:], window: { [weak self] in self?.desktops[playerID]?.window }) { [weak self] action in
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
                    guard let source = args["uri"] as? String, let url = URL(string: source), ["file", "http", "https", "rtsp", "rtp", "udp", "rtmp"].contains(url.scheme ?? "") else {
                        result(FlutterError(code: "MEDIA", message: "Invalid media address.", details: nil)); return
                    }
                    recording.removeValue(forKey: id)?.finish()
                    sources[id] = url
                    try engine.open(url)
                case "input.open":
                    let kind=args["kind"] as? String ?? ""
                    let source:URL
                    if kind=="screen" {
                        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
                            result(FlutterError(code:"PERMISSION",message:"Enable Screen Recording for Tangerine in System Settings, then restart the app.",details:nil));return
                        }
                        source=URL(string:"screen://")!
                    } else {
                        guard ["dvdnav","dvd","bluray","cdda","vcd"].contains(kind) else { throw PlayerError.media }
                        let path=args["path"] as? String ?? ""
                        guard path.hasPrefix("/"),!path.contains("\0"),FileManager.default.fileExists(atPath:path),let encoded=path.addingPercentEncoding(withAllowedCharacters:.urlPathAllowed),let url=URL(string:kind+"://"+encoded) else { throw PlayerError.media }
                        source=url
                    }
                    recording.removeValue(forKey:id)?.finish();sources[id]=source
                    try engine.open(source,options:kind=="screen" ? [":screen-fps=15"] : [])
                case "disc.navigate":
                    let actions:[String:libvlc_navigate_mode_t] = ["menu":libvlc_navigate_popup,"activate":libvlc_navigate_activate,"up":libvlc_navigate_up,"down":libvlc_navigate_down,"left":libvlc_navigate_left,"right":libvlc_navigate_right]
                    if let action=actions[args["action"] as? String ?? ""] { libvlc_media_player_navigate(engine.player,action.rawValue) }
                    else { throw PlayerError.media }
                case "disc.title":
                    let title=(args["value"] as? NSNumber)?.int32Value ?? -1
                    guard title>=0,title<libvlc_media_player_get_title_count(engine.player) else { throw PlayerError.media }
                    libvlc_media_player_set_title(engine.player,title)
                case "addon.run":
                    guard let source=args["source"] as? String,source.utf8.count<=256*1024,addonRunners.count<4 else { throw PlayerError.media }
                    let token=UUID(),runner=TangerineAddonRunner();addonRunners[token]=runner
                    runner.run(source:source,title:String((args["title"] as? String ?? engine.metadata["title"] ?? "").prefix(512)),position:Double(engine.time)/1000) { [weak self,weak engine] commands,error in
                        defer { self?.addonRunners.removeValue(forKey:token) }
                        guard let engine,self?.engines[id] === engine else { result(FlutterError(code:"CLOSED",message:"The player closed.",details:nil));return }
                        if error != nil { result(FlutterError(code:"ADDON",message:"Add-on failed or timed out. Review the script before enabling it again.",details:nil));return }
                        for command in (commands ?? []).prefix(64) {
                            let number=(command["value"] as? NSNumber)?.doubleValue ?? 0
                            guard number.isFinite else {continue}
                            switch command["action"] as? String {
                            case "play":engine.play()
                            case "pause":engine.pause(true)
                            case "stop":engine.stop()
                            case "seek":engine.seek(to:Int64(max(0,min(number,Double(engine.duration)/1000))*1000))
                            case "volume":engine.volume=Int32(max(0,min(100,number)))
                            default:break
                            }
                        }
                        result(nil)
                    };return
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
                        "discTitle":Int(libvlc_media_player_get_title(engine.player)),"discTitles":Int(libvlc_media_player_get_title_count(engine.player)),
                        "chapter": engine.chapter, "chapters": engine.chapterCount, "statistics": engine.statistics,
                        "metadata": engine.metadata, "audioDevices": engine.audioOutputDevices, "audioDevice": engine.outputDevice,
                        "minimized": desktops[id]?.window?.isMiniaturized ?? false,
                        "miniature": desktops[id]?.miniature ?? false, "fullscreen": desktops[id]?.fullscreen ?? false,
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
                    for key in ["brightness", "contrast", "saturation", "gamma", "hue", "aspect", "crop", "zoom", "audioDelay", "subtitleDelay", "deinterlace", "deinterlaceMode"] {
                        if let value = args[key] { preferences[key] = String(describing: value) }
                    }
                    if let mode = args["deinterlaceMode"] as? String { preferences["deinterlace"] = mode == "off" ? "off" : "on" }
                    engine.applyLive(preferences)
                case "device": try engine.selectOutputDevice(args["value"] as? String ?? "")
                case "prepareExit":
                    recording.removeValue(forKey:id)?.finish()
                    for job in jobs[id] ?? [] where !job.finished {job.cancel()}
                case "window.finish":
                    let action=args["action"] as? String ?? "Stop"
                    if action=="Minimize" {desktops[id]?.window?.miniaturize(nil)}
                    if action=="Quit" {result(nil);DispatchQueue.main.async{NSApp.terminate(nil)};return}
                case "window.close":
                    let window=desktops[id]?.window
                    self.handle(FlutterMethodCall(methodName:"dispose",arguments:["id":id]),result:result)
                    DispatchQueue.main.async { window?.performClose(nil) };return
                case "window.preferences": desktops[id]?.applyPreferences(args["values"] as? [String: String] ?? [:])
                case "escape": desktops[id]?.exitPresentation()
                case "record.toggle":
                    if let active = recording.removeValue(forKey: id), !active.finished { active.finish(); result(nil); return }
                    var recordArgs = args; recordArgs["mode"] = "record"; recordArgs["format"] = "ts"
                    self.handle(FlutterMethodCall(methodName: "output.start", arguments: recordArgs), result: result); return
                case "mini": desktops[id]?.toggleMini()
                case "fullscreen": desktops[id]?.toggleFullscreen()
                case "snapshot":
                    guard engine.hasVideoOutput else { throw PlayerError.media }
                    let format=(args["format"] as? String)=="jpg" ? "jpg":"png"
                    let name=(args["filename"] as? String) ?? "Tangerine-snapshot.\(format)"
                    let panel = NSSavePanel();panel.nameFieldStringValue=URL(fileURLWithPath:name).lastPathComponent;panel.allowedFileTypes=[format]
                    if let directory=args["directory"] as? String, !directory.isEmpty {panel.directoryURL=URL(fileURLWithPath:(directory as NSString).expandingTildeInPath)}
                    guard panel.runModal() == .OK, let destination = panel.url else { result(nil); return }
                    guard engine.snapshot(to: destination,width:UInt32(max(0,min(1920,(args["width"] as? NSNumber)?.intValue ?? 0)))) else { throw PlayerError.playback }
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
                    let oldDesktop = desktops[id]
                    let desktop = MyVLCDesktop(engine: replacement, windowProvider:{ [weak self] in self?.flutterView?.window })
                    desktop.onPointer = oldDesktop?.onPointer; desktop.onSeek = oldDesktop?.onSeek; desktop.onTransport = oldDesktop?.onTransport
                    if let values = oldDesktop?.currentPreferences { desktop.applyPreferences(values) }
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
