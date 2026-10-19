import Cocoa
import AVFoundation
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var accessedFolders: [URL] = []
  deinit { for url in accessedFolders { url.stopAccessingSecurityScopedResource() } }
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MyVLCBridge.register(with: flutterViewController.registrar(forPlugin: "MyVLCBridge"))

    let channel = FlutterMethodChannel(name: "studystream/folder_access", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(nil) }
      do {
        if call.method == "thumbnail", let arguments = call.arguments as? [String: String], let path = arguments["path"], let output = arguments["output"] {
          DispatchQueue.global(qos: .utility).async {
            do {
              let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: path)))
              generator.appliesPreferredTrackTransform = true
              generator.maximumSize = CGSize(width: 320, height: 240)
              let image = try generator.copyCGImage(at: .zero, actualTime: nil)
              let bitmap = NSBitmapImageRep(cgImage: image)
              let data = bitmap.representation(using: .png, properties: [:])
              try data?.write(to: URL(fileURLWithPath: output), options: .atomic)
              DispatchQueue.main.async { result(data == nil ? nil : output) }
            } catch { DispatchQueue.main.async { result(nil) } }
          }
        } else if call.method == "retain", let arguments = call.arguments as? [String: Any], let path = arguments["path"] as? String {
          let url = URL(fileURLWithPath: path)
          let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
          var bookmarks = UserDefaults.standard.dictionary(forKey: "StudyStream.folderBookmarks") as? [String: Data] ?? [:]
          bookmarks[path] = data
          UserDefaults.standard.set(bookmarks, forKey: "StudyStream.folderBookmarks")
          if url.startAccessingSecurityScopedResource() { self.accessedFolders.append(url) }
          result(nil)
        } else if call.method == "restore" {
          var bookmarks = UserDefaults.standard.dictionary(forKey: "StudyStream.folderBookmarks") as? [String: Data] ?? [:]
          for (path, data) in bookmarks {
            do {
              var stale = false
              let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
              if url.startAccessingSecurityScopedResource() { self.accessedFolders.append(url) }
              if stale { bookmarks[path] = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) }
            } catch { /* Keep the bookmark: an unavailable volume can return later. */ }
          }
          UserDefaults.standard.set(bookmarks, forKey: "StudyStream.folderBookmarks")
          result(nil)
        } else { result(FlutterMethodNotImplemented) }
      } catch { result(FlutterError(code: "FOLDER_ACCESS", message: "Folder permission could not be retained. Select the folder again.", details: nil)) }
    }

    super.awakeFromNib()
  }
}
