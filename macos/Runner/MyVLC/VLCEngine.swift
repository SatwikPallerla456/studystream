import AppKit
import CLibVLC

struct MediaTrack: Identifiable, Equatable {
    let id: Int32
    let name: String
}

enum PlayerError: LocalizedError {
    case initialization, media, playback, subtitle
    var errorDescription: String? {
        switch self {
        case .initialization: return "libVLC could not start. Install VLC 3 for macOS, then rebuild MyVLC."
        case .media: return "This media could not be opened. Check that the file exists or the stream address is correct."
        case .playback: return "libVLC could not play this media. Check the file, network connection, or stream permissions."
        case .subtitle: return "The subtitle file could not be added. Open a video first and choose an SRT, ASS, or VTT file."
        }
    }
}

/// Owns libVLC's C objects. All calls are serialized on the main thread.
@MainActor
final class VLCEngine {
    let instance: OpaquePointer
    let player: OpaquePointer
    private(set) var hasMedia = false

    init(headless: Bool = false, preferences: PlayerPreferences? = nil, extraArguments: [String] = []) throws {
        let vlcApp = ProcessInfo.processInfo.environment["VLC_APP_PATH"] ?? "/Applications/VLC.app"
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("VLC/plugins")
        let plugins = bundled.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0.path : nil } ?? "\(vlcApp)/Contents/MacOS/plugins"
        setenv("VLC_PLUGIN_PATH", plugins, 1)
        // VLC 3's VideoToolbox decoder can stall on newer macOS releases.
        // Prefer libavcodec's software path for a predictable embedded player.
        let arguments = ["--no-video-title-show", "--no-osd", "--no-snapshot-preview"] +
            ((preferences?.bool("saveLog") == true || preferences?.bool("developer") == true) ? [] : ["--quiet"]) +
            (preferences?.vlcArguments ?? ["--codec=avcodec,any", "--avcodec-hw=none"]) +
            (headless ? ["--vout=dummy"] : ["--vout=macosx"]) + extraArguments
        let strings = arguments.map { strdup($0) }
        defer { strings.forEach { free($0) } }
        let argv = strings.map { UnsafePointer<CChar>($0) }
        guard let instance = argv.withUnsafeBufferPointer({ libvlc_new(Int32($0.count), $0.baseAddress) }) else {
            throw PlayerError.initialization
        }
        guard let player = libvlc_media_player_new(instance) else {
            libvlc_release(instance)
            throw PlayerError.initialization
        }
        self.instance = instance
        self.player = player
        libvlc_video_set_mouse_input(player, 0)
        libvlc_video_set_key_input(player, 0)
    }

    func attach(to view: NSView) {
        libvlc_media_player_set_nsobject(player, Unmanaged.passUnretained(view).toOpaque())
    }

    func open(_ url: URL, options: [String] = [], fetchNetworkMetadata: Bool = false) throws {
        if url.isFileURL && !FileManager.default.fileExists(atPath: url.path) { throw PlayerError.media }
        let media = url.isFileURL ? libvlc_media_new_path(instance, url.path) : libvlc_media_new_location(instance, url.absoluteString)
        guard let media else { throw PlayerError.media }
        defer { libvlc_media_release(media) }
        for option in options { libvlc_media_add_option_flag(media, option, UInt32(libvlc_media_option_trusted)) }
        libvlc_media_player_set_media(player, media)
        let flags = UInt32(libvlc_media_parse_local.rawValue) | UInt32(fetchNetworkMetadata ? libvlc_media_fetch_network.rawValue : libvlc_media_fetch_local.rawValue)
        libvlc_media_parse_with_options(media, libvlc_media_parse_flag_t(rawValue: flags), 2000)
        hasMedia = true
        guard libvlc_media_player_play(player) == 0 else { throw PlayerError.playback }
    }

    var state: libvlc_state_t { libvlc_media_player_get_state(player) }
    var isPlaying: Bool { libvlc_media_player_is_playing(player) != 0 }
    var time: Int64 { max(0, libvlc_media_player_get_time(player)) }
    var duration: Int64 { max(0, libvlc_media_player_get_length(player)) }
    var seekable: Bool { libvlc_media_player_is_seekable(player) != 0 }
    var videoTrackCount: Int32 { libvlc_video_get_track_count(player) }
    var hasVideoOutput: Bool { libvlc_media_player_has_vout(player) > 0 }
    var rate: Float { libvlc_media_player_get_rate(player) }
    var volume: Int32 {
        get { libvlc_audio_get_volume(player) }
        set { libvlc_audio_set_volume(player, max(0, min(300, newValue))) }
    }
    var muted: Bool {
        get { libvlc_audio_get_mute(player) == 1 }
        set { libvlc_audio_set_mute(player, newValue ? 1 : 0) }
    }
    func pause(_ paused: Bool) { libvlc_media_player_set_pause(player, paused ? 1 : 0) }
    func play() { libvlc_media_player_play(player) }
    func stop() { libvlc_media_player_stop(player) }
    func seek(to milliseconds: Int64) {
        guard seekable else { return }
        libvlc_media_player_set_time(player, max(0, min(duration, milliseconds)))
    }
    func setRate(_ value: Float) -> Bool { libvlc_media_player_set_rate(player, value) == 0 }
    func addSubtitle(_ url: URL) throws {
        guard hasMedia, libvlc_media_player_add_slave(player, libvlc_media_slave_type_subtitle, url.absoluteString, true) == 0 else {
            throw PlayerError.subtitle
        }
    }
    var subtitleTrack: Int32 {
        get { libvlc_video_get_spu(player) }
        set { libvlc_video_set_spu(player, newValue) }
    }
    var audioTrack: Int32 {
        get { libvlc_audio_get_track(player) }
        set { libvlc_audio_set_track(player, newValue) }
    }
    private func tracks(_ first: UnsafeMutablePointer<libvlc_track_description_t>?) -> [MediaTrack] {
        defer { if let first { libvlc_track_description_list_release(first) } }
        var result: [MediaTrack] = []
        var node = first
        while let track = node?.pointee {
            result.append(MediaTrack(id: track.i_id, name: track.psz_name.map { String(cString: $0) } ?? "Track \(track.i_id)"))
            node = track.p_next
        }
        return result
    }
    var audioTracks: [MediaTrack] { tracks(libvlc_audio_get_track_description(player)) }
    var subtitleTracks: [MediaTrack] { tracks(libvlc_video_get_spu_description(player)) }
    var version: String { String(cString: libvlc_get_version()) }
    var metadata: [String: String] {
        guard let media = libvlc_media_player_get_media(player) else { return [:] }
        var values: [String: String] = [:]
        for (name, field) in [("Title", libvlc_meta_Title), ("Artist", libvlc_meta_Artist), ("Album", libvlc_meta_Album), ("Genre", libvlc_meta_Genre), ("Artwork", libvlc_meta_ArtworkURL)] {
            if let pointer = libvlc_media_get_meta(media, field) { values[name] = String(cString: pointer); libvlc_free(pointer) }
        }
        return values
    }
    var statistics: [String: String] {
        guard let media = libvlc_media_player_get_media(player) else { return [:] }
        var stats = libvlc_media_stats_t()
        guard libvlc_media_get_stats(media, &stats) != 0 else { return [:] }
        return ["Decoded video frames": String(stats.i_decoded_video), "Displayed pictures": String(stats.i_displayed_pictures),
                "Lost pictures": String(stats.i_lost_pictures), "Decoded audio buffers": String(stats.i_decoded_audio),
                "Lost audio buffers": String(stats.i_lost_abuffers), "Read bytes": String(stats.i_read_bytes),
                "Input bitrate (Mb/s)": String(format: "%.3f", stats.f_input_bitrate * 8)]
    }

    var videoSize: CGSize {
        var width: UInt32 = 0, height: UInt32 = 0
        libvlc_video_get_size(player, 0, &width, &height)
        return CGSize(width: Int(width), height: Int(height))
    }
    func applyEqualizer(_ settings: EqualizerSettings) {
        guard settings.enabled, let eq = libvlc_audio_equalizer_new() else {
            libvlc_media_player_set_equalizer(player, nil); return
        }
        defer { libvlc_audio_equalizer_release(eq) }
        libvlc_audio_equalizer_set_preamp(eq, settings.preamp)
        for (index, value) in settings.bands.enumerated() where index < Int(libvlc_audio_equalizer_get_band_count()) {
            libvlc_audio_equalizer_set_amp_at_index(eq, max(-20, min(20, value)), UInt32(index))
        }
        libvlc_media_player_set_equalizer(player, eq)
    }
    static var equalizerPresets: [String] {
        (0..<libvlc_audio_equalizer_get_preset_count()).map { String(cString: libvlc_audio_equalizer_get_preset_name($0)) }
    }
    static func preset(_ index: UInt32) -> EqualizerSettings {
        guard index < libvlc_audio_equalizer_get_preset_count(), let eq = libvlc_audio_equalizer_new_from_preset(index) else { return EqualizerSettings() }
        defer { libvlc_audio_equalizer_release(eq) }
        return EqualizerSettings(enabled: true, preset: index, preamp: libvlc_audio_equalizer_get_preamp(eq),
                                 bands: (0..<libvlc_audio_equalizer_get_band_count()).map { libvlc_audio_equalizer_get_amp_at_index(eq, $0) })
    }
    func applyLive(_ p: PlayerPreferences) {
        let adjusted = ["brightness", "contrast", "saturation", "gamma"].contains { p.number($0) != 1 } || p.number("hue") != 0
        libvlc_video_set_adjust_int(player, UInt32(libvlc_adjust_Enable.rawValue), adjusted ? 1 : 0)
        for (key, option) in [("brightness", libvlc_adjust_Brightness), ("contrast", libvlc_adjust_Contrast),
                              ("saturation", libvlc_adjust_Saturation), ("gamma", libvlc_adjust_Gamma)] {
            libvlc_video_set_adjust_float(player, UInt32(option.rawValue), Float(p.number(key)))
        }
        libvlc_video_set_adjust_int(player, UInt32(libvlc_adjust_Hue.rawValue), Int32(p.integer("hue")))
        p["aspect"].withCString { libvlc_video_set_aspect_ratio(player, $0) }
        var crop = p["crop"]
        if ["cropTop", "cropBottom", "cropLeft", "cropRight"].contains(where: { p.integer($0) > 0 }) {
            let size = videoSize
            if size.width > 0 && size.height > 0 {
                let left = min(Int(size.width) - 1, p.integer("cropLeft")), top = min(Int(size.height) - 1, p.integer("cropTop"))
                crop = "\(max(1, Int(size.width) - left - p.integer("cropRight")))x\(max(1, Int(size.height) - top - p.integer("cropBottom")))+\(left)+\(top)"
            }
        }
        crop.withCString { libvlc_video_set_crop_geometry(player, $0) }
        libvlc_video_set_scale(player, Float(p.number("zoom")))
        if p["deinterlace"] == "off" { libvlc_video_set_deinterlace(player, nil) }
        else { p["deinterlaceMode"].withCString { libvlc_video_set_deinterlace(player, $0) } }
        libvlc_audio_set_delay(player, Int64(p.number("audioDelay") * 1_000_000))
        libvlc_video_set_spu_delay(player, Int64(p.number("subtitleDelay") * 1_000_000))
        if !p["outputDevice"].isEmpty { p["outputDevice"].withCString { libvlc_audio_output_device_set(player, nil, $0) } }
    }
    var outputDevices: [MediaTrack] {
        let first = libvlc_audio_output_device_enum(player)
        defer { if let first { libvlc_audio_output_device_list_release(first) } }
        var result: [MediaTrack] = []; var node = first; var index: Int32 = 0
        while let value = node?.pointee {
            result.append(MediaTrack(id: index, name: value.psz_description.map { String(cString: $0) } ?? "Audio device"))
            index += 1; node = value.p_next
        }
        return result
    }
    var outputDeviceIDs: [(String, String)] {
        let first = libvlc_audio_output_device_enum(player)
        defer { if let first { libvlc_audio_output_device_list_release(first) } }
        var result: [(String, String)] = []; var node = first
        while let value = node?.pointee {
            result.append((value.psz_device.map { String(cString: $0) } ?? "", value.psz_description.map { String(cString: $0) } ?? "Audio device"))
            node = value.p_next
        }
        return result
    }
    func snapshot(to url: URL, width: UInt32 = 0) -> Bool {
        libvlc_video_take_snapshot(player, 0, url.path, width, 0) == 0
    }
    var chapterCount: Int32 { libvlc_media_player_get_chapter_count(player) }
    var chapter: Int32 {
        get { libvlc_media_player_get_chapter(player) }
        set { libvlc_media_player_set_chapter(player, newValue) }
    }
    func nextFrame() { libvlc_media_player_next_frame(player) }

    deinit {
        libvlc_media_player_stop(player)
        libvlc_media_player_set_nsobject(player, nil)
        libvlc_media_player_release(player)
        libvlc_release(instance)
    }
}
