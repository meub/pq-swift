import SwiftUI

/// Main game view matching the classic PQ three-column layout.
struct ContentView: View {
    let engine: GameEngine

    var body: some View {
        VStack(spacing: 0) {
            // Three-column layout
            HStack(alignment: .top, spacing: 0) {
                leftColumn
                Divider()
                middleColumn
                Divider()
                rightColumn
            }

            Divider()

            // Bottom: task bar + big XP bar
            bottomArea
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .background(WindowConfigurator(resizable: true))
        .navigationTitle(windowTitle)
    }

    private var windowTitle: String {
        var t = "ProgressQuest"
        if !engine.characterName.isEmpty {
            t += " – \(engine.characterName)"
            if !engine.hostName.isEmpty { t += " [\(engine.hostName)]" }
        }
        return t
    }

    // MARK: - Left Column

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Character Sheet")

            PQKeyValueRows(items: [
                ("Name:", engine.characterName),
                ("Race:", engine.race),
                ("Class:", engine.klass),
                ("Level:", "\(engine.level)"),
            ])

            PQColumnHeader(left: "Stat", right: "Value")

            PQKeyValueTable(items: engine.orderedStats.map { ($0.0, "\($0.1)") })

            // XP bar under stats
            VStack(spacing: 1) {
                Text("Experience")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PQBar(value: engine.expPos, max: engine.expMax)
                    .frame(height: 14)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)

            SectionHeader("Spell Book")
            PQColumnHeader(left: "Spell", right: "Level")
            PQKeyValueTable(items: engine.spells.map { ($0.name, $0.level) })
        }
        .frame(minWidth: 220, idealWidth: 280)
    }

    // MARK: - Middle Column

    private var middleColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Equipment")

            PQKeyValueTable(items: engine.equips.map { ($0.slot, $0.item) })

            SectionHeader("Inventory")
            PQColumnHeader(left: "Item", right: "Qty")
            PQKeyValueTable(items: engine.inventory.map { ($0.name, "\($0.qty)") })

            Spacer(minLength: 0)

            // Encumbrance at bottom of middle column
            VStack(alignment: .leading, spacing: 2) {
                Text("Encumbrance")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                PQBar(value: engine.encumPos, max: engine.encumMax)
                    .frame(height: 14)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
            }
        }
        .frame(minWidth: 250, idealWidth: 320)
    }

    // MARK: - Right Column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Plot Development")
            PQChecklist(items: engine.plots.map { ($0.name, $0.completed) })

            SectionHeader("Quests")
            PQChecklist(items: engine.quests.suffix(20).map { ($0.name, $0.completed) })
        }
        .frame(minWidth: 200, idealWidth: 260)
    }

    // MARK: - Bottom Area

    private var bottomArea: some View {
        ZStack(alignment: .leading) {
            PQBar(value: engine.taskPos, max: engine.taskMax)
            Text(engine.taskDisplay)
                .font(.system(size: 12))
                .lineLimit(1)
                .padding(.horizontal, 8)
        }
        .frame(height: 24)
    }
}

// MARK: - Reusable Components

/// Bold section header with background.
struct SectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) {
                Divider()
            }
    }
}

/// Column header row (e.g., "Stat" / "Value").
struct PQColumnHeader: View {
    let left: String
    let right: String
    var body: some View {
        HStack {
            Text(left)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(right)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// Simple key-value rows (no scroll, for small fixed lists like name/race/class).
struct PQKeyValueRows: View {
    let items: [(String, String)]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack {
                    Text(item.0)
                        .font(.system(size: 12, design: .default))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 50, alignment: .leading)
                    Text(item.1)
                        .font(.system(size: 12, design: .default))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(idx % 2 == 1 ? Color(nsColor: .alternatingContentBackgroundColors[1]) : .clear)
            }
        }
    }
}

/// Scrollable key-value table with alternating rows.
struct PQKeyValueTable: View {
    let items: [(String, String)]
    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.0)
                        .font(.system(size: 11, design: .default))
                        .lineLimit(1)
                    Spacer()
                    Text(item.1)
                        .font(.system(size: 11, design: .default))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
            }
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        .scrollContentBackground(.hidden)
    }
}

/// Checklist with blue square checkboxes.
struct PQChecklist: View {
    let items: [(String, Bool)]
    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 4) {
                    Image(systemName: item.1 ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.1 ? .blue : .secondary)
                        .font(.system(size: 13))
                    Text(item.0)
                        .font(.system(size: 11, design: .default))
                        .lineLimit(1)
                }
                .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
            }
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        .scrollContentBackground(.hidden)
    }
}

/// Flat blue progress bar matching the mockup style.
struct PQBar: View {
    var value: Int
    var max: Int

    private var fraction: Double {
        guard max > 0 else { return 0 }
        return Double(min(value, max)) / Double(max)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(nsColor: .separatorColor).opacity(0.3))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: geo.size.width * fraction)
            }
        }
    }
}

// MARK: - Character Sheet (popup)

struct CharacterSheetView: View {
    let engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading) {
            Text(engine.characterName)
                .font(.title.bold())
            Text("\(engine.race) \(engine.klass)")
                .font(.title3)
            Text("Level \(engine.level) (exp. \(engine.expPos)/\(engine.expMax))")
                .foregroundStyle(.secondary)

            Divider()

            if let plot = engine.plots.last {
                Text("Plot: \(plot.name) — \(roughTime(engine.plotMax - engine.plotPos)) remaining")
            }
            if let quest = engine.quests.last {
                Text("Quest: \(quest.name) — \(100 * engine.questPos / max(engine.questMax, 1))%")
            }

            Divider()

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Stats").font(.headline)
                    ForEach(engine.orderedStats, id: \.0) { s in
                        Text("\(s.0): \(s.1)")
                            .font(.system(.body, design: .default))
                    }
                }
                VStack(alignment: .leading) {
                    Text("Equipment").font(.headline)
                    ForEach(Array(engine.equips.enumerated()), id: \.offset) { _, e in
                        if !e.item.isEmpty {
                            Text("\(e.slot): \(e.item)")
                                .font(.system(.body, design: .default))
                        }
                    }
                }
            }

            Spacer()
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
}
