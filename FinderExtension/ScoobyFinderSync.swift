import Cocoa
import FinderSync

final class ScoobyFinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: NSHomeDirectory())]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems,
              let fileURL = FIFinderSyncController.default().selectedItemURLs()?.first,
              fileURL.pathExtension.lowercased() == "mp4" else { return nil }

        let menu = NSMenu(title: "Scooby")
        let item = NSMenuItem(title: "🐶 Cast with Scooby", action: #selector(castWithScooby(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = fileURL
        menu.addItem(item)
        return menu
    }

    @objc private func castWithScooby(_ sender: NSMenuItem) {
        guard let fileURL = sender.representedObject as? URL else { return }
        var components = URLComponents()
        components.scheme = "utilitypets"
        components.host = "cast"
        components.queryItems = [URLQueryItem(name: "file", value: fileURL.path)]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }
}
