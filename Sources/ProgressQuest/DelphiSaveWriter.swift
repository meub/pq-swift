import Foundation
import Compression

/// Writer for Delphi-compatible Progress Quest `.pq` save files.
/// Produces zlib-compressed binary component streams matching the original PQ format.
enum DelphiSaveWriter {

    // MARK: - Public API

    static func save(_ sd: SaveData, to path: String) throws {
        let stream = buildComponentStream(sd)
        let compressed = try zlibCompress(stream)
        try compressed.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    // MARK: - Value types

    private enum Value {
        case int(Int)
        case string(String)
        case binary(Data)
        case stringList([String])
    }

    // MARK: - Zlib compression

    private static func zlibCompress(_ data: Data) throws -> Data {
        let srcCount = data.count
        let dstSize = srcCount + srcCount / 10 + 256
        var dst = Data(count: dstSize)
        let written = data.withUnsafeBytes { srcBuf in
            dst.withUnsafeMutableBytes { dstBuf in
                compression_encode_buffer(
                    dstBuf.bindMemory(to: UInt8.self).baseAddress!,
                    dstSize,
                    srcBuf.bindMemory(to: UInt8.self).baseAddress!,
                    srcCount,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written > 0 else {
            throw DelphiSaveParser.PQLoadError.invalidFormat("Compression failed")
        }
        // zlib stream: header + deflate data + adler32
        var result = Data([0x78, 0x9C])
        result.append(dst.prefix(written))
        let cs = adler32(data)
        result.append(contentsOf: [
            UInt8((cs >> 24) & 0xFF), UInt8((cs >> 16) & 0xFF),
            UInt8((cs >> 8) & 0xFF), UInt8(cs & 0xFF),
        ])
        return result
    }

    private static func adler32(_ data: Data) -> UInt32 {
        var a: UInt32 = 1, b: UInt32 = 0
        for byte in data {
            a = (a &+ UInt32(byte)) % 65521
            b = (b &+ a) % 65521
        }
        return (b << 16) | a
    }

    // MARK: - Stream builder

    private static func buildComponentStream(_ sd: SaveData) -> Data {
        var out = Data()

        // Traits
        let traitRows: [LVRow] = [
            LVRow("Name", [sd.name]),
            LVRow("Race", [sd.race]),
            LVRow("Class", [sd.klass]),
            LVRow("Level", ["\(sd.level)"]),
        ]
        out.append(component("TListView", "Traits",
            lvProps(traitRows, tag: sd.passkey)))

        // Stats
        let statNames = ["STR", "CON", "DEX", "INT", "WIS", "CHA", "HP Max", "MP Max"]
        let statRows = statNames.map { LVRow($0, ["\(sd.stats[$0] ?? 0)"]) }
        var sp = lvProps(statRows)
        if !sd.motto.isEmpty { sp.append(("Hint", .string(sd.motto))) }
        out.append(component("TListView", "Stats", sp))

        // ExpBar
        out.append(component("TGauge", "ExpBar", [
            ("Position", .int(sd.expPos)), ("Max", .int(sd.expMax)),
        ]))

        // Spells
        let spellRows = sd.spells.map { LVRow($0.name, [$0.level]) }
        var slp = lvProps(spellRows)
        if !sd.hostName.isEmpty { slp.append(("Hint", .string(sd.hostName))) }
        out.append(component("TListView", "Spells", slp))

        // Equips
        let equipRows = sd.equips.map { LVRow($0.slot, [$0.item]) }
        var eqp = lvProps(equipRows, tag: sd.bestEquipIdx)
        if !sd.hostAddr.isEmpty { eqp.append(("Hint", .string(sd.hostAddr))) }
        out.append(component("TListView", "Equips", eqp))

        // Inventory
        let invRows = sd.inventory.map { LVRow($0.name, ["\($0.qty)"]) }
        var ivp = lvProps(invRows)
        if !sd.login.isEmpty { ivp.append(("Hint", .string(sd.login))) }
        out.append(component("TListView", "Inventory", ivp))

        // Quests
        let questRows = sd.quests.map { LVRow($0.name, [], $0.completed ? 1 : 0) }
        out.append(component("TListView", "Quests", lvProps(questRows)))

        // QuestBar
        out.append(component("TGauge", "QuestBar", [
            ("Position", .int(sd.questPos)), ("Max", .int(sd.questMax)),
        ]))

        // Plots
        let plotRows = sd.plots.map { LVRow($0.name, [], $0.completed ? 1 : 0) }
        var plp = lvProps(plotRows)
        if !sd.password.isEmpty { plp.append(("Hint", .string(sd.password))) }
        out.append(component("TListView", "Plots", plp))

        // PlotBar
        out.append(component("TGauge", "PlotBar", [
            ("Position", .int(sd.plotPos)), ("Max", .int(sd.plotMax)),
        ]))

        // fTask
        out.append(component("TLabel", "fTask", [
            ("Caption", .string(sd.taskCaption)),
        ]))

        // TaskBar
        out.append(component("TGauge", "TaskBar", [
            ("Position", .int(sd.taskPos)), ("Max", .int(sd.taskMax)),
        ]))

        // Kill
        out.append(component("TGauge", "Kill", [
            ("SimpleText", .string(sd.taskDisplay)),
        ]))

        // fQuest
        var fqp: [(String, Value)] = [("Caption", .string(sd.questMonster))]
        if sd.questMonsterTag != 0 { fqp.append(("Tag", .int(sd.questMonsterTag))) }
        out.append(component("TLabel", "fQuest", fqp))

        // fQueue
        var fqueueP: [(String, Value)] = []
        if !sd.taskQueue.isEmpty {
            fqueueP.append(("Items.Strings", .stringList(sd.taskQueue)))
        }
        out.append(component("TListBox", "fQueue", fqueueP))

        // InventoryLabelAlsoGameStyle
        out.append(component("TLabel", "InventoryLabelAlsoGameStyle", [
            ("Tag", .int(sd.gameStyle)),
        ]))

        // Label1
        var l1p: [(String, Value)] = []
        if !sd.guild.isEmpty { l1p.append(("Hint", .string(sd.guild))) }
        out.append(component("TLabel", "Label1", l1p))

        return out
    }

    // MARK: - Component encoding

    private static func component(_ className: String, _ name: String,
                                  _ props: [(String, Value)]) -> Data {
        var d = Data()
        d.append(contentsOf: [0x54, 0x50, 0x46, 0x30]) // "TPF0"
        d.append(shortStr(className))
        d.append(shortStr(name))
        for (pname, val) in props {
            d.append(shortStr(pname))
            d.append(encode(val))
        }
        d.append(0x00) // end properties
        d.append(0x00) // end children
        return d
    }

    private static func shortStr(_ s: String) -> Data {
        let b = Array(s.utf8)
        var d = Data()
        d.append(UInt8(min(b.count, 255)))
        d.append(contentsOf: b.prefix(255))
        return d
    }

    private static func encode(_ v: Value) -> Data {
        var d = Data()
        switch v {
        case .int(let n):
            if n >= 0 && n <= 255 {
                d.append(0x02) // vaInt8
                d.append(UInt8(n))
            } else if n >= 256 && n <= 65535 {
                d.append(0x03) // vaInt16
                d.append(UInt8(n & 0xFF))
                d.append(UInt8((n >> 8) & 0xFF))
            } else {
                d.append(0x04) // vaInt32
                let u = UInt32(bitPattern: Int32(truncatingIfNeeded: n))
                d.append(UInt8(u & 0xFF))
                d.append(UInt8((u >> 8) & 0xFF))
                d.append(UInt8((u >> 16) & 0xFF))
                d.append(UInt8((u >> 24) & 0xFF))
            }
        case .string(let s):
            let b = Array(s.utf8)
            if b.count <= 255 {
                d.append(0x06) // vaString
                d.append(shortStr(s))
            } else {
                d.append(0x0C) // vaLString
                appendU32(&d, UInt32(b.count))
                d.append(contentsOf: b)
            }
        case .binary(let data):
            d.append(0x0A) // vaBinary
            appendU32(&d, UInt32(data.count))
            d.append(data)
        case .stringList(let strings):
            d.append(0x01) // vaList
            for s in strings {
                d.append(0x06) // vaString
                d.append(shortStr(s))
            }
            d.append(0x00) // end list
        }
        return d
    }

    // MARK: - ListView data

    private struct LVRow {
        let caption: String
        let subItems: [String]
        let stateIndex: Int
        init(_ caption: String, _ subItems: [String], _ stateIndex: Int = 0) {
            self.caption = caption; self.subItems = subItems; self.stateIndex = stateIndex
        }
    }

    private static func lvProps(_ rows: [LVRow], tag: Int = 0) -> [(String, Value)] {
        var props: [(String, Value)] = [("Items.Data", .binary(buildLVData(rows)))]
        if tag != 0 { props.append(("Tag", .int(tag))) }
        return props
    }

    private static func buildLVData(_ rows: [LVRow]) -> Data {
        var items = Data()
        appendU32(&items, UInt32(rows.count))
        for row in rows {
            appendI32(&items, -1)                           // ImageIndex
            appendI32(&items, Int32(row.stateIndex))        // StateIndex
            appendI32(&items, -1)                           // GroupID
            appendI32(&items, Int32(row.subItems.count))    // SubItemCount
            appendI32(&items, 0)                            // flags
            let cap = Array(row.caption.utf8)
            items.append(UInt8(min(cap.count, 255)))
            items.append(contentsOf: cap.prefix(255))
            for sub in row.subItems {
                let sb = Array(sub.utf8)
                items.append(UInt8(min(sb.count, 255)))
                items.append(contentsOf: sb.prefix(255))
            }
        }
        var result = Data()
        appendU32(&result, UInt32(items.count))
        result.append(items)
        return result
    }

    private static func appendU32(_ d: inout Data, _ v: UInt32) {
        d.append(UInt8(v & 0xFF))
        d.append(UInt8((v >> 8) & 0xFF))
        d.append(UInt8((v >> 16) & 0xFF))
        d.append(UInt8((v >> 24) & 0xFF))
    }

    private static func appendI32(_ d: inout Data, _ v: Int32) {
        appendU32(&d, UInt32(bitPattern: v))
    }
}
