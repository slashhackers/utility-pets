import PetCore
import Testing

@Test("Events published to the bus are delivered to a subscriber")
func eventBusDeliversEvents() async {
    let bus = PetEventBus()
    let events = await bus.stream()
    let expected = PetEvent.petStarted(id: "scooby")
    async let received: PetEvent? = events.first(where: { $0 == expected })
    await bus.publish(expected)
    #expect(await received == expected)
}
