import Foundation
import SwiftUI
import Security

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General", interface = "Interface", privacy = "Privacy", controls = "Controls"
    case playback = "Playback", video = "Video", audio = "Audio", subtitles = "Subtitles", library = "Library"
    case network = "Network", performance = "Performance", recording = "Recording", extensions = "Extensions"
    var id: String { rawValue }
}

enum PreferenceKind {
    case toggle, text, secret, choice([String]), slider(Double, Double, Double), action
}

struct PreferenceSpec: Identifiable {
    let key: String
    let title: String
    let category: SettingsCategory
    let section: String
    let kind: PreferenceKind
    let initial: String
    var option: String? = nil
    var advanced = false
    var unavailable: String? = nil
    var id: String { key }
}

struct PlayerPreferences: Codable, Equatable {
    var values: [String: String] = [:]
    subscript(_ key: String) -> String {
        get { values[key] ?? SettingsCatalog.fields.first { $0.key == key }?.initial ?? "" }
        set { values[key] = newValue }
    }
    func bool(_ key: String) -> Bool { self[key] == "true" }
    func number(_ key: String) -> Double { Double(self[key]) ?? 0 }
    func integer(_ key: String) -> Int { Int(number(key)) }
    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: "playerPreferences"), let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }
    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "playerPreferences") }
    }
    var vlcArguments: [String] {
        var result = SettingsCatalog.fields.compactMap { field -> String? in
            guard let option = field.option, field.unavailable == nil else { return nil }
            let value = self[field.key]
            guard SettingsCatalog.supportedOptions.contains(option) else { return nil }
            if field.key == "preciseSeek" { return "--\(bool(field.key) ? "no-" : "")input-fast-seek" }
            if field.key == "timeshiftSize" { return "--input-timeshift-granularity=\(integer(field.key) * 1024 * 1024)" }
            if field.key == "visualizer" { return value.isEmpty ? "--audio-visual=none" : "--audio-visual=visual" }
            if case .toggle = field.kind { return "--\(bool(field.key) ? "" : "no-")\(option)" }
            return value.isEmpty ? nil : "--\(option)=\(value)"
        }
        let filters: [(String, String)] = [("compressor", "compressor"), ("spatialAudio", "spatializer"),
            ("widening", "stereo_widen"), ("normalize", "normvol"), ("chorus", "chorus_flanger"),
            ("karaoke", "karaoke"), ("pitchEnabled", "scaletempo_pitch")]
        let audio = filters.filter { bool($0.0) }.map(\.1)
        if !audio.isEmpty { result.append("--audio-filter=" + audio.joined(separator: ":")) }
        if self["buffering"] != "Custom" {
            let value = self["buffering"] == "Low latency" ? 150 : (self["buffering"] == "High" ? 5000 : 1000)
            result += ["--network-caching=\(value)", "--file-caching=\(min(value, 1000))", "--live-caching=\(min(value, 1000))", "--disc-caching=\(min(value, 1000))"]
        }
        if !self["visualizer"].isEmpty { result.append("--effect-list=\(self["visualizer"])") }
        if number("postprocess") > 0 { result.append("--video-filter=postproc") }
        if bool("minorWarnings") && integer("verbosity") == 0 { result.append("--verbose=1") }
        if let extra = try? OptionLexer.parse(self["extraOptions"]) { result += extra }
        if bool("twoPass") { result.append("--equalizer-2pass") }
        result.append("--\(self["subtitleUnits"] == "Pixels" ? "freetype-fontsize" : "freetype-rel-fontsize")=\(integer("subtitleSize"))")
        if bool("nightMode") && !bool("compressor") { result.append("--audio-filter=" + (audio + ["compressor"]).joined(separator: ":")); result.append("--compressor-ratio=10") }
        if self["hardware"] == "none" { result += ["--codec=avcodec,any", "--avcodec-hw=none"] }
        else { result.append("--avcodec-hw=any") }
        if self["decoder"] != "any" { result.append("--codec=\(self["decoder"]),any") }
        if bool("scrobble") {
            let username = self["lastfmUser"], password = CredentialStore.read("lastfmPassword")
            if !username.isEmpty && !password.isEmpty {
                result += ["--extraintf=audioscrobbler", "--lastfm-username=\(username)", "--lastfm-password=\(password)", "--scrobbler-url=\(self["scrobbleURL"])"]
            }
        }
        if !self["proxy"].isEmpty {
            let proxyPassword = CredentialStore.read("proxyPassword")
            if !proxyPassword.isEmpty { result.append("--http-proxy-pwd=\(proxyPassword)") }
        }
        if bool("saveLog"), !self["logFile"].isEmpty { result += ["--file-logging", "--logfile=\(self["logFile"])", "--logmode=\(self["logFormat"])"] }
        return result
    }
}

enum CredentialStore {
    static func read(_ key: String) -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.myplayer.credentials", kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    @discardableResult static func write(_ value: String, key: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.myplayer.credentials", kSecAttrAccount as String: key]
        if value.isEmpty { let status = SecItemDelete(query as CFDictionary); return status == errSecSuccess || status == errSecItemNotFound }
        let attributes = [kSecValueData as String: Data(value.utf8)]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { return SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess }
        return status == errSecSuccess
    }
}

enum SettingsCatalog {
    static let supportedOptions: Set<String> = {
        guard let url = Bundle.main.url(forResource: "VLCOptions", withExtension: "json"),
              let data = try? Data(contentsOf: url), let options = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(options)
    }()
    private static func b(_ key: String, _ title: String, _ c: SettingsCategory, _ s: String, _ initial: Bool = false, _ option: String? = nil) -> PreferenceSpec {
        PreferenceSpec(key: key, title: title, category: c, section: s, kind: .toggle, initial: String(initial), option: option)
    }
    private static func t(_ key: String, _ title: String, _ c: SettingsCategory, _ s: String, _ initial: String = "", _ option: String? = nil) -> PreferenceSpec {
        PreferenceSpec(key: key, title: title, category: c, section: s, kind: .text, initial: initial, option: option)
    }
    private static func p(_ key: String, _ title: String, _ c: SettingsCategory, _ s: String, _ choices: [String], _ initial: String, _ option: String? = nil) -> PreferenceSpec {
        PreferenceSpec(key: key, title: title, category: c, section: s, kind: .choice(choices), initial: initial, option: option)
    }
    private static func n(_ key: String, _ title: String, _ c: SettingsCategory, _ s: String, _ initial: Double, _ min: Double, _ max: Double, _ step: Double = 1, _ option: String? = nil) -> PreferenceSpec {
        PreferenceSpec(key: key, title: title, category: c, section: s, kind: .slider(min, max, step), initial: String(initial), option: option)
    }
    private static func a(_ key: String, _ title: String, _ c: SettingsCategory, _ s: String) -> PreferenceSpec {
        PreferenceSpec(key: key, title: title, category: c, section: s, kind: .action, initial: "")
    }
    private static func secret(_ key: String, _ title: String, _ c: SettingsCategory, _ s: String) -> PreferenceSpec {
        PreferenceSpec(key: key, title: title, category: c, section: s, kind: .secret, initial: "")
    }
    static let fields: [PreferenceSpec] = [
        p("language", "Interface language", .general, "Appearance", ["English"], "English"),
        p("theme", "Theme", .general, "Appearance", ["Dark", "Light", "System"], "Dark"),
        t("accent", "Accent color (hex)", .general, "Appearance", "D37918"),
        b("dialogs", "Show confirmation and error dialogs", .general, "Startup", true),
        b("autoUpdates", "Check for updates automatically", .general, "Startup"),
        t("updateFeed", "Update feed URL", .general, "Startup"),
        a("checkUpdates", "Check for updates now", .general, "Startup"),
        b("developer", "Developer mode", .general, "Diagnostics"),
        b("saveLog", "Save a log", .general, "Diagnostics"),
        t("logFile", "Log file", .general, "Diagnostics"),
        p("verbosity", "Log details", .general, "Diagnostics", ["0", "1", "2"], "0", "verbose"),
        p("logFormat", "Log format", .general, "Diagnostics", ["text", "html"], "text"),
        b("statistics", "Collect playback statistics", .general, "Advanced Options", true, "stats"),
        b("minorWarnings", "Show minor warnings", .general, "Advanced Options"),
        t("extraOptions", "Additional libVLC command line options", .general, "Advanced Options"),
        b("systemLog", "Write to the system log", .general, "Advanced Options", false, "syslog"),
        t("syslogIdentity", "System log identity", .general, "Advanced Options", "MyVLC", "syslog-ident"),
        p("syslogFacility", "System log facility", .general, "Advanced Options", ["user", "daemon", "local0"], "user", "syslog-facility"),
        a("openConfig", "Open configurations folder", .general, "Advanced Options"),
        a("resetSettings", "Reset all settings", .general, "Advanced Options"),
        b("customSkin", "Use a custom skin", .interface, "Skin"),
        t("skinFile", "Skin file (MyVLC JSON)", .interface, "Skin"),
        a("loadSkin", "Choose skin…", .interface, "Skin"),
        b("embeddedVideo", "Play video inside main window", .interface, "Window", true),
        p("resizeVideo", "Resize window to fit video", .interface, "Window", ["Never", "Always", "On first video"], "Never"),
        b("rememberWindow", "Remember window size and position", .interface, "Window", true),
        b("alwaysOnTop", "Keep window above other windows", .interface, "Window"),
        b("decorations", "Show window decorations", .interface, "Window", true),
        b("filenameTitle", "Show the file name in the title bar", .interface, "Window", true),
        p("fullscreenScreen", "Open fullscreen on", .interface, "Window", ["Current screen", "Main screen"], "Current screen"),
        b("compactStartup", "Start in compact mode", .interface, "Playback Controls"),
        p("autoHide", "Auto-hide the controls", .interface, "Playback Controls", ["Never", "In fullscreen only", "Always"], "In fullscreen only"),
        n("hideAfter", "Hide after (seconds)", .interface, "Playback Controls", 3, 1, 10),
        b("fullscreenControls", "Show controls in fullscreen", .interface, "Playback Controls", true),
        b("trayIcon", "Show a menu bar icon", .interface, "Notifications and System Tray"),
        b("startMinimized", "Start minimized to the menu bar", .interface, "Notifications and System Tray"),
        p("trackPopup", "Show a popup when the track changes", .interface, "Notifications and System Tray", ["Never", "When minimized", "Always"], "Never"),
        n("popupDuration", "Popup duration (seconds)", .interface, "Notifications and System Tray", 3, 1, 10),
        b("playlistTree", "Show the playlist as a tree", .interface, "Playlist"),
        n("opacity", "Window opacity", .interface, "Advanced Options", 1, 0.1, 1, 0.05),
        b("pauseMinimized", "Pause video when window is minimized", .interface, "Advanced Options"),
        b("frontPlayback", "Bring app to the front when playback starts", .interface, "Advanced Options"),
        b("coverArt", "Show cover art when playing audio", .interface, "Advanced Options", true),
        n("controlsOpacity", "Fullscreen controls opacity", .interface, "Advanced Options", 1, 0.1, 1, 0.05),
        b("saveHistory", "Save recently played items", .privacy, "History", true),
        b("resume", "Remember the playback position", .privacy, "History", true),
        t("historyExclusion", "Never remember items matching (regular expression)", .privacy, "History"),
        a("clearHistory", "Clear history now", .privacy, "History"),
        b("fetchArtwork", "Fetch titles and cover art from the internet", .privacy, "Network"),
        b("scrobble", "Submit played tracks to last.fm", .privacy, "Network"),
        t("lastfmUser", "Last.fm username", .privacy, "Network"),
        secret("lastfmPassword", "Last.fm password", .privacy, "Network"),
        t("scrobbleURL", "Last.fm submission URL", .privacy, "Network", "post.audioscrobbler.com"),
        a("editShortcuts", "Edit keyboard shortcuts", .controls, "Keyboard Shortcuts"),
        a("resetShortcuts", "Reset all shortcuts", .controls, "Keyboard Shortcuts"),
        n("skipVeryShort", "Very short skip (seconds)", .controls, "Skip Amounts", 3, 1, 30),
        n("skipShort", "Short skip (seconds)", .controls, "Skip Amounts", 10, 1, 120),
        n("skipMedium", "Medium skip (seconds)", .controls, "Skip Amounts", 60, 1, 600),
        n("skipLong", "Long skip (seconds)", .controls, "Skip Amounts", 300, 1, 1800),
        p("singleClick", "Single click on the video", .controls, "Mouse", ["Nothing", "Play / Pause", "Toggle fullscreen"], "Play / Pause"),
        p("doubleClick", "Double click on the video", .controls, "Mouse", ["Nothing", "Play / Pause", "Toggle fullscreen"], "Toggle fullscreen"),
        p("scroll", "Scroll wheel", .controls, "Mouse", ["Nothing", "Volume", "Seek"], "Volume"),
        p("horizontalScroll", "Horizontal scroll", .controls, "Mouse", ["Nothing", "Volume", "Seek"], "Seek"),
        b("reverseScroll", "Reverse scroll direction", .controls, "Mouse"),
        b("webRemote", "Web remote control", .controls, "Remotes"),
        t("remotePort", "Port", .controls, "Remotes", "8088"),
        b("remoteLAN", "Allow local network connections", .controls, "Remotes"),
        secret("remotePassword", "Remote password", .controls, "Remotes"),
        a("openRemote", "Open web remote", .controls, "Remotes"),
        p("continue", "Continue where you left off", .playback, "Startup", ["Always", "Ask", "Never"], "Always"),
        b("startPlaying", "Start playing as soon as a file opens", .playback, "Startup", true),
        n("speed", "Default playback speed", .playback, "Startup", 1, 0.25, 4, 0.25),
        b("pauseOtherAudio", "Pause when another app uses audio", .playback, "Startup"),
        p("quality", "Preferred video quality", .playback, "Tracks", ["-1", "1080", "720", "480", "360"], "-1", "preferred-resolution"),
        t("menuLanguage", "Preferred menu language", .playback, "Tracks", "en", "menu-language"),
        t("audioTrack", "Default audio track (-1 = automatic)", .playback, "Tracks", "-1", "audio-track"),
        t("subtitleTrack", "Default subtitle track (-1 = automatic)", .playback, "Tracks", "-1", "sub-track"),
        p("repeat", "Repeat", .playback, "Order", ["off", "all", "one"], "off"),
        b("shuffle", "Shuffle", .playback, "Order"),
        b("stopEach", "Stop after each item", .playback, "Order"),
        p("finished", "When playback finishes", .playback, "Order", ["Stop", "Quit", "Minimize"], "Stop"),
        b("preciseSeek", "Seek precisely", .playback, "Seeking", true, "input-fast-seek"),
        b("scrubThumbnail", "Show thumbnail while scrubbing", .playback, "Seeking", true),
        t("opticalDrive", "Default optical drive", .playback, "Files & Discs", "", "dvd"),
        p("aviRepair", "Repair damaged AVI files", .playback, "Files & Discs", ["0", "1", "2"], "0", "avi-index"),
        b("matchingMKV", "Load matching .mkv files from the same folder", .playback, "Files & Discs", true, "mkv-preload-local-dir"),
        t("timeshiftFolder", "Time-shift buffer folder", .playback, "Advanced Options", "", "input-timeshift-path"),
        n("timeshiftSize", "Time-shift buffer size (MB)", .playback, "Advanced Options", 50, 1, 1024, 1, "input-timeshift-granularity"),
        b("videoEnabled", "Enable video", .video, "Output", true, "video"),
        b("startFullscreen", "Start videos in fullscreen", .video, "Output"),
        b("preventSleep", "Stop the screensaver during playback", .video, "Output", true),
        b("wallpaper", "Play video as desktop wallpaper", .video, "Output"),
        n("hue", "Hue", .video, "Picture", 0, -180, 180),
        n("brightness", "Brightness", .video, "Picture", 1, 0, 2, 0.05),
        n("contrast", "Contrast", .video, "Picture", 1, 0, 2, 0.05),
        n("saturation", "Saturation", .video, "Picture", 1, 0, 3, 0.05),
        n("gamma", "Gamma", .video, "Picture", 1, 0.01, 10, 0.05),
        a("resetPicture", "Reset picture", .video, "Picture"),
        p("deinterlace", "Deinterlacing", .video, "Deinterlacing", ["off", "auto", "on"], "auto"),
        p("deinterlaceMode", "Method", .video, "Deinterlacing", ["auto", "blend", "bob", "yadif", "yadif2x", "linear"], "auto"),
        p("aspect", "Aspect ratio", .video, "Framing", ["", "16:9", "16:10", "4:3", "1:1", "2.35:1", "2.39:1"], ""),
        p("crop", "Crop", .video, "Framing", ["", "16:9", "16:10", "4:3", "1:1", "2.35:1", "2.39:1"], ""),
        n("zoom", "Zoom (0 = fit)", .video, "Framing", 0, 0, 3, 0.25),
        p("alignment", "Position in the window", .video, "Framing", ["0", "1", "2", "4", "8"], "0", "align"),
        t("snapshotFolder", "Save snapshots to", .video, "Snapshots", "~/Pictures/MyVLC"),
        t("snapshotPrefix", "File name prefix", .video, "Snapshots", "MyVLC-"),
        p("snapshotFormat", "Format", .video, "Snapshots", ["png", "jpg"], "png"),
        p("snapshotWidth", "Size (width, 0 = same as video)", .video, "Snapshots", ["0", "640", "1280", "1920"], "0"),
        b("snapshotSequential", "Number files sequentially", .video, "Snapshots", true),
        b("snapshotPreview", "Show a preview after capture", .video, "Snapshots", true),
        a("takeSnapshot", "Take snapshot", .video, "Snapshots"),
        b("audioEnabled", "Enable audio", .audio, "Output", true, "audio"),
        t("outputDevice", "Output device ID (empty = system default)", .audio, "Output"),
        a("chooseOutput", "Choose output device…", .audio, "Output"),
        p("speakerSetup", "Speaker setup", .audio, "Output", ["0", "1", "2", "3", "4", "5", "6", "7"], "0", "stereo-mode"),
        n("maxVolume", "Maximum volume (%)", .audio, "Volume", 100, 100, 300, 10),
        b("rememberVolume", "Remember last volume", .audio, "Volume", true),
        n("startupVolume", "Always starts at (%)", .audio, "Volume", 75, 0, 300, 5),
        n("volumeStep", "Volume step", .audio, "Volume", 5, 1, 25),
        b("normalize", "Normalize loudness", .audio, "Loudness"),
        n("normalizeLevel", "Target level", .audio, "Loudness", 2, 0.1, 10, 0.1, "norm-max-level"),
        b("nightMode", "Night mode", .audio, "Loudness"),
        p("replayGain", "Replay gain", .audio, "Loudness", ["none", "track", "album"], "none", "audio-replay-gain-mode"),
        n("replayPreamp", "Replay gain preamp (dB)", .audio, "Loudness", 0, -20, 20, 0.5, "audio-replay-gain-preamp"),
        b("equalizer", "Equalizer", .audio, "Effects"),
        a("openEQ", "Open equalizer", .audio, "Effects"),
        b("twoPass", "Two-pass", .audio, "Effects"),
        b("spatialAudio", "Spatial audio", .audio, "Effects"),
        b("widening", "Stereo widening", .audio, "Effects"),
        b("compressor", "Compressor", .audio, "Effects"),
        b("pitchEnabled", "Pitch shift", .audio, "Effects"),
        n("pitch", "Pitch (semitones)", .audio, "Effects", 0, -12, 12, 0.25, "pitch-shift"),
        b("chorus", "Chorus / flanger", .audio, "Effects"),
        b("karaoke", "Karaoke", .audio, "Effects"),
        t("audioLanguage", "Preferred audio language", .audio, "Tracks", "", "audio-language"),
        n("audioDelay", "Audio delay (seconds)", .audio, "Tracks", 0, -10, 10, 0.05),
        p("visualizer", "Visualizer", .audio, "Visualization", ["", "spectrometer", "scope", "spectrum", "vuMeter"], "", "audio-visual"),
        b("subtitlesEnabled", "Enable subtitles", .subtitles, "Tracks & Languages", true, "spu"),
        t("subtitleLanguage", "Preferred language", .subtitles, "Tracks & Languages", "", "sub-language"),
        p("encoding", "Text encoding", .subtitles, "Tracks & Languages", ["", "UTF-8", "UTF-16", "ISO-8859-1", "Windows-1252"], "", "subsdec-encoding"),
        b("autoSubtitles", "Load subtitle files automatically", .subtitles, "Loading Subtitles", true, "sub-autodetect-file"),
        p("subtitleMatch", "File name matching", .subtitles, "Loading Subtitles", ["1", "2", "3", "4"], "3", "sub-autodetect-fuzzy"),
        t("subtitleFont", "Font", .subtitles, "Appearance", "Helvetica", "freetype-font"),
        p("subtitleUnits", "Size values", .subtitles, "Appearance", ["Relative", "Pixels"], "Relative"),
        n("subtitleSize", "Font size", .subtitles, "Appearance", 16, 6, 100, 1),
        b("subtitleBold", "Bold", .subtitles, "Appearance", false, "freetype-bold"),
        t("subtitleColor", "Text color", .subtitles, "Appearance", "16777215", "freetype-color"),
        n("subtitleOpacity", "Text opacity", .subtitles, "Appearance", 255, 0, 255, 1, "freetype-opacity"),
        n("outline", "Outline thickness", .subtitles, "Appearance", 2, 0, 6, 1, "freetype-outline-thickness"),
        t("outlineColor", "Outline color", .subtitles, "Appearance", "0", "freetype-outline-color"),
        n("shadow", "Shadow opacity", .subtitles, "Appearance", 128, 0, 255, 1, "freetype-shadow-opacity"),
        t("shadowColor", "Shadow color", .subtitles, "Appearance", "0", "freetype-shadow-color"),
        n("shadowDistance", "Shadow distance", .subtitles, "Appearance", 0.06, 0, 1, 0.01, "freetype-shadow-distance"),
        t("backgroundColor", "Background color", .subtitles, "Appearance", "0", "freetype-background-color"),
        n("backgroundOpacity", "Background opacity", .subtitles, "Appearance", 0, 0, 255, 1, "freetype-background-opacity"),
        n("subtitlePosition", "Vertical position (px from bottom)", .subtitles, "Appearance", 0, 0, 500, 1, "sub-margin"),
        n("subtitleDelay", "Subtitle delay (seconds)", .subtitles, "Timing", 0, -5, 5, 0.05),
        b("shortcutFeedback", "Show feedback for shortcuts", .subtitles, "On-Screen Messages", true),
        n("feedbackDuration", "Show feedback for (seconds)", .subtitles, "On-Screen Messages", 2, 0.5, 5, 0.5),
        b("filenameOSD", "Show filename when a video starts", .subtitles, "On-Screen Messages"),
        n("filenameDuration", "Show filename for (seconds)", .subtitles, "On-Screen Messages", 3, 1, 10),
        b("singleWindow", "Only allow one MyVLC window", .library, "Opening Files", true),
        b("enqueue", "Add to the playlist instead of replacing it", .library, "Opening Files", true),
        b("recursive", "Include subfolders", .library, "Opening Files", true),
        b("hiddenFiles", "Show hidden files", .library, "Opening Files"),
        p("metadata", "Fetch titles and artwork", .library, "Metadata & Artwork", ["From the file only", "Allow network"], "From the file only"),
        b("mediaLibrary", "Use the media library", .library, "Metadata & Artwork", true),
        p("buffering", "Buffering", .network, "Buffering", ["Low latency", "Normal", "High", "Custom"], "Normal"),
        n("fileCache", "Local files (ms)", .network, "Buffering", 300, 0, 10000, 50, "file-caching"),
        n("discCache", "Discs (ms)", .network, "Buffering", 300, 0, 10000, 50, "disc-caching"),
        n("networkCache", "Network streams (ms)", .network, "Buffering", 1000, 0, 20000, 100, "network-caching"),
        n("liveCache", "Live capture (ms)", .network, "Buffering", 300, 0, 10000, 50, "live-caching"),
        t("proxy", "HTTP proxy (empty = system)", .network, "Proxy", "", "http-proxy"),
        secret("proxyPassword", "HTTP proxy password", .network, "Proxy"),
        b("verifyCertificates", "Verify certificates against the system trust store", .network, "Security", true, "gnutls-system-trust"),
        p("cipher", "Cipher preference", .network, "Security", ["NORMAL", "SECURE128", "SECURE256"], "NORMAL", "gnutls-priorities"),
        p("hardware", "Hardware-accelerated decoding", .performance, "Decoding", ["none", "automatic"], "none"),
        n("postprocess", "Video post-processing", .performance, "Decoding", 0, 0, 6, 1, "postproc-q"),
        p("loopFilter", "Skip the H.264 loop filter", .performance, "Decoding", ["0", "1", "2", "3", "4"], "0", "avcodec-skiploopfilter"),
        n("threads", "Decoding threads (0 = automatic)", .performance, "Decoding", 0, 0, 32, 1, "avcodec-threads"),
        b("dropFrames", "Drop frames when the system cannot keep up", .performance, "Smooth Playback", true, "drop-late-frames"),
        PreferenceSpec(key: "realtimePriority", title: "Give VLC real-time priority", category: .performance, section: "Smooth Playback", kind: .toggle, initial: "false", unavailable: "VLC's Windows process-priority controls are unavailable in this native macOS app."),
        PreferenceSpec(key: "processPriority", title: "Process priority", category: .performance, section: "Smooth Playback", kind: .slider(-20, 20, 1), initial: "0", unavailable: "macOS manages playback scheduling. Raising process priority requires privileged system access and is not supported here."),
        a("rescanPlugins", "Rescan plugins", .performance, "Smooth Playback"),
        p("encoder", "Encoder", .performance, "Developer", ["any", "x264", "avcodec"], "any", "sout-transcode-venc"),
        p("decoder", "Decoder", .performance, "Developer", ["any", "avcodec", "videotoolbox"], "any"),
        p("clockSync", "Clock synchronisation", .performance, "Developer", ["-1", "0", "1"], "-1", "clock-synchro"),
        n("clockJitter", "Clock jitter (ms)", .performance, "Developer", 5000, 0, 20000, 100, "clock-jitter"),
        n("clockAverage", "Clock reference averaging", .performance, "Developer", 40, 1, 200, 1, "clock-average"),
        t("recordFolder", "Save recordings to", .recording, "Recording", "~/Movies/MyVLC"),
        b("recordOriginal", "Record without re-encoding when possible", .recording, "Recording", true),
        a("record", "Start / stop recording", .recording, "Recording"),
        b("discoverCast", "Discover cast devices", .recording, "Casting"),
        p("castQuality", "Cast quality", .recording, "Casting", ["0", "1", "2"], "0", "sout-chromecast-conversion-quality"),
        a("cast", "Choose cast device…", .recording, "Casting"),
        b("streamLocal", "Play locally while streaming", .recording, "Streaming", true),
        b("streamAudio", "Include audio", .recording, "Streaming", true),
        b("streamVideo", "Include video", .recording, "Streaming", true),
        b("streamSubtitles", "Include subtitles", .recording, "Streaming", true),
        p("encodingPreset", "Encoding preset", .recording, "Streaming", ["ultrafast", "fast", "medium", "slow"], "medium", "sout-x264-preset"),
        p("tuning", "Tuning", .recording, "Streaming", ["", "film", "animation", "grain", "zerolatency"], "", "sout-x264-tune"),
        a("streamOut", "Stream output…", .recording, "Streaming"),
        a("addons", "Manage add-ons and scripts…", .extensions, "Add-ons"),
        b("loadAddons", "Load add-ons on startup", .extensions, "Add-ons", true),
        a("findAddons", "Find more extensions", .extensions, "Add-ons")
    ] + effectFields

    static let effectFields: [PreferenceSpec] = [
        n("compressorRMS", "RMS / peak", .audio, "Compressor", 0, 0, 1, 0.01, "compressor-rms-peak"),
        n("compressorAttack", "Attack (ms)", .audio, "Compressor", 25, 1.5, 400, 0.5, "compressor-attack"),
        n("compressorRelease", "Release (ms)", .audio, "Compressor", 100, 2, 800, 1, "compressor-release"),
        n("compressorThreshold", "Threshold (dB)", .audio, "Compressor", -11, -30, 0, 0.5, "compressor-threshold"),
        n("compressorRatio", "Ratio", .audio, "Compressor", 4, 1, 20, 0.1, "compressor-ratio"),
        n("compressorKnee", "Knee (dB)", .audio, "Compressor", 5, 1, 10, 0.1, "compressor-knee"),
        n("compressorGain", "Makeup gain (dB)", .audio, "Compressor", 7, 0, 24, 0.5, "compressor-makeup-gain"),
        n("roomSize", "Room size", .audio, "Spatializer", 0.85, 0, 1.1, 0.01, "spatializer-roomsize"),
        n("spatialWidth", "Width", .audio, "Spatializer", 1, 0, 1, 0.01, "spatializer-width"),
        n("spatialWet", "Wet", .audio, "Spatializer", 0.4, 0, 1, 0.01, "spatializer-wet"),
        n("spatialDry", "Dry", .audio, "Spatializer", 0.5, 0, 1, 0.01, "spatializer-dry"),
        n("spatialDamp", "Damp", .audio, "Spatializer", 0.5, 0, 1, 0.01, "spatializer-damp"),
        n("widenDelay", "Delay (ms)", .audio, "Stereo Widener", 20, 1, 100, 1, "stereowiden-delay"),
        n("widenFeedback", "Feedback", .audio, "Stereo Widener", 0.3, 0, 0.9, 0.01, "stereowiden-feedback"),
        n("widenCrossfeed", "Crossfeed", .audio, "Stereo Widener", 0.3, 0, 0.8, 0.01, "stereowiden-crossfeed"),
        n("widenDry", "Dry mix", .audio, "Stereo Widener", 0.8, 0, 1, 0.01, "stereowiden-dry-mix"),
        n("chorusDelay", "Delay (ms)", .audio, "Chorus / Flanger", 20, 0, 100, 1, "delay-time"),
        n("chorusDepth", "Sweep depth", .audio, "Chorus / Flanger", 6, 0, 20, 0.1, "sweep-depth"),
        n("chorusRate", "Sweep rate", .audio, "Chorus / Flanger", 6, 0.1, 20, 0.1, "sweep-rate"),
        n("cropTop", "Top (pixels)", .video, "Crop edges", 0, 0, 1000),
        n("cropBottom", "Bottom (pixels)", .video, "Crop edges", 0, 0, 1000),
        n("cropLeft", "Left (pixels)", .video, "Crop edges", 0, 0, 1000),
        n("cropRight", "Right (pixels)", .video, "Crop edges", 0, 0, 1000)
    ]
}
