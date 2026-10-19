import Foundation

struct MediaItem: Identifiable, Codable, Equatable {
    var id: String { url.absoluteString }
    let url: URL
    var lastPlayed: Date?
    var resumeTime: Int64 = 0
    var subtitleURL: URL?
    var title: String {
        url.isFileURL ? url.lastPathComponent : (url.host ?? url.absoluteString) + url.path
    }
    var isAudio: Bool { Self.audioExtensions.contains(url.pathExtension.lowercased()) }
    static let audioExtensions: Set<String> = ["mp3", "flac", "wav", "aac", "m4a", "ogg", "opus", "aiff", "wma", "alac"]
    static let mediaExtensions = audioExtensions.union(["mp4", "mkv", "avi", "mov", "webm", "m4v", "mpeg", "mpg", "ts", "m2ts", "ogv", "3gp", "vob"])

    static func streamURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "rtsp", "rtmp", "rtp", "udp", "srt"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }
}

enum RepeatMode: String, Codable, CaseIterable {
    case off, all, one
    var label: String { switch self { case .off: return "Off"; case .all: return "All"; case .one: return "One" } }
}

enum QueueNavigation {
    static func nextIndex(current: Int, count: Int, direction: Int = 1, repeatMode: RepeatMode,
                          automatic: Bool = false) -> Int? {
        guard count > 0, current >= 0, current < count else { return nil }
        if automatic && repeatMode == .one { return current }
        let next = current + direction
        if (0..<count).contains(next) { return next }
        if repeatMode == .all { return (next + count) % count }
        return nil
    }
}

struct LibrarySnapshot: Codable {
    var items: [MediaItem] = []
    var queue: [String] = []
    var playlists: [NamedPlaylist] = []
    var folders: [URL] = []

    enum CodingKeys: String, CodingKey { case items, queue, playlists, folders }
    init(items: [MediaItem] = [], queue: [String] = [], playlists: [NamedPlaylist] = [], folders: [URL] = []) {
        self.items = items; self.queue = queue; self.playlists = playlists; self.folders = folders
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([MediaItem].self, forKey: .items) ?? []
        queue = try c.decodeIfPresent([String].self, forKey: .queue) ?? []
        playlists = try c.decodeIfPresent([NamedPlaylist].self, forKey: .playlists) ?? []
        folders = try c.decodeIfPresent([URL].self, forKey: .folders) ?? []
    }
}

struct NamedPlaylist: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var mediaIDs: [String]
    var artwork: Data?
    var createdAt = Date()
}

struct PlayerProfile: Identifiable, Codable {
    var id = UUID()
    var name: String
    var preferences: PlayerPreferences
    var equalizer: EqualizerSettings
}

struct EqualizerSettings: Codable, Equatable {
    var enabled = false
    var preset: UInt32 = 0
    var preamp: Float = 0
    var bands: [Float] = Array(repeating: 0, count: 10)
}

enum PlaylistFile {
    static func read(_ url: URL) throws -> [URL] {
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines: [String]
        if url.pathExtension.lowercased() == "pls" {
            lines = text.components(separatedBy: .newlines).filter { $0.lowercased().hasPrefix("file") }.compactMap { $0.split(separator: "=", maxSplits: 1).last.map(String.init) }
        } else { lines = text.components(separatedBy: .newlines).filter { !$0.hasPrefix("#") } }
        return lines.compactMap { line in
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            if let url = URL(string: text), url.scheme != nil { return url }
            return URL(fileURLWithPath: text, relativeTo: url.deletingLastPathComponent()).standardizedFileURL
        }
    }
    static func write(_ items: [MediaItem], to url: URL) throws {
        let contents = "#EXTM3U\n" + items.map { "#EXTINF:-1,\($0.title)\n\($0.url.isFileURL ? $0.url.path : $0.url.absoluteString)" }.joined(separator: "\n") + "\n"
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct LibraryStore {
    let url: URL
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyPlayer/library.json")
    }
    func load() -> LibrarySnapshot {
        guard let data = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(LibrarySnapshot.self, from: data) else {
            return LibrarySnapshot()
        }
        return snapshot
    }
    func save(_ snapshot: LibrarySnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
}
