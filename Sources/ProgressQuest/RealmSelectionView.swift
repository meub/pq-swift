import SwiftUI

/// Server/realm selection for multiplayer.
struct RealmSelectionView: View {
    let engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    @State private var realms: [PQServer.Realm] = []
    @State private var selectedIdx: Int?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showNewChar = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Select Realm")
                .font(.title2.bold())

            if isLoading {
                ProgressView("Fetching realm list from server...")
                    .padding()
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding()
            } else {
                List(selection: $selectedIdx) {
                    ForEach(Array(realms.enumerated()), id: \.offset) { idx, realm in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(realm.name)
                                    .font(.headline)
                                if realm.opts & 32 != 0 {
                                    Text("DISABLED")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            if !realm.desc.isEmpty {
                                Text(realm.desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .tag(idx)
                    }
                }
                .listStyle(.bordered)
                .frame(minHeight: 150)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Select") { selectRealm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedIdx == nil || isLoading)
            }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 300)
        .task { await fetchRealms() }
        .sheet(isPresented: $showNewChar) {
            if let idx = selectedIdx, idx < realms.count {
                NewCharacterView(engine: engine, realm: realms[idx])
            }
        }
        .onChange(of: engine.isRunning) {
            if engine.isRunning { dismiss() }
        }
    }

    private func fetchRealms() async {
        do {
            let (list, defaultName) = try await PQServer.fetchRealmList()
            realms = list
            selectedIdx = list.firstIndex(where: { $0.name == defaultName }) ?? (list.isEmpty ? nil : 0)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func selectRealm() {
        guard let idx = selectedIdx, idx < realms.count else { return }
        let realm = realms[idx]
        if realm.opts & 32 != 0 { return } // disabled
        if realm.opts & 4 != 0 {
            // Directory - would need recursive fetch, skip for now
            errorMessage = "Directory realms not supported yet"
            return
        }
        showNewChar = true
    }
}
