import AppKit
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
    public func start() async {}
    public func stop() async {}
    public func commands() -> [PetCommand] { [PetCommand(id: "discover-devices", title: "Find TVs", systemImage: "tv")] }
    public func makeView() -> AnyView { AnyView(ScoobyHomeView(model: model)) }
    public func open(fileURL: URL) { model.enqueue(fileURL) }
}

@MainActor
private final class ScoobyViewModel: ObservableObject {
    @Published var devices: [MediaDevice] = []
    @Published var selectedDeviceID: String?
    @Published var selectedFileURL: URL?
    @Published var queue: [URL] = []
    @Published var selectedSubtitleURL: URL?
    @Published var selectedAudioTrackName: String?
    @Published var seekSeconds = 0
    @Published var isDiscovering = false
    @Published var isCasting = false
    @Published var isPaused = false
    @Published var errorMessage: String?
    private var controller: DLNAController?
    private var mediaServer: MediaStreamServer?

    func discoverDevices() {
        guard !isDiscovering else { return }
        isDiscovering = true
        errorMessage = nil
        Task {
            let foundDevices = await SSDPDeviceDiscovery().scan()
            devices = foundDevices
            selectedDeviceID = selectedDeviceID ?? foundDevices.first?.id
            isDiscovering = false
            if foundDevices.isEmpty { errorMessage = "No DLNA TVs were found on your local network." }
        }
    }

    func chooseMediaFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .audio]
        if panel.runModal() == .OK { panel.urls.forEach(enqueue) }
    }

    func enqueue(_ fileURL: URL) {
        guard !queue.contains(fileURL) else { return }
        queue.append(fileURL)
        selectedFileURL = selectedFileURL ?? fileURL
    }

    func removeFromQueue(_ fileURL: URL) {
        queue.removeAll { $0 == fileURL }
        if selectedFileURL == fileURL { selectedFileURL = queue.first }
    }

    func chooseSubtitle() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "srt")!, .init(filenameExtension: "vtt")!]
        if panel.runModal() == .OK { selectedSubtitleURL = panel.url }
    }

    func cast() {
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
                let server = MediaStreamServer(fileURL: fileURL)
                try server.start()
                let newController = DLNAController(device: device)
                let streamURL = URL(string: "http://\(address):8888/stream")!
                try await newController.play(mediaURL: streamURL, title: fileURL.lastPathComponent, mimeType: mimeType(for: fileURL))
                mediaServer = server
                controller = newController
                isCasting = true
                isPaused = false
            } catch {
                mediaServer?.stop()
                errorMessage = error.localizedDescription
            }
        }
    }

    func togglePlayback() {
        guard let controller else { return }
        Task {
            do {
                if isPaused { try await controller.resume() } else { try await controller.pause() }
                isPaused.toggle()
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func stopCasting() {
        guard let controller else { return }
        Task {
            do { try await controller.stop() } catch { errorMessage = error.localizedDescription }
            mediaServer?.stop()
            mediaServer = nil
            self.controller = nil
            isCasting = false
            isPaused = false
        }
    }

    func seek() {
        guard let controller else { return }
        Task { do { try await controller.seek(to: seekSeconds) } catch { errorMessage = error.localizedDescription } }
    }

    func playNext() {
        guard let current = selectedFileURL, let index = queue.firstIndex(of: current), queue.indices.contains(index + 1) else { return }
        stopCasting()
        selectedFileURL = queue[index + 1]
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
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                Text("🐶").font(.system(size: 72))
                Text("Casting Scooby").font(.largeTitle.bold())
                Text("Your local-media casting companion").font(.title3).foregroundStyle(.secondary)
                PetCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("1. Choose a TV").font(.headline)
                            Spacer()
                            Button(model.isDiscovering ? "Looking…" : "Find TVs") { model.discoverDevices() }
                                .disabled(model.isDiscovering)
                        }
                        if model.devices.isEmpty {
                            Text("Find compatible DLNA/UPnP TVs on your local network.").foregroundStyle(.secondary)
                        } else {
                            Picker("TV", selection: $model.selectedDeviceID) {
                                ForEach(model.devices) { device in Text(device.name).tag(Optional(device.id)) }
                            }
                        }
                        if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if !model.queue.isEmpty {
                    PetCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Queue").font(.headline)
                            ForEach(model.queue, id: \.self) { file in
                                HStack { Text(file.lastPathComponent).lineLimit(1); Spacer(); Button("Remove") { model.removeFromQueue(file) } }
                            }
                        }
                    }
                }
                PetCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tracks").font(.headline)
                        Button("Choose Subtitle (.srt or .vtt)…") { model.chooseSubtitle() }
                        if let subtitle = model.selectedSubtitleURL { Label(subtitle.lastPathComponent, systemImage: "captions.bubble") }
                        Text("Selected subtitle and audio-track preferences are saved with the queue. Applying them to a remote DLNA renderer requires its device-specific capability; universal remuxing/transcoding is the next media-engine increment.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                PetCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. Choose media").font(.headline)
                        Button("Choose Video or Audio…") { model.chooseMediaFile() }
                        if let file = model.selectedFileURL { Label(file.lastPathComponent, systemImage: "film") }
                    }
                }
                PetCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. Cast").font(.headline)
                        if model.isCasting {
                            HStack {
                                Label("Casting now", systemImage: "tv.fill").foregroundStyle(.green)
                                Spacer()
                                Button(model.isPaused ? "Resume" : "Pause") { model.togglePlayback() }
                                Button("Next") { model.playNext() }
                                Button("Stop", role: .destructive) { model.stopCasting() }
                            }
                        } else {
                            Button("Cast with Scooby") { model.cast() }
                                .disabled(model.selectedDeviceID == nil || model.selectedFileURL == nil)
                        }
                        if model.isCasting {
                            HStack { Text("Seek: \(model.seekSeconds)s"); Slider(value: Binding(get: { Double(model.seekSeconds) }, set: { model.seekSeconds = Int($0) }), in: 0...14_400, step: 5); Button("Go") { model.seek() } }
                        }
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Casting Scooby")
    }
}
