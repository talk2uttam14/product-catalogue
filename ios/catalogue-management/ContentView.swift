import SwiftUI

struct ContentView: View {
    let container: AppContainer

    var body: some View {
        TabView {
            HomeScreen(container: container)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .accessibilityIdentifier("catalogue.homeTab")

            SearchScreen(container: container)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .accessibilityIdentifier("catalogue.searchTab")
        }
        .tint(.accentColor)
    }
}
