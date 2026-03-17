import Foundation

// MARK: - Codable model types for save/load

struct EquipEntry: Codable { var slot: String; var item: String }
struct SpellEntry: Codable { var name: String; var level: String }
struct InventoryEntry: Codable { var name: String; var qty: Int }
struct QuestEntry: Codable { var name: String; var completed: Bool }
struct PlotEntry: Codable { var name: String; var completed: Bool }

struct SaveData: Codable {
    var version = "pqswift-1.0"
    var name = "", race = "", klass = "", level = 1
    var stats: [String: Int] = [:]
    var equips: [EquipEntry] = []
    var bestEquipIdx = 0
    var spells: [SpellEntry] = []
    var inventory: [InventoryEntry] = []
    var quests: [QuestEntry] = []
    var plots: [PlotEntry] = []
    var questPos = 0, questMax = 100
    var questMonster = "", questMonsterTag = 0
    var plotPos = 0, plotMax = 26
    var taskPos = 0, taskMax = 1
    var taskCaption = "", taskDisplay = ""
    var taskQueue: [String] = []
    var expPos = 0, expMax = 1269
    var gameStyle = 3
    var passkey = 0, motto = ""
    var hostName = "", hostAddr = ""
    var login = "", password = "", guild = ""
    var opts = 0
}

// MARK: - Game Engine

@Observable
final class GameEngine {
    // Traits
    var characterName = ""
    var race = ""
    var klass = ""
    var level = 1

    // Stats
    var stats: [String: Int] = [:]
    private let statOrder = ["STR", "CON", "DEX", "INT", "WIS", "CHA", "HP Max", "MP Max"]

    var orderedStats: [(String, Int)] {
        statOrder.compactMap { k in stats[k].map { (k, $0) } }
    }

    // Equipment
    var equips: [EquipEntry] = []
    var bestEquipIdx = 0

    // Spells
    var spells: [SpellEntry] = []

    // Inventory
    var inventory: [InventoryEntry] = []

    // Quests
    var quests: [QuestEntry] = []
    var questPos = 0
    var questMax = 100

    // Plot
    var plots: [PlotEntry] = []
    var plotPos = 0
    var plotMax = 26

    // Task
    var taskPos = 0
    var taskMax = 1
    var taskCaption = ""
    var taskDisplay = ""
    var taskQueue: [String] = []

    // Experience
    var expPos = 0
    var expMax = 1269

    // Encumbrance (computed)
    var encumPos: Int { inventory.filter { $0.name != "Gold" }.reduce(0) { $0 + $1.qty } }
    var encumMax: Int { 10 + (stats["STR"] ?? 0) }

    // Online
    var passkey = 0
    var motto = ""
    var hostName = ""
    var hostAddr = ""
    var login = ""
    var password = ""
    var guild = ""
    var opts = 0

    // Game
    var gameStyle = 3
    var isRunning = false
    var savePath = ""

    // Internal
    private var questMonster = ""
    private var questMonsterTag = 0
    private var timer: Timer?
    private var lastTick: TimeInterval = 0

    // MARK: - Inventory helpers

    private func findInv(_ name: String) -> Int {
        if let idx = inventory.firstIndex(where: { $0.name == name }) { return idx }
        inventory.append(InventoryEntry(name: name, qty: 0))
        return inventory.count - 1
    }

    func getInv(_ name: String) -> Int {
        inventory.first(where: { $0.name == name })?.qty ?? 0
    }

    private func setInv(_ name: String, _ val: Int) {
        let idx = findInv(name)
        inventory[idx].qty = val
    }

    private func addInv(_ name: String, _ val: Int) {
        setInv(name, getInv(name) + val)
    }

    // MARK: - Spell helpers

    private func findSpell(_ name: String) -> Int {
        if let idx = spells.firstIndex(where: { $0.name == name }) { return idx }
        spells.append(SpellEntry(name: name, level: ""))
        return spells.count - 1
    }

    // MARK: - Equip price

    var equipPrice: Int { 5 * level * level + 10 * level + 20 }

    // MARK: - Item generation

    func specialItem() -> String { "\(interestingItem()) of \(pick(GameData.itemOfs))" }
    func interestingItem() -> String { "\(pick(GameData.itemAttrib)) \(pick(GameData.specials))" }
    func boringItem() -> String { pick(GameData.boringItems) }

    // MARK: - Named monster (for cinematics)

    private func namedMonster(_ level: Int) -> String {
        var bestName = "", bestLev = 0
        for _ in 0..<5 {
            let m = pick(GameData.monsters)
            let lev = Int(splitPipe(m, 1)) ?? 0
            if bestName.isEmpty || abs(level - lev) < abs(level - bestLev) {
                bestName = splitPipe(m, 0); bestLev = lev
            }
        }
        return "\(generateName()) the \(bestName)"
    }

    private func impressiveGuy() -> String {
        let title = pick(GameData.impressiveTitles)
        if Int.random(in: 0...1) == 0 {
            return "the \(title) of the \(plural(pick(GameData.races)))"
        }
        return "\(title) \(generateName()) of \(generateName())"
    }

    // MARK: - Monster task

    private func monsterTask() -> (display: String, duration: Int) {
        var targetLevel = level
        for _ in 0..<targetLevel {
            if odds(2, 5) { targetLevel += randSign() }
        }
        if targetLevel < 1 { targetLevel = 1 }

        var isDefinite = false
        var monsterName: String
        var lev: Int

        if odds(1, 25) {
            // NPC opponent
            monsterName = " " + pick(GameData.races)
            if odds(1, 2) {
                monsterName = "passing\(monsterName) \(pick(GameData.klasses))"
            } else {
                monsterName = "\(pickLow(GameData.titles)) \(generateName()) the\(monsterName)"
                isDefinite = true
            }
            lev = targetLevel
            taskCaption = "kill|\(monsterName)|\(targetLevel)|*"
        } else if !questMonster.isEmpty && odds(1, 4) && questMonsterTag >= 0 && questMonsterTag < GameData.monsters.count {
            let m = GameData.monsters[questMonsterTag]
            monsterName = splitPipe(m, 0)
            lev = Int(splitPipe(m, 1)) ?? 0
            taskCaption = "kill|\(monsterName)|\(lev)|\(splitPipe(m, 2))"
        } else {
            var m = pick(GameData.monsters)
            lev = Int(splitPipe(m, 1)) ?? 0
            for _ in 0..<5 {
                let m1 = pick(GameData.monsters)
                let l1 = Int(splitPipe(m1, 1)) ?? 0
                if abs(targetLevel - l1) < abs(targetLevel - lev) { m = m1; lev = Int(splitPipe(m, 1)) ?? 0 }
            }
            monsterName = splitPipe(m, 0)
            taskCaption = "kill|\(monsterName)|\(lev)|\(splitPipe(m, 2))"
        }

        var display = monsterName
        var qty = 1
        let diff = targetLevel - lev

        if diff > 10 {
            qty = (targetLevel + Int.random(in: 0..<max(lev, 1))) / max(lev, 1)
            if qty < 1 { qty = 1 }
            // targetLevel = targetLevel / qty  -- used for modifier calc below
        }

        let modLevel = qty > 1 ? targetLevel / qty : targetLevel

        if modLevel - lev <= -10 {
            display = "imaginary \(display)"
        } else if modLevel - lev < -5 {
            let i = max(0, 10 + (modLevel - lev))
            let j = 5 - Int.random(in: 0...i)
            display = sickPrefix(j, youngPrefix((lev - modLevel) - j, display))
        } else if modLevel - lev < 0 && Int.random(in: 0...1) == 1 {
            display = sickPrefix(modLevel - lev, display)
        } else if modLevel - lev < 0 {
            display = youngPrefix(modLevel - lev, display)
        } else if modLevel - lev >= 10 {
            display = "messianic \(display)"
        } else if modLevel - lev > 5 {
            let i = max(0, 10 - (modLevel - lev))
            let j = 5 - Int.random(in: 0...i)
            display = bigPrefix(j, specialPrefix((modLevel - lev) - j, display))
        } else if modLevel - lev > 0 && Int.random(in: 0...1) == 1 {
            display = bigPrefix(modLevel - lev, display)
        } else if modLevel - lev > 0 {
            display = specialPrefix(modLevel - lev, display)
        }

        let totalLev = (qty > 1 ? targetLevel / qty : targetLevel) * qty
        if !isDefinite { display = indefinite(display, qty) }
        let duration = (2 * gameStyle * totalLev * 1000) / level
        return (display, duration)
    }

    // MARK: - Rewards

    private func winSpell() {
        let wis = stats["WIS"] ?? 0
        let idx = randomLow(min(wis + level, GameData.spells.count))
        let name = GameData.spells[idx]
        let si = findSpell(name)
        let cur = romanToInt(spells[si].level)
        spells[si].level = intToRoman(cur + 1)
    }

    private func winEquip() {
        let posn = Int.random(in: 0..<equips.count)
        bestEquipIdx = posn

        let stuff: [String]
        var better: [String]
        let worse: [String]

        if posn == 0 {
            stuff = GameData.weapons; better = GameData.offenseAttrib; worse = GameData.offenseBad
        } else {
            better = GameData.defenseAttrib; worse = GameData.defenseBad
            stuff = posn == 1 ? GameData.shields : GameData.armors
        }

        let item = lpick(stuff, goal: level)
        let qual = Int(splitPipe(item, 1)) ?? 0
        var name = splitPipe(item, 0)
        var plus = level - qual
        if plus < 0 { better = worse }

        var count = 0
        while count < 2 && plus != 0 {
            let mod = pick(better)
            let modVal = Int(splitPipe(mod, 1)) ?? 0
            let modName = splitPipe(mod, 0)
            if name.contains(modName) { break }
            if abs(plus) < abs(modVal) { break }
            name = "\(modName) \(name)"
            plus -= modVal
            count += 1
        }
        if plus != 0 { name = "\(plus) \(name)" }
        if plus > 0 { name = "+\(name)" }
        equips[posn].item = name
    }

    private func winStat() {
        let statNames = ["STR", "CON", "DEX", "INT", "WIS", "CHA"]
        let i: Int
        if odds(1, 2) {
            i = Int.random(in: 0..<statNames.count)
        } else {
            let vals = statNames.map { stats[$0] ?? 0 }
            let total = vals.reduce(0) { $0 + $1 * $1 }
            if total == 0 {
                i = Int.random(in: 0..<statNames.count)
            } else {
                var t = Int.random(in: 0..<total)
                var idx = -1
                while t >= 0 { idx += 1; t -= vals[idx] * vals[idx] }
                i = idx
            }
        }
        stats[statNames[i], default: 0] += 1
    }

    private func winItem() {
        if max(250, Int.random(in: 0..<999)) < inventory.count {
            let name = inventory[Int.random(in: 0..<inventory.count)].name
            addInv(name, 1)
        } else {
            addInv(specialItem(), 1)
        }
    }

    // MARK: - Level up

    private func doLevelUp() {
        level += 1
        stats["HP Max", default: 0] += (stats["CON"] ?? 0) / 3 + 1 + Int.random(in: 0..<4)
        stats["MP Max", default: 0] += (stats["INT"] ?? 0) / 3 + 1 + Int.random(in: 0..<4)
        for _ in 0..<2 { winStat() }
        winSpell()
        expPos = 0
        expMax = levelUpTime(level)
        saveGame()
        doBrag("l")
    }

    // MARK: - Quest

    private func completeQuest() {
        questPos = 0
        questMax = 50 + Int.random(in: 0..<100)

        if !quests.isEmpty {
            quests[quests.count - 1].completed = true
            switch Int.random(in: 0..<4) {
            case 0: winSpell()
            case 1: winEquip()
            case 2: winStat()
            default: winItem()
            }
        }
        while quests.count > 99 { quests.removeFirst() }

        // New quest
        switch Int.random(in: 0..<5) {
        case 0:
            var bestM: String?, bestLev = 0, bestTag = 0
            for _ in 0..<4 {
                let tag = Int.random(in: 0..<GameData.monsters.count)
                let m = GameData.monsters[tag]
                let l = Int(splitPipe(m, 1)) ?? 0
                if bestM == nil || abs(l - level) < abs(bestLev - level) {
                    bestLev = l; bestM = m; bestTag = tag
                }
            }
            questMonster = bestM ?? ""; questMonsterTag = bestTag
            quests.append(QuestEntry(name: "Exterminate \(definite(splitPipe(questMonster, 0), 2))", completed: false))
        case 1:
            questMonster = ""
            quests.append(QuestEntry(name: "Seek \(definite(interestingItem(), 1))", completed: false))
        case 2:
            questMonster = ""
            quests.append(QuestEntry(name: "Deliver this \(boringItem())", completed: false))
        case 3:
            questMonster = ""
            quests.append(QuestEntry(name: "Fetch me \(indefinite(boringItem(), 1))", completed: false))
        default:
            var bestM: String?, bestLev = 0
            for _ in 0..<2 {
                let tag = Int.random(in: 0..<GameData.monsters.count)
                let m = GameData.monsters[tag]
                let l = Int(splitPipe(m, 1)) ?? 0
                if bestM == nil || abs(l - level) < abs(bestLev - level) {
                    bestLev = l; bestM = m
                }
            }
            questMonster = ""
            quests.append(QuestEntry(name: "Placate \(definite(splitPipe(bestM ?? "", 0), 2))", completed: false))
        }
        saveGame()
    }

    // MARK: - Plot

    private func completeAct() {
        plotPos = 0
        if !plots.isEmpty { plots[plots.count - 1].completed = true }
        let actNum = plots.count
        plotMax = 60 * 60 * (1 + 5 * actNum)
        plots.append(PlotEntry(name: "Act \(intToRoman(actNum))", completed: false))
        if actNum > 1 { winItem() }
        if actNum > 2 { winEquip() }
        saveGame()
        doBrag("a")
    }

    private func interplotCinematic() {
        switch Int.random(in: 0..<3) {
        case 0:
            q("task|1|Exhausted, you arrive at a friendly oasis in a hostile land")
            q("task|2|You greet old friends and meet new allies")
            q("task|2|You are privy to a council of powerful do-gooders")
            q("task|1|There is much to be done. You are chosen!")
        case 1:
            q("task|1|Your quarry is in sight, but a mighty enemy bars your path!")
            let nemesis = namedMonster(level + 3)
            q("task|4|A desperate struggle commences with \(nemesis)")
            var s = Int.random(in: 0..<3)
            for _ in 0..<Int.random(in: 0..<(1 + plots.count)) {
                s += 1 + Int.random(in: 0..<2)
                switch s % 3 {
                case 0: q("task|2|Locked in grim combat with \(nemesis)")
                case 1: q("task|2|\(nemesis) seems to have the upper hand")
                default: q("task|2|You seem to gain the advantage over \(nemesis)")
                }
            }
            q("task|3|Victory! \(nemesis) is slain! Exhausted, you lose conciousness")
            q("task|2|You awake in a friendly place, but the road awaits")
        default:
            let nemesis = impressiveGuy()
            q("task|2|Oh sweet relief! You've reached the kind protection of \(nemesis)")
            q("task|3|There is rejoicing, and an unnerving encouter with \(nemesis) in private")
            q("task|2|You forget your \(boringItem()) and go back to get it")
            q("task|2|What's this!? You overhear something shocking!")
            q("task|2|Could \(nemesis) be a dirty double-dealer?")
            q("task|3|Who can possibly be trusted with this news!? -- Oh yes, of course")
        }
        q("plot|2|Loading")
    }

    // MARK: - Task management

    private func q(_ s: String) { taskQueue.append(s) }

    private func setTask(_ caption: String, _ msec: Int) {
        taskDisplay = caption + "..."
        taskPos = 0
        taskMax = msec
    }

    private var taskDone: Bool { taskPos >= taskMax }

    private func dequeue() {
        while taskDone {
            // Process kill
            if taskCaption.hasPrefix("kill|") {
                let parts = taskCaption.components(separatedBy: "|")
                let loot = parts.count > 3 ? parts[3] : ""
                if loot == "*" {
                    winItem()
                } else if !loot.isEmpty {
                    addInv("\(parts[1]) \(properCase(loot))".lowercased(), 1)
                }
            } else if taskCaption == "buying" {
                addInv("Gold", -equipPrice)
                winEquip()
            } else if taskCaption == "market" || taskCaption == "sell" {
                if taskCaption == "sell" && inventory.count > 1 {
                    var sellPrice = inventory[1].qty * level
                    if inventory[1].name.contains(" of ") {
                        sellPrice *= (1 + randomLow(10)) * (1 + randomLow(level))
                    }
                    inventory.remove(at: 1)
                    addInv("Gold", sellPrice)
                }
                if inventory.count > 1 {
                    setTask("Selling \(indefinite(inventory[1].name, inventory[1].qty))", 1000)
                    taskCaption = "sell"
                    break
                }
            }

            let old = taskCaption
            taskCaption = ""

            if !taskQueue.isEmpty {
                let entry = taskQueue.removeFirst()
                let action = splitPipe(entry, 0)
                let dur = Int(splitPipe(entry, 1)) ?? 1
                var text = splitPipe(entry, 2)
                if action == "plot" {
                    completeAct()
                    text = "Loading \(plots.last?.name ?? "")"
                }
                setTask(text, dur * 1000)
            } else if encumPos >= encumMax {
                setTask("Heading to market to sell loot", 4000)
                taskCaption = "market"
            } else if !old.contains("kill|") && old != "heading" {
                if getInv("Gold") > equipPrice {
                    setTask("Negotiating purchase of better equipment", 5000)
                    taskCaption = "buying"
                } else {
                    setTask("Heading to the killing fields", 4000)
                    taskCaption = "heading"
                }
            } else {
                let (display, duration) = monsterTask()
                setTask("Executing \(display)", duration)
            }
        }
    }

    // MARK: - Timer tick

    func tick() {
        guard isRunning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        var elapsed = Int((now - lastTick) * 1000)
        lastTick = now
        if elapsed > 100 { elapsed = 100 }
        if elapsed < 0 { elapsed = 0 }

        if taskPos >= taskMax {
            let gain = taskCaption.hasPrefix("kill|")

            if gain {
                if expPos >= expMax { doLevelUp() }
                else { expPos += taskMax / 1000 }
            }

            if gain && plots.count > 1 {
                if questPos >= questMax { completeQuest() }
                else if !quests.isEmpty { questPos += taskMax / 1000 }
            }

            if plotPos >= plotMax && gain {
                interplotCinematic()
            } else if taskCaption != "load" {
                plotPos = min(plotPos + taskMax / 1000, plotMax)
            }

            dequeue()
        } else {
            taskPos += elapsed
        }
    }

    // MARK: - Character creation

    func createCharacter(name: String, race: String, klass: String, statValues: [String: Int]) {
        characterName = name
        self.race = race
        self.klass = klass
        level = 1
        stats = statValues
        stats["HP Max"] = Int.random(in: 0..<8) + (statValues["CON"] ?? 0) / 6
        stats["MP Max"] = Int.random(in: 0..<8) + (statValues["INT"] ?? 0) / 6

        equips = GameData.equipSlots.map { EquipEntry(slot: $0, item: "") }
        equips[0].item = "Sharp Stick"
        bestEquipIdx = 0
        spells = []
        inventory = [InventoryEntry(name: "Gold", qty: 0)]
        quests = []
        questMonster = ""
        questMonsterTag = 0
        plots = []
        taskQueue = []
        gameStyle = 3
        expPos = 0
        expMax = levelUpTime(1)
    }

    func startGame() {
        expPos = 0
        expMax = levelUpTime(1)
        taskCaption = "load"
        questMonster = ""
        taskQueue = []

        setTask("Loading", 2000)
        q("task|10|Experiencing an enigmatic and foreboding night vision")
        q("task|6|Much is revealed about that wise old bastard you'd underestimated")
        q("task|6|A shocking series of events leaves you alone and bewildered, but resolute")
        q("task|4|Drawing upon an unexpected reserve of determination, you set out on a long and dangerous journey")
        q("plot|2|Loading")

        plotMax = 26
        plots = [PlotEntry(name: "Prologue", completed: false)]

        isRunning = true
        lastTick = ProcessInfo.processInfo.systemUptime
        saveGame()
        doBrag("s")
    }

    func startTimer() {
        lastTick = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Online

    var hostAddrResolved: String {
        if !hostAddr.isEmpty { return hostAddr }
        if passkey != 0 { return PQServer.defaultHost }
        return ""
    }

    var bragTraits: [(String, String)] {
        [("n", characterName), ("r", race), ("c", klass), ("l", "\(level)")]
    }

    private var bestSpellStr: String {
        guard !spells.isEmpty else { return "" }
        var best = 0
        for i in 1..<spells.count {
            if (i + 1) * romanToInt(spells[i].level) > (best + 1) * romanToInt(spells[best].level) {
                best = i
            }
        }
        return "\(spells[best].name) \(spells[best].level)"
    }

    private var bestEquipStr: String {
        guard bestEquipIdx < equips.count else { return "" }
        var s = equips[bestEquipIdx].item
        if bestEquipIdx > 1 { s += "+" + equips[bestEquipIdx].slot }
        return s
    }

    private var bestStat: (name: String, val: Int) {
        let names = ["STR", "CON", "DEX", "INT", "WIS", "CHA"]
        var best = 0
        for i in 1..<names.count {
            if (stats[names[i]] ?? 0) > (stats[names[best]] ?? 0) { best = i }
        }
        return (names[best], stats[names[best]] ?? 0)
    }

    /// Last level successfully bragged to the server, keyed per character.
    private var lastBragLevelKey: String { "PQLastBragLevel_\(characterName)_\(hostName)" }
    private var lastBragLevel: Int {
        get { UserDefaults.standard.integer(forKey: lastBragLevelKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastBragLevelKey) }
    }

    func doBrag(_ trigger: String) {
        guard passkey != 0 else { return }

        // If the server is behind by more than 1 level, send incremental brags to catch up
        let serverLevel = lastBragLevel
        if serverLevel > 0 && level > serverLevel + 1 {
            for catchUpLevel in (serverLevel + 1)..<level {
                PQServer.sendBrag(
                    trigger: "l", traits: bragTraitsWithLevel(catchUpLevel), expPos: 0,
                    bestEquip: bestEquipStr, bestSpell: bestSpellStr,
                    bestStatName: bestStat.name, bestStatVal: bestStat.val,
                    currentAct: plots.last?.name ?? "Prologue", hostName: hostName,
                    hostAddr: hostAddrResolved, passkey: passkey, motto: motto
                )
            }
        }

        PQServer.sendBrag(
            trigger: trigger, traits: bragTraits, expPos: expPos,
            bestEquip: bestEquipStr, bestSpell: bestSpellStr,
            bestStatName: bestStat.name, bestStatVal: bestStat.val,
            currentAct: plots.last?.name ?? "Prologue", hostName: hostName,
            hostAddr: hostAddrResolved, passkey: passkey, motto: motto
        )
        lastBragLevel = level
    }

    private func bragTraitsWithLevel(_ lvl: Int) -> [(String, String)] {
        [("n", characterName), ("r", race), ("c", klass), ("l", "\(lvl)")]
    }

    // MARK: - Save / Load

    func gameSaveName() -> String {
        if savePath.isEmpty {
            var fn = characterName
            if !hostName.isEmpty { fn += " [\(hostName)]" }
            savePath = NSHomeDirectory() + "/" + fn + ".pq"
        }
        // Migrate legacy .pq.json paths to .pq
        if savePath.hasSuffix(".pq.json") {
            savePath = String(savePath.dropLast(5))
        }
        return savePath
    }

    func saveGame(to path: String? = nil) {
        if let path { savePath = path }
        let data = SaveData(
            name: characterName, race: race, klass: klass, level: level,
            stats: stats, equips: equips, bestEquipIdx: bestEquipIdx,
            spells: spells, inventory: inventory, quests: quests, plots: plots,
            questPos: questPos, questMax: questMax,
            questMonster: questMonster, questMonsterTag: questMonsterTag,
            plotPos: plotPos, plotMax: plotMax,
            taskPos: taskPos, taskMax: taskMax,
            taskCaption: taskCaption, taskDisplay: taskDisplay, taskQueue: taskQueue,
            expPos: expPos, expMax: expMax, gameStyle: gameStyle,
            passkey: passkey, motto: motto,
            hostName: hostName, hostAddr: hostAddr,
            login: login, password: password, guild: guild, opts: opts
        )
        let path = gameSaveName()
        try? DelphiSaveWriter.save(data, to: path)
    }

    func loadGame(_ path: String) throws {
        let d: SaveData
        let url = URL(fileURLWithPath: path)
        let rawData = try Data(contentsOf: url)

        if rawData.first == 0x7B { // starts with '{' — it's JSON regardless of extension
            d = try JSONDecoder().decode(SaveData.self, from: rawData)
        } else if rawData.first == 0x78 || rawData.first == 0x54 { // zlib (0x78) or raw "TPF0" (0x54)
            d = try DelphiSaveParser.load(path)
        } else {
            // Try JSON as fallback
            d = try JSONDecoder().decode(SaveData.self, from: rawData)
        }
        savePath = path
        characterName = d.name; race = d.race; klass = d.klass; level = d.level
        stats = d.stats; equips = d.equips; bestEquipIdx = d.bestEquipIdx
        spells = d.spells; inventory = d.inventory
        quests = d.quests; plots = d.plots
        questPos = d.questPos; questMax = d.questMax
        questMonster = d.questMonster; questMonsterTag = d.questMonsterTag
        plotPos = d.plotPos; plotMax = d.plotMax
        taskPos = d.taskPos; taskMax = d.taskMax
        taskCaption = d.taskCaption; taskDisplay = d.taskDisplay; taskQueue = d.taskQueue
        expPos = d.expPos; expMax = d.expMax; gameStyle = d.gameStyle
        passkey = d.passkey; motto = d.motto
        hostName = d.hostName; hostAddr = d.hostAddr
        login = d.login; password = d.password; guild = d.guild; opts = d.opts
        isRunning = true
        lastTick = ProcessInfo.processInfo.systemUptime
    }
}
