import Foundation

struct CaffeinateConfiguration: Equatable {
    var preventIdleSleep: Bool = true
    var preventDisplaySleep = false
    var preventSystemSleep = false
    var preventDiskSleep = false
    var durationMinutes = 60
}

enum CoffeeCatCommands {
    static func caffeinateArguments(for configuration: CaffeinateConfiguration) -> [String] {
        var arguments: [String] = []
        if configuration.preventIdleSleep { arguments.append("-i") }
        if configuration.preventDisplaySleep { arguments.append("-d") }
        if configuration.preventSystemSleep { arguments.append("-s") }
        if configuration.preventDiskSleep { arguments.append("-m") }
        arguments += ["-t", String(max(1, configuration.durationMinutes) * 60)]
        return arguments
    }

    static func pmsetLidSleepScript(disabled: Bool) -> String {
        let value = disabled ? "1" : "0"
        return "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
    }
}

enum CoffeeCatPowerSettings {
    static func setLidSleepDisabled(_ disabled: Bool) async -> String {
        await Task.detached {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", CoffeeCatCommands.pmsetLidSleepScript(disabled: disabled)]
            do {
                try task.run()
                task.waitUntilExit()
                guard task.terminationStatus == 0 else { return "The power setting was not changed." }
                return disabled ? "Sleep while the lid is closed is disabled." : "Sleep while the lid is closed is enabled."
            } catch {
                return "Could not run pmset: \(error.localizedDescription)"
            }
        }.value
    }
}
