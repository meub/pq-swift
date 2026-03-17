import SwiftUI
import UniformTypeIdentifiers

/// Title screen / main menu.
struct FrontView: View {
    let engine: GameEngine
    @State private var showNewChar = false
    @State private var showRealmSelect = false
    @State private var showFileOpen = false
    @State private var loadError: String?

    var body: some View {
        HStack(spacing: 0) {
            // Left: logo
            VStack {
                Spacer()
                if let url = Bundle.module.url(forResource: "pq-logo", withExtension: "png", subdirectory: "Resources"),
                   let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160)
                }
                VStack(spacing: 2) {
                    Text("Unofficial macOS Swift Version")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Compatible with v6.4.4")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.leading, 24)
            .padding(.trailing, 20)

            // Right: buttons
            VStack(spacing: 8) {
                Spacer()

                VStack(spacing: 6) {
                    Button(action: { showNewChar = true }) {
                        Text("New Game (Single Player)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: { showRealmSelect = true }) {
                        Text("New Game (Multiplayer)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: { showFileOpen = true }) {
                        Text("Load Game")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: { NSApp.terminate(nil) }) {
                        Text("Exit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()

                Link("progressquest.com", destination: URL(string: "http://progressquest.com/")!)
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("Build \(AppBuild.number)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 220)
            .padding(.trailing, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 440, height: 260)
        .background(.white)
        .background(WindowConfigurator(resizable: false, size: NSSize(width: 440, height: 260)))
        .sheet(isPresented: $showNewChar) {
            NewCharacterView(engine: engine, realm: nil)
        }
        .sheet(isPresented: $showRealmSelect) {
            RealmSelectionView(engine: engine)
        }
        .fileImporter(isPresented: $showFileOpen,
                      allowedContentTypes: [.json, .data, .item],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                do {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    try engine.loadGame(url.path)
                    engine.startTimer()
                    engine.doBrag("s")
                    loadError = nil
                } catch {
                    loadError = error.localizedDescription
                }
            }
        }
        .alert("Load Error", isPresented: .init(get: { loadError != nil }, set: { if !$0 { loadError = nil } })) {
            Button("OK") { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
    }
}
