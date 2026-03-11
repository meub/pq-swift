import Foundation

/// Manages periodic backups of the save file.
@Observable
final class BackupManager {
    enum Schedule: String, CaseIterable, Codable {
        case off = "Off"
        case daily = "Daily"
        case weekly = "Weekly"
    }

    var schedule: Schedule {
        didSet { savePrefs(); rescheduleTimer() }
    }
    var backupFolder: String {
        didSet { savePrefs() }
    }
    var lastBackup: Date?

    private var timer: Timer?
    private weak var engine: GameEngine?

    private static let prefsKey = "PQBackupPrefs"

    struct Prefs: Codable {
        var schedule: Schedule = .off
        var backupFolder: String = ""
        var lastBackup: Date?
    }

    init(engine: GameEngine) {
        self.engine = engine
        let prefs = Self.loadPrefs()
        self.schedule = prefs.schedule
        self.backupFolder = prefs.backupFolder
        self.lastBackup = prefs.lastBackup

        if backupFolder.isEmpty {
            // Default: ~/Documents/ProgressQuest Backups
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory()
            backupFolder = docs + "/ProgressQuest Backups"
        }

        rescheduleTimer()
    }

    // MARK: - Backup

    func backupNow() {
        guard let engine, engine.isRunning else { return }
        let srcPath = engine.gameSaveName()
        guard FileManager.default.fileExists(atPath: srcPath) else { return }

        // Ensure backup folder exists
        try? FileManager.default.createDirectory(atPath: backupFolder, withIntermediateDirectories: true)

        // Build filename: CharName [Realm] - 2026-03-11_14-30-00.pq.json
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = fmt.string(from: Date())

        let srcURL = URL(fileURLWithPath: srcPath)
        let baseName = srcURL.deletingPathExtension().deletingPathExtension().lastPathComponent
        let ext = srcPath.hasSuffix(".pq.json") ? ".pq.json" : ("." + srcURL.pathExtension)
        let backupName = "\(baseName) - \(timestamp)\(ext)"
        let destPath = (backupFolder as NSString).appendingPathComponent(backupName)

        try? FileManager.default.copyItem(atPath: srcPath, toPath: destPath)
        lastBackup = Date()
        savePrefs()
    }

    // MARK: - Timer

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = nil

        let interval: TimeInterval
        switch schedule {
        case .off: return
        case .daily: interval = 24 * 60 * 60
        case .weekly: interval = 7 * 24 * 60 * 60
        }

        // Check if a backup is due now
        if let last = lastBackup {
            if Date().timeIntervalSince(last) >= interval {
                backupNow()
            }
        } else if engine?.isRunning == true {
            // First backup
            backupNow()
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.backupNow()
        }
    }

    // MARK: - Persistence

    private func savePrefs() {
        let prefs = Prefs(schedule: schedule, backupFolder: backupFolder, lastBackup: lastBackup)
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: Self.prefsKey)
        }
    }

    private static func loadPrefs() -> Prefs {
        guard let data = UserDefaults.standard.data(forKey: prefsKey),
              let prefs = try? JSONDecoder().decode(Prefs.self, from: data) else {
            return Prefs()
        }
        return prefs
    }
}
