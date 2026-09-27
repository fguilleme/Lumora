import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if CommandLine.arguments.contains("--cinematic-glow-probe") { CinematicGlowDeviceProbe() }
            else { ContentView() }
            #else
            ContentView()
            #endif
        }
    }
}
