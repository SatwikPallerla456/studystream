import AppKit
@preconcurrency import AVFoundation
import SwiftUI
import WebKit
import CLibVLC

/// Retains the original AVFoundation capture ownership: one session, a serial
/// capture queue, explicit permission prompts, and stop on window close.
@MainActor final class TangerineCapture: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate, NSWindowDelegate {
    let session = AVCaptureSession()
    let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "tangerine.capture")
    @Published var running = false
    @Published var recording = false
    @Published var busy = false
    @Published var message = "Choose camera, microphone, or both. Access is requested when you start."
    private var generation=0
    var window: NSWindow?
    func show() {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let panel = NSWindow(contentRect: NSRect(x:0,y:0,width:720,height:560), styleMask:[.titled,.closable,.resizable], backing:.buffered, defer:false)
        panel.title = "Tangerine · Camera and microphone"; panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView:TangerineCaptureView(capture:self))
        panel.delegate = self; window = panel; panel.center(); panel.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { stop(); window = nil }
    func start(videoID: String, audioID: String) async {
        guard !busy, !recording else { return }
        busy = true; defer { busy = false }
        generation += 1; let token=generation
        if !videoID.isEmpty, !(await AVCaptureDevice.requestAccess(for:.video)) { message="Camera access denied. Enable Tangerine in System Settings → Privacy & Security → Camera."; return }
        if !audioID.isEmpty, !(await AVCaptureDevice.requestAccess(for:.audio)) { message="Microphone access denied. Enable Tangerine in System Settings → Privacy & Security → Microphone."; return }
        guard generation==token,window != nil else { return }
        let session=session, output=output
        let failure: String? = await withCheckedContinuation { continuation in
            queue.async {
                if session.isRunning { session.stopRunning() }
                session.beginConfiguration()
                do {
                    for input in session.inputs { session.removeInput(input) }
                    for (id, type) in [(videoID, AVMediaType.video),(audioID, AVMediaType.audio)] where !id.isEmpty {
                        guard let device=AVCaptureDevice.devices(for:type).first(where:{$0.uniqueID == id}) else { throw PlayerError.media }
                        let input=try AVCaptureDeviceInput(device:device)
                        guard session.canAddInput(input) else { throw PlayerError.media }
                        session.addInput(input)
                    }
                    guard !session.inputs.isEmpty else { throw PlayerError.media }
                    if !session.outputs.contains(output) {
                        guard session.canAddOutput(output) else { throw PlayerError.media }; session.addOutput(output)
                    }
                    session.commitConfiguration(); session.startRunning()
                    continuation.resume(returning:session.isRunning ? nil : "Capture could not start. Check the device connection or another app using it.")
                } catch { session.commitConfiguration(); continuation.resume(returning:"Capture device unavailable. Reconnect it and choose the device again.") }
            }
        }
        guard generation==token else {stop();return}
        running=failure == nil; message=failure ?? (videoID.isEmpty ? "Microphone active · ready to record" : "Preview active · ready to record")
    }
    func record() {
        guard running, !busy else { return }
        if recording { output.stopRecording(); return }
        let panel=NSSavePanel(); panel.nameFieldStringValue="Tangerine-Capture-\(Int(Date().timeIntervalSince1970)).mov";panel.allowedFileTypes=["mov"]
        guard panel.runModal() == .OK, let url=panel.url else { return }
        output.startRecording(to:url, recordingDelegate:self); recording=true; message="Recording… Stop to finalize the file."
    }
    func stop() {
        generation += 1
        if output.isRecording { output.stopRecording() }
        queue.async { [session] in if session.isRunning { session.stopRunning() } }
        running=false; message="Capture stopped"
    }
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections:[AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            self.recording=false
            let saved = error == nil || ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true)
            self.message=saved ? "Saved \(url.lastPathComponent). Add its folder to a library to scan it." : "Recording could not finish. Check available storage and file permission."
            if saved { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
    }
}
private final class TangerineCaptureHost: NSView {
    var preview: AVCaptureVideoPreviewLayer?
    override func layout() { super.layout();preview?.frame=bounds }
}
private struct TangerineCapturePreview: NSViewRepresentable {
    let session:AVCaptureSession
    func makeNSView(context:Context)->NSView {
        let view=TangerineCaptureHost();view.wantsLayer=true
        let preview=AVCaptureVideoPreviewLayer(session:session);preview.videoGravity = .resizeAspect
        view.layer?.addSublayer(preview);view.preview=preview;return view
    }
    func updateNSView(_ view:NSView,context:Context) {}
}
private struct TangerineCaptureView: View {
    @ObservedObject var capture:TangerineCapture
    @State var camera=""
    @State var microphone=""
    @State var cameras:[AVCaptureDevice]=[]
    @State var microphones:[AVCaptureDevice]=[]
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Camera and microphone").font(.title2)
            Picker("Camera",selection:$camera) { Text("None").tag("");ForEach(cameras,id:\.uniqueID){Text($0.localizedName).tag($0.uniqueID)} }
            Picker("Microphone",selection:$microphone) { Text("None").tag("");ForEach(microphones,id:\.uniqueID){Text($0.localizedName).tag($0.uniqueID)} }
            Button("Refresh devices") { refresh() }.disabled(capture.running || capture.busy)
            TangerineCapturePreview(session:capture.session).frame(minHeight:240).background(.black)
            Text(capture.message).font(.caption)
            HStack {
                Button("Start preview") { Task { await capture.start(videoID:camera,audioID:microphone) } }.disabled(capture.busy || capture.recording || camera.isEmpty && microphone.isEmpty)
                Button(capture.recording ? "Stop recording" : "Record…") { capture.record() }.disabled(!capture.running)
                Button("Stop capture") { capture.stop() }.disabled(!capture.running || capture.busy)
                Spacer();Button("Close") { capture.window?.close() }.disabled(capture.busy)
            }
        }.padding(24).onAppear{refresh()}
    }
    func refresh(){cameras=AVCaptureDevice.devices(for:.video);microphones=AVCaptureDevice.devices(for:.audio)}
}

/// JavaScript executes in a disposable Web Worker. The worker has no native,
/// filesystem, shell or network bridge. A watchdog terminates it after 2 seconds.
@MainActor final class TangerineAddonRunner: NSObject, WKNavigationDelegate {
    private var web:WKWebView?
    private var completion:(([[String:Any]]?,String?)->Void)?
    private var source="", title=""
    private var position=0.0
    private var watchdog:DispatchWorkItem?
    func run(source:String,title:String,position:Double,completion:@escaping ([[String:Any]]?,String?)->Void) {
        self.source=source;self.title=title;self.position=position;self.completion=completion
        let config=WKWebViewConfiguration();config.websiteDataStore = .nonPersistent()
        let web=WKWebView(frame:.zero,configuration:config);self.web=web;web.navigationDelegate=self
        let timeout=DispatchWorkItem{[weak self] in self?.finish(nil,"Add-on timed out after 3 seconds.")};watchdog=timeout
        DispatchQueue.main.asyncAfter(deadline:.now()+3,execute:timeout)
        web.loadHTMLString("<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval'; worker-src blob:; connect-src 'none'\">",baseURL:nil)
    }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
        let script="""
        return await new Promise((resolve,reject)=>{
          const boot = `const commands=[]; const title=${JSON.stringify(title)}; const position=${JSON.stringify(position)};
          const push=(action,value)=>{if(commands.length>=64)throw Error('Too many commands');commands.push({action,value});};
          const player=Object.freeze({title,position,play:()=>push('play',0),pause:()=>push('pause',0),stop:()=>push('stop',0),seek:v=>push('seek',v),setVolume:v=>push('volume',v)});
          try { ${source} ; if(typeof onPlay==='function')onPlay(title); postMessage({commands}); } catch(e){postMessage({error:String(e).slice(0,256)});}`;
          const url=URL.createObjectURL(new Blob([boot],{type:'text/javascript'}));
          const worker=new Worker(url);const timer=setTimeout(()=>{worker.terminate();URL.revokeObjectURL(url);reject(Error('Add-on timed out'));},2000);
          const end=()=>{clearTimeout(timer);worker.terminate();URL.revokeObjectURL(url);};
          worker.onmessage=e=>{end();resolve(e.data);};worker.onerror=()=>{end();reject(Error('Add-on execution failed'));};
        });
        """
        webView.callAsyncJavaScript(script,arguments:["source":source,"title":title,"position":position],in:nil,in:.page){[weak self] result in
            switch result {
            case .success(let value):
                let data=value as? [String:Any];self?.finish(data?["commands"] as? [[String:Any]],data?["error"] as? String)
            case .failure: self?.finish(nil,"Add-on execution failed or timed out.")
            }
        }
    }
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error){finish(nil,"Add-on sandbox could not start.")}
    private func finish(_ commands:[[String:Any]]?,_ error:String?) {
        guard let completion else{return};self.completion=nil;watchdog?.cancel();web?.stopLoading();web?.navigationDelegate=nil;web=nil
        completion(commands,error)
    }
}
