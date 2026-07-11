import SwiftUI

@main
struct PinchPrototypeApp: App {
    var body: some Scene {
        WindowGroup("Pinch — Throwaway Prototype") {
            PrototypeRootView()
                .frame(minWidth: 920, minHeight: 680)
        }
        .windowResizability(.contentMinSize)
    }
}
