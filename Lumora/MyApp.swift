import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if CommandLine.arguments.contains("--cinematic-glow-probe") { CinematicGlowDeviceProbe() }
            else if CommandLine.arguments.contains("--relighting-phases-probe") || CommandLine.arguments.contains("--lighting-halo-probe") { RelightingDeviceProbe() }
            else if CommandLine.arguments.contains("--depth-lens-probe") { DepthLensDeviceProbe() }
            else { ContentView() }
            #else
            ContentView()
            #endif
        }
    }
}
