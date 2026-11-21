import SwiftUI

@main
@MainActor
struct catalogue_managementApp: App {
    private let container: AppContainer?
    private let startupError: String?

    init() {
        do {
            container = try AppContainer.configured()
            startupError = nil
        } catch {
            container = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView(container: container)
            } else {
                ContentUnavailableView(
                    "Catalogue unavailable",
                    systemImage: "network.slash",
                    description: Text(startupError ?? "The app configuration could not be loaded.")
                )
            }
        }
    }
}
