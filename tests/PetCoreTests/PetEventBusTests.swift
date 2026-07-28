import PetCore
import XCTest

final class PetEventBusTests: XCTestCase {
    func testEventBusDeliversEvents() async {
        let bus = PetEventBus()
        let events = await bus.stream()
        let expected = PetEvent.petStarted(id: "scooby")
        
        let task = Task<PetEvent?, Never> {
            for await event in events {
                if event == expected {
                    return event
                }
            }
            return nil
        }
        
        await bus.publish(expected)
        let received = await task.value
        XCTAssertEqual(received, expected)
    }
}

