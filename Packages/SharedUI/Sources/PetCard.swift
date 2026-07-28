import SwiftUI

public struct PetCard<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View { content.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
}
