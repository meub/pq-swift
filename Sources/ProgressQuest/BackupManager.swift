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
    private var startupTimer: Timer?
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

        // Poll frequently until the game starts running, then do initial backup check
        DispatchQueue.main.async { [weak self] in
            self?.startupTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                guard let self, let engine = self.engine, engine.isRunning else { return }
                t.invalidate()
                self.startupTimer = nil
                self.checkAndBackup()
            }
        }
    }

    // MARK: - Backup

    func backupNow() {
        guard let engine, engine.isRunning else { return }
        let srcPath = engine.gameSaveName()
        guard FileManager.default.fileExists(atPath: srcPath) else { return }

        // Ensure backup folder exists
        try? FileManager.default.createDirectory(atPath: backupFolder, withIntermediateDirectories: true)

        // Build filename: CharName [Realm] - 2026-03-11_14-30-00.pq
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = fmt.string(from: Date())

        let srcURL = URL(fileURLWithPath: srcPath)
        let baseName = srcURL.deletingPathExtension().deletingPathExtension().lastPathComponent
        let ext = ".pq"
        let backupName = "\(baseName) - \(timestamp)\(ext)"
        let destPath = (backupFolder as NSString).appendingPathComponent(backupName)

        try? FileManager.default.copyItem(atPath: srcPath, toPath: destPath)
        lastBackup = Date()
        savePrefs()
    }

    // MARK: - Timer

    /// Interval between checks (5 minutes). The actual backup frequency
    /// is determined by `schedule`; this just polls for whether one is due.
    private static let checkInterval: TimeInterval = 5 * 60

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = nil

        guard schedule != .off else { return }

        // Check immediately, then poll every 5 minutes on the main run loop
        checkAndBackup()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
                self?.checkAndBackup()
            }
            RunLoop.main.add(self.timer!, forMode: .common)
        }
    }

    private func checkAndBackup() {
        guard schedule != .off, engine?.isRunning == true else { return }

        let interval: TimeInterval
        switch schedule {
        case .off: return
        case .daily: interval = 24 * 60 * 60
        case .weekly: interval = 7 * 24 * 60 * 60
        }

        if let last = lastBackup {
            guard Date().timeIntervalSince(last) >= interval else { return }
        }
        backupNow()
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
