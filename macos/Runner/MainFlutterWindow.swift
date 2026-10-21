import Cocoa
import AVFoundation
import FlutterMacOS
import Vision
import ImageIO

class MainFlutterWindow: NSWindow {
  private var accessedFolders: [URL] = []
  private var readerAnalysisChannel: FlutterMethodChannel?
  deinit { for url in accessedFolders { url.stopAccessingSecurityScopedResource() } }
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    readerAnalysisChannel = ReaderRasterAnalysis.register(with: flutterViewController.engine.binaryMessenger)
    MyVLCBridge.register(with: flutterViewController.registrar(forPlugin: "MyVLCBridge"))

    let channel = FlutterMethodChannel(name: "studystream/folder_access", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(nil) }
      do {
        if call.method == "allocatedSizes", let arguments = call.arguments as? [String: Any],
           let paths = arguments["paths"] as? [String], paths.count <= 512 {
          DispatchQueue.global(qos: .utility).async {
            var sizes: [String: Int] = [:]
            for path in paths where path.hasPrefix("/") {
              if let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]),
                 values.isRegularFile == true, let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                sizes[path] = size
              }
            }
            DispatchQueue.main.async { result(sizes) }
          }
        } else if call.method == "thumbnail", let arguments = call.arguments as? [String: String], let path = arguments["path"], let output = arguments["output"] {
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

// Independent on-device OCR capability. No file paths or PDF native text ranges
// cross this channel: the caller supplies a bounded upright raster.
private enum ReaderRasterAnalysis {
  static func register(with messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: "tangerine/reader_analysis", binaryMessenger: messenger)
    var requests: [String: VNRecognizeTextRequest] = [:]
    var cancelled = Set<String>()
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any], let id = args["id"] as? String, id.count <= 64 else {
        result(FlutterError(code: "INPUT", message: "Invalid analysis request.", details: nil)); return
      }
      if call.method == "cancel" {
        if let request = requests[id] { cancelled.insert(id); request.cancel() }
        result(nil); return
      }
      guard call.method == "recognize" else { result(FlutterMethodNotImplemented); return }
      guard requests.isEmpty else {
        result(FlutterError(code: "BUSY", message: "Another page is being recognized. Try again shortly.", details: nil)); return
      }
      guard let input = args["png"] as? FlutterStandardTypedData, input.data.count <= 20 * 1024 * 1024 else {
        result(FlutterError(code: "INPUT", message: "The analysis image exceeds its input limit.", details: nil)); return
      }
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      if #available(macOS 13.0, *) { request.automaticallyDetectsLanguage = true }
      requests[id] = request
      DispatchQueue.global(qos: .userInitiated).async {
        let outcome: Result<[[String: Any]], Error> = Result {
          try autoreleasepool {
            guard let source = CGImageSourceCreateWithData(input.data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.intValue > 0, height.intValue > 0,
              width.intValue <= 8192, height.intValue <= 8192,
              width.intValue * height.intValue <= 4 * 1024 * 1024,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw NSError(domain: "ReaderAnalysis", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid analysis raster."])
            }
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            var lines: [[String: Any]] = [], characters = 0
            for observation in (request.results ?? []).prefix(500) {
              guard let candidate = observation.topCandidates(1).first else { continue }
              var text = "", units = 0
              for scalar in candidate.string.unicodeScalars {
                let size = scalar.value > 0xffff ? 2 : 1
                if units + size > 2000 { break }
                text.unicodeScalars.append(scalar); units += size
              }
              if characters + text.utf16.count > 16000 { break }
              characters += text.utf16.count
              let box = observation.boundingBox
              lines.append(["text": text, "confidence": Double(candidate.confidence),
                "x": box.minX, "y": max(0, 1 - box.maxY), "width": box.width, "height": box.height])
            }
            return lines
          }
        }
        DispatchQueue.main.async {
          requests.removeValue(forKey: id)
          if cancelled.remove(id) != nil {
            result(FlutterError(code: "CANCELLED", message: "Text recognition cancelled.", details: nil)); return
          }
          switch outcome {
          case .success(let lines): result(lines)
          case .failure: result(FlutterError(code: "ANALYSIS", message: "Text could not be recognized on this page.", details: nil))
          }
        }
      }
    }
    return channel
  }
}
