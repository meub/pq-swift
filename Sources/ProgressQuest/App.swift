import SwiftUI
import AppKit

/// Menu bar icon loaded from bundled PNG.
struct MenuBarIcon: View {
    var body: some View {
        if let url = Bundle.module.url(forResource: "menubar-icon", withExtension: "png", subdirectory: "Resources"),
           let nsImage = NSImage(contentsOf: url) {
            let _ = { nsImage.size = NSSize(width: 18, height: 18) }()
            Image(nsImage: nsImage)
        } else {
            Image(systemName: "shield.fill")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct ProgressQuestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var engine = GameEngine()
    @State private var backupManager: BackupManager?
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(engine: engine, backupManager: backupManagerResolved)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)

        Window("Progress Quest", id: "main") {
            if engine.isRunning {
                ContentView(engine: engine)
            } else {
                FrontView(engine: engine)
            }
        }
        .defaultSize(width: 440, height: 260)

        Window("Settings", id: "settings") {
            SettingsView(engine: engine, backupManager: backupManagerResolved)
        }
        .windowResizability(.contentSize)
    }

    private var backupManagerResolved: BackupManager {
        if let bm = backupManager { return bm }
        let bm = BackupManager(engine: engine)
        DispatchQueue.main.async { backupManager = bm }
        return bm
    }
}

/// Compact view shown in the menu bar popover.
struct MenuBarView: View {
    let engine: GameEngine
    let backupManager: BackupManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if engine.isRunning {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.characterName)
                        .font(.headline)
                    Text("Lv \(engine.level) \(engine.race) \(engine.klass)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(engine.taskDisplay)
                        .font(.system(.caption, design: .default))
                        .lineLimit(2)
                    ProgressView(value: Double(min(engine.taskPos, engine.taskMax)),
                                 total: Double(max(engine.taskMax, 1)))
                        .progressViewStyle(.linear)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                HStack(spacing: 4) {
                    Text("XP")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(min(engine.expPos, engine.expMax)),
                                 total: Double(max(engine.expMax, 1)))
                        .progressViewStyle(.linear)
                    Text("\(engine.expMax - engine.expPos) to go")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

                Divider()
            } else {
                Text("Progress Quest")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Text("No game running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                Divider()
            }

            MenuRow(label: "Open ProgressQuest") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            MenuRow(label: "Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            MenuRow(label: "Quit") {
                if engine.isRunning {
                    engine.saveGame()
                    let path = engine.gameSaveName()
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Game Saved"
                        alert.informativeText = "Game saved as \(path)"
                        alert.addButton(withTitle: "OK")
                        alert.alertStyle = .informational
                        alert.runModal()
                        NSApp.terminate(nil)
                    }
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
        .frame(width: 260)
    }
}

/// Simple unstyled menu row with hover highlight.
struct MenuRow: View {
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isHovered ? Color.accentColor.opacity(0.15) : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
