import SwiftUI

@main
struct IFFQuickLookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("IFF-it QuickLook")
                .font(.title)
            Text("This app provides Quick Look previews for IFF/ILBM image files.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Select a .iff file in Finder and press Space to preview it.")
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }
}
