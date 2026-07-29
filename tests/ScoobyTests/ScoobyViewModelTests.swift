@testable import Scooby
import DeviceDiscovery
import Foundation
import XCTest

@MainActor
final class ScoobyViewModelTests: XCTestCase {
    func testEnqueueAndQueueNavigation() {
        let model = ScoobyViewModel()
        let file1 = URL(fileURLWithPath: "/tmp/test1.mp4")
        let file2 = URL(fileURLWithPath: "/tmp/test2.mp4")

        model.enqueue(file1)
        model.enqueue(file2)

        XCTAssertEqual(model.queue.count, 2)
        XCTAssertEqual(model.selectedFileURL, file1)

        // Queue duplicate prevention
        model.enqueue(file1)
        XCTAssertEqual(model.queue.count, 2)

        // Remove from queue
        model.removeFromQueue(file1)
        XCTAssertEqual(model.queue.count, 1)
        XCTAssertEqual(model.selectedFileURL, file2)
    }

    func testSeekAndSkipBoundaries() {
        let model = ScoobyViewModel()
        model.seekSeconds = 50

        model.skipForward(seconds: 15)
        XCTAssertEqual(model.seekSeconds, 65)

        model.rewind(seconds: 20)
        XCTAssertEqual(model.seekSeconds, 45)

        model.rewind(seconds: 100)
        XCTAssertEqual(model.seekSeconds, 0, "Rewind should clamp seekSeconds at 0")
    }

    func testCastValidationWithoutDeviceOrFile() {
        let model = ScoobyViewModel()
        model.cast()

        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.errorMessage, "Choose a TV and a media file first.")
        XCTAssertFalse(model.isCasting)
    }
}
