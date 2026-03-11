import SwiftUI

/// Character creation view.
struct NewCharacterView: View {
    let engine: GameEngine
    let realm: PQServer.Realm?
    @Environment(\.dismiss) private var dismiss

    @State private var name = generateName()
    @State private var selectedRace = Int.random(in: 0..<GameData.races.count)
    @State private var selectedKlass = Int.random(in: 0..<GameData.klasses.count)
    @State private var stats: [String: Int] = [:]
    @State private var isCreating = false
    @State private var errorMessage: String?

    var total: Int { stats.values.reduce(0, +) }

    var body: some View {
        VStack(spacing: 12) {
            Text("New Character")
                .font(.title2.bold())
            if let realm { Text("[\(realm.name)]").foregroundStyle(.secondary) }

            // Name
            HStack {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("Generate") { name = generateName() }
            }

            HStack(alignment: .top, spacing: 16) {
                // Race
                VStack(alignment: .leading) {
                    Text("Race").font(.headline)
                    List(selection: $selectedRace) {
                        ForEach(Array(GameData.races.enumerated()), id: \.offset) { idx, race in
                            Text(race).tag(idx)
                                .font(.system(.body, design: .default))
                        }
                    }
                    .listStyle(.bordered)
                    .frame(width: 200, height: 200)
                }

                // Class
                VStack(alignment: .leading) {
                    Text("Class").font(.headline)
                    List(selection: $selectedKlass) {
                        ForEach(Array(GameData.klasses.enumerated()), id: \.offset) { idx, klass in
                            Text(klass).tag(idx)
                                .font(.system(.body, design: .default))
                        }
                    }
                    .listStyle(.bordered)
                    .frame(width: 200, height: 200)
                }

                // Stats
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stats").font(.headline)
                    ForEach(["STR", "CON", "DEX", "INT", "WIS", "CHA"], id: \.self) { s in
                        HStack {
                            Text(s)
                                .font(.system(.body, design: .default))
                                .frame(width: 40, alignment: .leading)
                            Text("\(stats[s] ?? 0)")
                                .font(.system(.title3, design: .default).bold())
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                    Divider()
                    HStack {
                        Text("Total")
                            .font(.system(.body, design: .default).bold())
                        Spacer()
                        Text("\(total)")
                            .font(.system(.title3, design: .default).bold())
                            .foregroundStyle(totalColor)
                    }
                    .frame(width: 80)

                    Button("Roll") { rollStats() }
                        .keyboardShortcut("r", modifiers: .command)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Sold!") { createCharacter() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
        }
        .padding()
        .frame(minWidth: 550, minHeight: 450)
        .onAppear { rollStats() }
    }

    private var totalColor: Color {
        if total >= 81 { return .red }
        if total > 72 { return .yellow }
        if total <= 45 { return .gray }
        if total < 54 { return .secondary }
        return .primary
    }

    private func rollStats() {
        for s in ["STR", "CON", "DEX", "INT", "WIS", "CHA"] {
            stats[s] = 3 + Int.random(in: 0..<6) + Int.random(in: 0..<6) + Int.random(in: 0..<6)
        }
    }

    private func createCharacter() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        if let realm {
            // Online: register with server
            Task {
                do {
                    let passkey = try await PQServer.createCharacter(
                        hostAddr: realm.host, name: trimmed, realm: realm.name, opts: realm.opts
                    )
                    await MainActor.run {
                        engine.passkey = passkey
                        engine.hostName = realm.name
                        engine.hostAddr = realm.host
                        engine.opts = realm.opts
                        finishCreation(trimmed)
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isCreating = false
                    }
                }
            }
        } else {
            finishCreation(trimmed)
        }
    }

    private func finishCreation(_ trimmed: String) {
        engine.createCharacter(
            name: trimmed,
            race: GameData.races[selectedRace],
            klass: GameData.klasses[selectedKlass],
            statValues: stats
        )
        engine.startGame()
        engine.startTimer()
        dismiss()
    }
}
