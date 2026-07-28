import AppKit
import PetCore
import Scooby
import SwiftUI

@main
struct UtilityPetsApp: App {
    @NSApplicationDelegateAdaptor(UtilityPetsServiceDelegate.self) private var serviceDelegate
    @StateObject private var registry: PetRegistry
    init() {
        let scooby = CastingScoobyPet()
        _registry = StateObject(wrappedValue: PetRegistry(pets: [scooby]))
        UtilityPetsServiceDelegate.onFiles = { files in
            Task { @MainActor in files.forEach(scooby.open(fileURL:)) }
        }
        if let argument = CommandLine.arguments.dropFirst().first, FileManager.default.fileExists(atPath: argument) {
            Task { @MainActor in scooby.open(fileURL: URL(fileURLWithPath: argument)) }
        }
    }
    var body: some Scene {
        WindowGroup("Utility Pets") {
            PetHostView().environmentObject(registry).task { await registry.startAll() }
        }
        .defaultSize(width: 820, height: 540)
        MenuBarExtra("Utility Pets", systemImage: "pawprint.fill") { PetMenuBarView().environmentObject(registry) }
            .menuBarExtraStyle(.window)
    }
}

/// Native macOS Services bridge for Finder's “Cast with Scooby” menu item.
final class UtilityPetsServiceDelegate: NSObject, NSApplicationDelegate {
    static var onFiles: (([URL]) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.compactMap { url -> URL? in
            guard url.scheme == "utilitypets",
                  url.host == "cast",
                  let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "file" })?.value else { return nil }
            return URL(fileURLWithPath: path)
        }
        Self.onFiles?(files)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func castWithScooby(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
        let mp4Files = urls.filter { $0.pathExtension.lowercased() == "mp4" }
        guard !mp4Files.isEmpty else {
            error.pointee = "Cast with Scooby accepts MP4 files only." as NSString
            return
        }
        Self.onFiles?(mp4Files)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct PetHostView: View {
    @EnvironmentObject private var registry: PetRegistry
    var body: some View {
        NavigationSplitView {
            List(registry.pets, id: \.id, selection: $registry.selectedPetID) { pet in
                Text("\(pet.icon)  \(pet.displayName)").tag(pet.id)
            }.navigationTitle("Your Pets")
        } detail: { registry.selectedPet?.makeView() }
    }
}

private struct PetMenuBarView: View {
    @EnvironmentObject private var registry: PetRegistry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🐾 Utility Pets").font(.headline)
            ForEach(registry.pets, id: \.id) { pet in Button("\(pet.icon) \(pet.displayName)") { registry.selectedPetID = pet.id } }
            Divider()
            Button("Quit Utility Pets") { NSApplication.shared.terminate(nil) }
        }.padding().frame(width: 230, alignment: .leading)
    }
}
