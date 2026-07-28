import PetCore
import XCTest

final class PetEventBusTests: XCTestCase {
    func testEventBusDeliversEvents() async {
        let bus = PetEventBus()
        let events = await bus.stream()
        let expected = PetEvent.petStarted(id: "scooby")
        
        let exp = expectation(description: "Event delivered")
        var received: PetEvent?
        
        Task {
            for await event in events {
                if event == expected {
                    received = event
                    exp.fulfill()
                    break
                }
            }
        }
        
        await bus.publish(expected)
        await fulfillment(of: [exp], timeout: 3.0)
        XCTAssertEqual(received, expected)
    }
}

