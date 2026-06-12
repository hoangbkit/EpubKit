import SwiftUI

@main
struct EpubKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
