@testable import CoffeeCat
import XCTest

final class CoffeeCatCommandsTests: XCTestCase {
    func testDefaultSessionPreventsOnlyIdleSleepForOneHour() {
        let configuration = CaffeinateConfiguration()
        XCTAssertEqual(CoffeeCatCommands.caffeinateArguments(for: configuration), ["-i", "-t", "3600"])
    }

    func testAllPreventionOptionsMapToCaffeinateFlags() {
        let configuration = CaffeinateConfiguration(
            preventIdleSleep: true,
            preventDisplaySleep: true,
            preventSystemSleep: true,
            preventDiskSleep: true,
            durationMinutes: 15
        )
        XCTAssertEqual(CoffeeCatCommands.caffeinateArguments(for: configuration), ["-i", "-d", "-s", "-m", "-t", "900"])
    }

    func testDurationIsClampedToOneMinute() {
        var configuration = CaffeinateConfiguration()
        configuration.durationMinutes = 0
        XCTAssertEqual(CoffeeCatCommands.caffeinateArguments(for: configuration), ["-i", "-t", "60"])
    }

    func testDisableLidSleepUsesAdministratorGatedPmsetCommand() {
        XCTAssertEqual(
            CoffeeCatCommands.pmsetLidSleepScript(disabled: true),
            "do shell script \"/usr/bin/pmset -a disablesleep 1\" with administrator privileges"
        )
    }

    func testRestoreLidSleepRestoresPmsetDefault() {
        XCTAssertEqual(
            CoffeeCatCommands.pmsetLidSleepScript(disabled: false),
            "do shell script \"/usr/bin/pmset -a disablesleep 0\" with administrator privileges"
        )
    }
}
