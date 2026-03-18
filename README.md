# Progress Quest — Swift Edition

[![Release](https://img.shields.io/github/v/release/meub/pq-swift)](https://github.com/meub/pq-swift/releases/tag/v1.3)

A native macOS reimplementation of [Progress Quest](http://progressquest.com/), the original zero-player RPG. Your character automatically fights monsters, completes quests, levels up, and advances through an epic plot — all without any player interaction whatsoever.

**Unofficial macOS Swift Version — Compatible with v6.4.4**

Made with help from [Claude Code](https://claude.ai/code)

## Install

**[Download the latest DMG](https://github.com/meub/pq-swift/releases/latest/download/ProgressQuest-v1.3.dmg)** from the [Releases](https://github.com/meub/pq-swift/releases) page, open it, and drag ProgressQuest to your Applications folder.

> **Note:** The app is not code-signed. On first launch, right-click the app and choose "Open" to bypass Gatekeeper, or go to System Settings > Privacy & Security and click "Open Anyway".

## Limitations

- **macOS 14 (Sonoma) or later** — Uses SwiftUI APIs introduced in macOS 14; will not run on Ventura or earlier
- **Not code-signed or notarized** — macOS Gatekeeper will block the app on first launch; you must manually approve it (see install note above)
- **Multiplayer requires HTTP** — The official Progress Quest server (`progressquest.com`) only supports HTTP, not HTTPS. Strict network configurations or firewalls that block plain HTTP may prevent multiplayer features from working
- **No iCloud or cross-device sync** — Save files are stored locally in your home directory

## Screenshots

| Menu Bar Popover | Game Window |
|:---:|:---:|
| ![Menu bar popover showing character status, task progress, and XP](screenshots/menubar.png) | ![Main game window with 3-column layout](screenshots/gamewindow.png) |

**Menu Bar** — Lives in your menu bar with a compact popover showing character name, level, current task progress, and XP. Quick access to the game window, settings, and quit.

**Game Window** — Classic three-column layout: character sheet with stats and spellbook on the left, equipment and inventory in the middle, plot development and quest log on the right. The bottom status bar tracks your current action in real time.

## Features

### Menu Bar App
- Runs quietly in your macOS menu bar — no Dock icon
- Click the menu bar icon for a compact status popover showing:
  - Character name, level, race, and class
  - Current task with progress bar
  - XP progress toward next level
- Quick access to the game window, settings, and quit

### Full Game Window
- Classic three-column layout:
  - **Left**: Character sheet, stats (STR/CON/DEX/INT/WIS/CHA/HP/MP), spellbook with Roman numeral levels, experience bar
  - **Middle**: Equipment (11 slots), inventory with quantities, encumbrance bar
  - **Right**: Plot development with completed act checkmarks, quest log (last 20)
- Bottom status bar shows current action ("Executing 3 Kobolds...")

### Online Multiplayer
- Connect to official Progress Quest servers and join realms
- Browse available realms with descriptions
- Character registration with server-assigned passkey
- Status reports ("brags") sent on level-ups, act completions, and game start
- LFSR authentication compatible with the original Delphi client
- Guild and Motto support

### Save System
- **Delphi-compatible binary format**: Saves as `.pq` files (zlib-compressed DFM component streams), fully compatible with the original Progress Quest
- **Auto-save**: On level-ups, quest completions, and act transitions to `~/<CharacterName>.pq`
- **Cross-compatible**: Save files can be loaded by any version of Progress Quest

### Automatic Backups
- Configurable schedule: Off, Daily, or Weekly
- Timestamped backup files: `CharName - 2026-03-11_14-30-00.pq`
- Customizable backup folder (default: `~/Documents/ProgressQuest Backups`)
- Manual "Back Up Now" button in Settings
- Preferences persisted across launches

### Zero Dependencies
- Pure Swift + SwiftUI — no third-party packages
- Single Swift Package Manager target
- Compiles with `swift build`, no Xcode project required

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+

## Building from Source

```bash
# Clone and build
git clone https://github.com/meub/pq-swift.git
cd pq-swift
swift build

# Run
swift run ProgressQuest

# Or build a release binary
swift build -c release
.build/release/ProgressQuest
```

## How It Works

### Starting a Game

1. Launch the app — it appears in your **menu bar** (not the Dock)
2. Click the icon and choose **Open ProgressQuest**
3. From the title screen, pick:
   - **New Game (Single Player)** — Create a character and play offline
   - **New Game (Multiplayer)** — Register on an official PQ realm
   - **Load Game** — Resume from a `.pq` save file
   - **Exit** — Close the window

### Character Creation

- Enter a name or click **Generate** for a procedurally generated one (consonant-vowel-consonant syllable chains)
- Pick a race from 21 options, each with unique stat modifiers
- Pick a class from 18 options, each with unique stat modifiers
- Roll stats: 3d6+3 for STR, CON, DEX, INT, WIS, CHA
- Click **Sold!** to begin your adventure

### Saving & Quitting

- Games auto-save to `~/<CharacterName>.pq` at key milestones
- Clicking **Quit** in the menu bar saves the game and shows a confirmation with the save file path before exiting

### Settings

Access via the menu bar dropdown:
- View current save file location
- Configure automatic backup schedule (Off / Daily / Weekly)
- Choose a custom backup folder
- See last backup timestamp
- Trigger a manual backup

## Credits

- Original [Progress Quest](http://progressquest.com/) by Eric Fredricksen
- Swift reimplementation compatible with PQ v6.4.4 server protocol
