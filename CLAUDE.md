# Progress Quest — Swift Edition

Native macOS reimplementation of Progress Quest, the zero-player RPG. v6.4 Swift Edition.

## Build & Run

```bash
swift build              # debug build
swift run ProgressQuest  # run
swift build -c release   # release build
```

Requires macOS 14+ (Sonoma), Swift 5.9+. Zero external dependencies — pure Swift + SwiftUI.

## Project Structure

```
Sources/ProgressQuest/
├── App.swift               — @main entry, menu bar (NSApp.setActivationPolicy(.accessory)), MenuBarView
├── FrontView.swift         — Title screen: New Game, Load Game, Multiplayer
├── NewCharacterView.swift  — Character creation: name, race, class, stat rolling (3d6+3)
├── RealmSelectionView.swift— Multiplayer server browser (fetches realm list)
├── ContentView.swift       — Main game window: 3-column layout + bottom progress bars
├── GameEngine.swift        — Core game logic, all mutable state, save/load, timer tick
├── GameData.swift          — Static data tables from original Config.dfm (monsters, items, spells, races, classes)
├── Server.swift            — PQServer enum: LFSR auth hash, realm list, char registration, brag/status reports
└── Utilities.swift         — Helpers: name gen, roman numerals, English morphology, random utils
```

## Architecture

- **Single `@Observable GameEngine`** is the source of truth for all game state. All views read from it directly.
- **Timer-driven game loop**: 100ms repeating `Timer` calls `tick()`, which advances `taskPos` and triggers state transitions (level-up, quest completion, act transition).
- **Task queue**: Cinematic sequences and multi-step actions are queued as pipe-delimited strings (`"task|duration|text"` or `"plot|duration|text"`) via `q()` and dequeued in `dequeue()`.
- **Game loop flow** (`tick()` → `dequeue()`): kill monster → gain XP → check level-up → check quest completion → check plot/act completion → interplot cinematic → dequeue next task (market/buy/heading/monster).
- **Save format**: `SaveData` Codable struct → JSON files with `.pq.json` extension. Auto-saves to `~/<Name>.pq.json`.

## Key Patterns

- Data tables use pipe-delimited strings: `"name|level"` for equipment, `"name|level|loot"` for monsters, `"modifier|value"` for attributes.
- `splitPipe(s, field)` extracts fields from these strings.
- `pick()` for random selection, `lpick()` for level-matched selection (best-of-6 random samples).
- `randomLow()` / `pickLow()` bias toward lower indices (min of two random values).
- Monster difficulty modifiers: prefix chains like `sickPrefix()`/`youngPrefix()`/`bigPrefix()`/`specialPrefix()` based on level difference.
- Roman numerals extended with A=5000, T=10000 for spell levels.
- English morphology: `plural()`, `indefinite()`, `definite()` for generated text.

## Server Protocol

- LFSR hash (`PQServer.lfsr()`) implements Delphi-compatible authentication — request params are hashed with passkey as salt.
- Brag reports sent on: game start (`"s"`), level-up (`"l"`), act completion (`"a"`).
- Server URL: `http://www.progressquest.com/knoram.php?`
- User-Agent: `PQ6.4`
- Realm opts bitmask: `&4` = directory, `&16` = alt-creation endpoint, `&32` = disabled.

## Code Conventions

- No tests currently exist.
- No external dependencies — do not add any without explicit approval.
- All game data lives in `GameData` enum as static arrays.
- Views are lightweight — business logic belongs in `GameEngine`.
- `taskCaption` stores the current task type for dispatch in `dequeue()` (e.g., `"kill|monster|level|loot"`, `"buying"`, `"market"`, `"sell"`, `"heading"`, `"load"`).
