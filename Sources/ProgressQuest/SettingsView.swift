import SwiftUI

struct SettingsView: View {
    let engine: GameEngine
    @Bindable var backupManager: BackupManager
    @Environment(\.dismiss) private var dismiss
    @State private var showFolderPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2.bold())

            // Save file info
            GroupBox("Save File") {
                VStack(alignment: .leading, spacing: 6) {
                    if engine.isRunning {
                        HStack(alignment: .top) {
                            Text("Location:")
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                            Text(engine.gameSaveName())
                                .textSelection(.enabled)
                                .lineLimit(3)
                        }
                    } else {
                        Text("No game running")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            // Motto & Guild
            if engine.isRunning && engine.passkey != 0 {
                GroupBox("Leaderboard") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Motto:")
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                            TextField("Shown on leaderboard", text: Binding(
                                get: { engine.motto },
                                set: { engine.motto = $0 }
                            ))
                                .textFieldStyle(.roundedBorder)
                            Button("Update") { engine.doBrag("s") }
                                .controlSize(.small)
                        }
                        HStack {
                            Text("Guild:")
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                            TextField("Guild name", text: Binding(
                                get: { engine.guild },
                                set: { engine.guild = $0 }
                            ))
                                .textFieldStyle(.roundedBorder)
                            Button("Update") {
                                PQServer.sendGuildify(
                                    traits: engine.bragTraits, hostName: engine.hostName,
                                    hostAddr: engine.hostAddrResolved, passkey: engine.passkey,
                                    guild: engine.guild
                                )
                            }
                                .controlSize(.small)
                        }
                    }
                    .padding(4)
                }
            }

            // Backup settings
            GroupBox("Backups") {
                VStack(alignment: .leading, spacing: 10) {
                    // Schedule picker
                    HStack {
                        Text("Schedule:")
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                        Picker("", selection: $backupManager.schedule) {
                            ForEach(BackupManager.Schedule.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }

                    // Backup folder
                    HStack(alignment: .top) {
                        Text("Folder:")
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(backupManager.backupFolder)
                                .textSelection(.enabled)
                                .lineLimit(2)
                                .font(.system(size: 11))
                            Button("Choose...") { showFolderPicker = true }
                                .controlSize(.small)
                        }
                    }

                    // Last backup
                    HStack {
                        Text("Last:")
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                        if let last = backupManager.lastBackup {
                            Text(last, style: .date)
                            Text("at")
                                .foregroundStyle(.secondary)
                            Text(last, style: .time)
                        } else {
                            Text("Never")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Manual backup button
                    HStack {
                        Spacer().frame(width: 76)
                        Button("Back Up Now") { backupManager.backupNow() }
                            .controlSize(.small)
                            .disabled(!engine.isRunning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420, height: 420)
        .fileImporter(isPresented: $showFolderPicker,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                _ = url.startAccessingSecurityScopedResource()
                backupManager.backupFolder = url.path
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}
