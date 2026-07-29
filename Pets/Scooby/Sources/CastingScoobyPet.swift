import AppKit
import AVFoundation
import AVKit
import DeviceDiscovery
import PetCore
import SharedUI
import SwiftUI

/// 🐶 A local-media casting companion for DLNA and AirPlay devices.
@MainActor
public final class CastingScoobyPet: PetPlugin {
    public let id = "scooby"
    public let displayName = "Casting Scooby"
    public let icon = "🐶"
    public let tagline = "Cast local media to your TV"
    private let model = ScoobyViewModel()
    public init() {}
    public func start() async {
        model.discoverDevices()
    }
    public func stop() async {}
    public func commands() -> [PetCommand] { [PetCommand(id: "discover-devices", title: "Find TVs", systemImage: "tv")] }
    public func makeView() -> AnyView { AnyView(ScoobyHomeView(model: model)) }
    public func open(fileURL: URL) { model.enqueue(fileURL) }
}

@MainActor
public final class ScoobyViewModel: ObservableObject {
    @Published public var devices: [MediaDevice] = []
    @Published public var selectedDeviceID: String?
    @Published public var selectedFileURL: URL? {
        didSet { updateLocalPreviewPlayer() }
    }
    @Published public var queue: [URL] = []
    @Published public var subtitles: [URL: URL] = [:]
    @Published public var selectedAudioTrackName: String?
    @Published public var seekSeconds = 0
    @Published public var totalDurationSeconds = 0
    @Published public var isEditingSeek = false
    @Published public var isDiscovering = false
    @Published public var isCasting = false
    @Published public var isPaused = false
    @Published public var isPreviewEnabled = true {
        didSet { updatePreviewState() }
    }
    @Published public var errorMessage: String?
    @Published public var localPlayer: AVPlayer?
    private var controller: DLNAController?
    private var mediaServer: MediaStreamServer?
    private var positionTimer: Timer?

    public init() {
        discoverDevices()
    }

    public func discoverDevices() {
        guard !isDiscovering else { return }
        isDiscovering = true
        errorMessage = nil
        Task {
            let foundDevices = await SSDPDeviceDiscovery().scan()
            devices = foundDevices
            selectedDeviceID = selectedDeviceID ?? foundDevices.first?.id
            isDiscovering = false
            if foundDevices.isEmpty { errorMessage = "No DLNA TVs found on your local network." }
        }
    }

    public func chooseMediaFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .audio]
        if panel.runModal() == .OK { panel.urls.forEach(enqueue) }
    }

    public func enqueue(_ fileURL: URL) {
        guard !queue.contains(fileURL) else { return }
        queue.append(fileURL)
        selectedFileURL = selectedFileURL ?? fileURL
        autoDetectSubtitle(for: fileURL)
    }

    public func removeFromQueue(_ fileURL: URL) {
        queue.removeAll { $0 == fileURL }
        subtitles.removeValue(forKey: fileURL)
        if selectedFileURL == fileURL { selectedFileURL = queue.first }
    }

    public func chooseSubtitle(for fileURL: URL) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "srt")!, .init(filenameExtension: "vtt")!]
        if panel.runModal() == .OK, let subtitleURL = panel.url {
            subtitles[fileURL] = subtitleURL
        }
    }

    public func removeSubtitle(for fileURL: URL) {
        subtitles.removeValue(forKey: fileURL)
    }

    private func autoDetectSubtitle(for fileURL: URL) {
        let base = fileURL.deletingPathExtension()
        for ext in ["srt", "vtt"] {
            let candidate = base.appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: candidate.path) {
                subtitles[fileURL] = candidate
                break
            }
        }
    }

    public func cast() {
        guard let fileURL = selectedFileURL,
              let device = devices.first(where: { $0.id == selectedDeviceID }) else {
            errorMessage = "Choose a TV and a media file first."
            return
        }
        guard let address = NetworkAddress.localIPv4Address() else {
            errorMessage = "Scooby could not find this Mac’s local network address."
            return
        }
        errorMessage = nil
        Task {
            do {
                mediaServer?.stop()
                stopPositionPolling()
                let server = MediaStreamServer(fileURL: fileURL)
                try server.start()
                let newController = DLNAController(device: device)
                let streamURL = URL(string: "http://\(address):8888/stream")!
                try await newController.play(mediaURL: streamURL, title: fileURL.lastPathComponent, mimeType: mimeType(for: fileURL))
                mediaServer = server
                controller = newController
                isCasting = true
                isPaused = false
                updatePreviewState()
                startPositionPolling()
            } catch {
                mediaServer?.stop()
                errorMessage = error.localizedDescription
            }
        }
    }

    public func togglePlayback() {
        guard let controller else { return }
        let shouldResume = isPaused
        // Immediately flip UI state so button responds instantly
        isPaused = !shouldResume
        if isPreviewEnabled {
            if shouldResume { localPlayer?.play() } else { localPlayer?.pause() }
        }
        
        Task {
            do {
                if shouldResume {
                    try await controller.resume()
                    // Check if TV renderer requires seek fallback to unfreeze
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if let state = try? await controller.getTransportInfo(), state == "PAUSED_PLAYBACK" {
                        let currentSeek = seekSeconds
                        try? await controller.seek(to: currentSeek)
                        try? await controller.resume()
                    }
                } else {
                    try await controller.pause()
                }
            } catch {
                isPaused = shouldResume
                errorMessage = error.localizedDescription
            }
        }
    }

    public func stopCasting() {
        stopPositionPolling()
        localPlayer?.pause()
        guard let controller else {
            mediaServer?.stop()
            mediaServer = nil
            isCasting = false
            isPaused = false
            return
        }
        Task {
            do { try await controller.stop() } catch { errorMessage = error.localizedDescription }
            mediaServer?.stop()
            mediaServer = nil
            self.controller = nil
            isCasting = false
            isPaused = false
        }
    }

    public func seek(to seconds: Int? = nil) {
        let target = seconds ?? seekSeconds
        seekSeconds = target
        let targetTime = CMTime(seconds: Double(target), preferredTimescale: 600)
        localPlayer?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in }
        guard let controller else { return }
        let wasPlaying = !isPaused
        Task {
            do {
                try await controller.seek(to: target)
                // If TV was playing before seek, ensure play is dispatched so TV doesn't get stuck in PAUSED_PLAYBACK
                if wasPlaying {
                    try? await controller.resume()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func skipForward(seconds: Int = 10) {
        let target = max(0, seekSeconds + seconds)
        seek(to: target)
    }

    public func rewind(seconds: Int = 10) {
        let target = max(0, seekSeconds - seconds)
        seek(to: target)
    }

    private func updateLocalPreviewPlayer() {
        guard let fileURL = selectedFileURL else {
            localPlayer = nil
            totalDurationSeconds = 0
            return
        }
        let asset = AVURLAsset(url: fileURL)
        Task { @MainActor [weak self] in
            if let duration = try? await asset.load(.duration) {
                let secs = Int(duration.seconds)
                if secs > 0 {
                    self?.totalDurationSeconds = secs
                }
            }
        }
        let player = AVPlayer(url: fileURL)
        player.isMuted = true
        localPlayer = player
        updatePreviewState()
    }

    private func updatePreviewState() {
        guard let player = localPlayer else { return }
        if isCasting && isPreviewEnabled && !isPaused {
            player.play()
        } else {
            player.pause()
        }
    }

    private func startPositionPolling() {
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let controller = self.controller, self.isCasting, !self.isEditingSeek else { return }
                
                // Sync playback state from TV remote
                if let transportState = try? await controller.getTransportInfo() {
                    switch transportState {
                    case "PLAYING", "TRANSITIONING":
                        if self.isPaused {
                            self.isPaused = false
                            if self.isPreviewEnabled { self.localPlayer?.play() }
                        }
                    case "PAUSED_PLAYBACK":
                        if !self.isPaused {
                            self.isPaused = true
                            self.localPlayer?.pause()
                        }
                    default:
                        break
                    }
                }

                if let info = try? await controller.getPositionInfo() {
                    if info.relTime > 0 || info.duration > 0 {
                        self.seekSeconds = info.relTime
                        if info.duration > 0 { self.totalDurationSeconds = info.duration }
                        
                        // Sync local preview frame if drift exceeds 2 seconds
                        if let player = self.localPlayer, self.isPreviewEnabled {
                            let currentLocal = Int(player.currentTime().seconds)
                            if abs(currentLocal - info.relTime) > 2 {
                                player.seek(to: CMTime(seconds: Double(info.relTime), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { _ in }
                            }
                        }
                    }
                }
            }
        }
    }

    private func stopPositionPolling() {
        positionTimer?.invalidate()
        positionTimer = nil
    }

    public func playNext() {
        guard let current = selectedFileURL, let index = queue.firstIndex(of: current), queue.indices.contains(index + 1) else { return }
        stopCasting()
        selectedFileURL = queue[index + 1]
        cast()
    }

    public func playPrevious() {
        guard let current = selectedFileURL, let index = queue.firstIndex(of: current), queue.indices.contains(index - 1) else { return }
        stopCasting()
        selectedFileURL = queue[index - 1]
        cast()
    }

    private func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "mp4", "m4v": "video/mp4"
        case "mov": "video/quicktime"
        case "mkv": "video/x-matroska"
        case "mp3": "audio/mpeg"
        default: "application/octet-stream"
        }
    }
}

private struct ScoobyHomeView: View {
    @ObservedObject var model: ScoobyViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Header Bar
            HStack(spacing: 12) {
                Text("🐶").font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Casting Scooby").font(.title2.bold())
                    Text("Local-media TV casting companion").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { model.discoverDevices() }) {
                    Label(model.isDiscovering ? "Searching…" : "Scan TVs", systemImage: "arrow.clockwise")
                }
                .disabled(model.isDiscovering)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if let error = model.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }

            // Main Grid Layout (No Scrolling)
            HStack(alignment: .top, spacing: 16) {
                // Left Column: INPUT (Media Queue & Subtitle attachments)
                VStack(spacing: 14) {
                    PetCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("INPUT MEDIA", systemImage: "tray.and.arrow.down.fill").font(.caption.bold()).foregroundStyle(.secondary)
                                Spacer()
                            }
                            
                            HStack {
                                Label("Media Queue", systemImage: "film").font(.headline)
                                Spacer()
                                Button("Add Media…") { model.chooseMediaFile() }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            }

                            if model.queue.isEmpty {
                                Text("No files in queue. Click 'Add Media' to choose video/audio files.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                            } else {
                                VStack(spacing: 6) {
                                    ForEach(model.queue, id: \.self) { file in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: model.selectedFileURL == file ? "play.circle.fill" : "doc")
                                                    .foregroundStyle(model.selectedFileURL == file ? Color.accentColor : Color.secondary)
                                                
                                                Text(file.lastPathComponent)
                                                    .font(.body.weight(model.selectedFileURL == file ? .medium : .regular))
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                Button(action: { model.removeFromQueue(file) }) {
                                                    Image(systemName: "trash").foregroundStyle(.secondary)
                                                }
                                                .buttonStyle(.plain)
                                                .help("Remove file from queue")
                                            }

                                            // Per-item subtitle attachment row
                                            HStack {
                                                if let subtitle = model.subtitles[file] {
                                                    Label(subtitle.lastPathComponent, systemImage: "captions.bubble.fill")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: { model.removeSubtitle(for: file) }) {
                                                        Image(systemName: "xmark.circle").font(.caption).foregroundStyle(.secondary)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("Remove subtitle")
                                                } else {
                                                    Button(action: { model.chooseSubtitle(for: file) }) {
                                                        Label("Add Subtitle (.srt/.vtt)", systemImage: "captions.bubble")
                                                            .font(.caption)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .foregroundStyle(Color.accentColor)
                                                }
                                            }
                                            .padding(.leading, 20)
                                        }
                                        .padding(8)
                                        .background(model.selectedFileURL == file ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                                        .cornerRadius(6)
                                        .onTapGesture {
                                            model.selectedFileURL = file
                                        }
                                    }
                                }
                            }
                        }
                        .padding(4)
                    }
                }
                .frame(maxWidth: .infinity)

                // Right Column: OUTPUT (Merged TV Selector & Player Controls)
                VStack(spacing: 14) {
                    PetCard {
                        VStack(spacing: 14) {
                            // Unified Output & Control Header
                            HStack(spacing: 10) {
                                Label("Output", systemImage: "tv").font(.headline)

                                if model.devices.isEmpty {
                                    Text("No TVs found")
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Picker("Device", selection: $model.selectedDeviceID) {
                                        ForEach(model.devices) { device in
                                            Text(device.name).tag(Optional(device.id))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .controlSize(.small)
                                }

                                Spacer()

                                Button(action: { model.isPreviewEnabled.toggle() }) {
                                    Image(systemName: model.isPreviewEnabled ? "eye.fill" : "eye.slash")
                                        .font(.subheadline)
                                        .foregroundStyle(model.isPreviewEnabled ? Color.accentColor : Color.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(model.isPreviewEnabled ? "Hide mini video preview" : "Show mini video preview")
                                
                                if model.isCasting {
                                    Button("Stop", role: .destructive) { model.stopCasting() }
                                        .controlSize(.small)
                                }
                            }

                            Divider()

                            // Optional Mini Video Player Preview Screen
                            if model.isPreviewEnabled, let player = model.localPlayer {
                                ScoobyMiniPlayerView(player: player)
                                    .frame(height: 140)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                            }

                            // Now Playing Title
                            VStack(spacing: 2) {
                                Text(model.selectedFileURL?.lastPathComponent ?? "No Media Selected")
                                    .font(.title3.bold())
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }

                            // Scrubber / Seek Control
                            VStack(spacing: 4) {
                                HStack {
                                    Text("\(formatTime(model.seekSeconds))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    Slider(
                                        value: Binding(
                                            get: { Double(model.seekSeconds) },
                                            set: { model.seekSeconds = Int($0) }
                                        ),
                                        in: 0...Double(max(1, model.totalDurationSeconds > 0 ? model.totalDurationSeconds : 7200)),
                                        onEditingChanged: { editing in
                                            model.isEditingSeek = editing
                                            if !editing {
                                                model.seek()
                                            }
                                        }
                                    )
                                    .disabled(!model.isCasting)
                                    
                                    Text(model.totalDurationSeconds > 0 ? formatTime(model.totalDurationSeconds) : "--:--")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Full Player Buttons Bar
                            HStack(spacing: 14) {
                                Button(action: { model.playPrevious() }) {
                                    Image(systemName: "backward.end.fill").font(.title2)
                                }
                                .disabled(model.queue.isEmpty || model.selectedFileURL == model.queue.first)

                                Button(action: { model.rewind(seconds: 10) }) {
                                    Image(systemName: "gobackward.10").font(.title2)
                                }
                                .disabled(!model.isCasting)

                                if model.isCasting {
                                    Button(action: { model.togglePlayback() }) {
                                        Image(systemName: model.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                            .font(.system(size: 44))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: { model.cast() }) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 44))
                                            .foregroundStyle(model.selectedDeviceID == nil || model.selectedFileURL == nil ? Color.gray : Color.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(model.selectedDeviceID == nil || model.selectedFileURL == nil)
                                }

                                Button(action: { model.skipForward(seconds: 10) }) {
                                    Image(systemName: "goforward.10").font(.title2)
                                }
                                .disabled(!model.isCasting)

                                Button(action: { model.playNext() }) {
                                    Image(systemName: "forward.end.fill").font(.title2)
                                }
                                .disabled(model.queue.isEmpty || model.selectedFileURL == model.queue.last)
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(6)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Casting Scooby")
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

private struct ScoobyMiniPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player != player {
            nsView.player = player
        }
    }
}
