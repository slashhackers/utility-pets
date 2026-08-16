import AppKit
import PetCore
import SharedUI
import SwiftUI

/// ☕🐱 A native macOS control panel for `caffeinate` and selected `pmset` settings.
@MainActor
public final class CoffeeCatPet: PetPlugin {
    public let id = "coffee-cat"
    public let displayName = "CoffeeCat"
    public let icon = "☕🐱"
    public let tagline = "Keep your Mac awake, on your terms"
    private let model = CoffeeCatModel()

    public init() {}
    public func start() async {}
    public func stop() async { model.stopCaffeinate() }
    public func commands() -> [PetCommand] {
        [PetCommand(id: "start-caffeinate", title: "Keep Mac Awake", systemImage: "cup.and.saucer.fill")]
    }
    public func makeView() -> AnyView { AnyView(CoffeeCatView(model: model)) }
}

@MainActor
private final class CoffeeCatModel: ObservableObject {
    @Published var preventIdleSleep = true
    @Published var preventDisplaySleep = false
    @Published var preventSystemSleep = false
    @Published var preventDiskSleep = false
    @Published var durationMinutes = 60
    @Published var isRunning = false
    @Published var status = "Not keeping your Mac awake"
    @Published var powerStatus: String?
    private var process: Process?

    func startCaffeinate() {
        stopCaffeinate()
        let command = Process()
        command.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        command.arguments = CoffeeCatCommands.caffeinateArguments(for: CaffeinateConfiguration(
            preventIdleSleep: preventIdleSleep,
            preventDisplaySleep: preventDisplaySleep,
            preventSystemSleep: preventSystemSleep,
            preventDiskSleep: preventDiskSleep,
            durationMinutes: durationMinutes
        ))
        command.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.process === command else { return }
                self?.process = nil
                self?.isRunning = false
                self?.status = "Timer finished — normal sleep settings restored"
            }
        }
        do {
            try command.run()
            process = command
            isRunning = true
            status = "Keeping your Mac awake for \(durationMinutes) minutes"
        } catch {
            status = "Could not start caffeinate: \(error.localizedDescription)"
        }
    }

    func stopCaffeinate() {
        process?.terminate()
        process = nil
        isRunning = false
        if !status.contains("Could not") { status = "Normal sleep settings restored" }
    }

    func setLidSleepDisabled(_ disabled: Bool) {
        powerStatus = "Requesting administrator permission…"
        Task { [weak self] in
            let result = await CoffeeCatPowerSettings.setLidSleepDisabled(disabled)
            self?.powerStatus = result
        }
    }
}

private struct CoffeeCatView: View {
    @ObservedObject var model: CoffeeCatModel
    @State private var showPowerWarning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("☕🐱").font(.system(size: 64))
                Text("CoffeeCat").font(.largeTitle.bold())
                Text("A professional control panel for keeping your Mac awake.").font(.title3).foregroundStyle(.secondary)

                PetCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Caffeinate session").font(.headline)
                        Toggle("Prevent idle sleep", isOn: $model.preventIdleSleep)
                        Toggle("Prevent display sleep", isOn: $model.preventDisplaySleep)
                        Toggle("Prevent system sleep while on AC power", isOn: $model.preventSystemSleep)
                        Toggle("Prevent disk idle sleep", isOn: $model.preventDiskSleep)
                        Stepper("Duration: \(model.durationMinutes) minutes", value: $model.durationMinutes, in: 1...1_440)
                        HStack {
                            Button(model.isRunning ? "Restart timer" : "Keep Mac awake") { model.startCaffeinate() }
                                .buttonStyle(.borderedProminent)
                            if model.isRunning { Button("Stop") { model.stopCaffeinate() } }
                            Text(model.status).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                PetCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Advanced power settings").font(.headline)
                        Text("These controls run pmset with administrator permission. Lid-closed operation depends on your Mac model, power source, external display, and thermal conditions.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Disable sleep when lid closes") { showPowerWarning = true }
                            Button("Restore lid-close sleep") { model.setLidSleepDisabled(false) }
                        }
                        if let status = model.powerStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .padding(40)
        }
        .navigationTitle("CoffeeCat")
        .alert("Disable sleep when the lid closes?", isPresented: $showPowerWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Disable sleep", role: .destructive) { model.setLidSleepDisabled(true) }
        } message: {
            Text("This may increase heat and battery use. CoffeeCat will ask for your administrator password before changing the system setting.")
        }
    }
}
