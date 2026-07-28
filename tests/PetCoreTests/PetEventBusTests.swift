import PetCore
import XCTest

final class PetEventBusTests: XCTestCase {
    func testEventBusDeliversEvents() async {
        let bus = PetEventBus()
        let events = await bus.stream()
        let expected = PetEvent.petStarted(id: "scooby")
        async let received: PetEvent? = events.first(where: { $0 == expected })
        await bus.publish(expected)
        let actual = await received
        XCTAssertEqual(actual, expected)
    }
}

