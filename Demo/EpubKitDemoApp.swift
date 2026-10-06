import SwiftUI

@main
struct EpubKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .frame(minWidth: 980, minHeight: 640)
#endif
        }
#if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
#endif
    }
}
