import Foundation
import Compression

/// Parser for original Progress Quest `.pq` save files.
/// These are zlib-compressed Delphi binary component streams.
/// Format: each component starts with ASCII "TPF0", then length-prefixed class name,
/// length-prefixed component name, properties terminated by 0x00, children terminated by 0x00.
enum DelphiSaveParser {

    // MARK: - Public API

    static func load(_ path: String) throws -> SaveData {
        let compressed = try Data(contentsOf: URL(fileURLWithPath: path))
        let raw = try zlibDecompress(compressed)
        let components = try parseComponents(raw)
        return try extractSaveData(components)
    }

    // MARK: - Zlib decompression

    private static func zlibDecompress(_ data: Data) throws -> Data {
        // Strip 2-byte zlib header (78 xx), decompress raw deflate
        guard data.count > 2, data[data.startIndex] == 0x78 else {
            throw PQLoadError.invalidFormat("Not a zlib stream")
        }
        let deflateData = data.dropFirst(2)
        return try deflateData.withUnsafeBytes { srcBuf -> Data in
            let srcPtr = srcBuf.bindMemory(to: UInt8.self).baseAddress!
            let dstSize = data.count * 20
            let dstPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
            defer { dstPtr.deallocate() }
            let written = compression_decode_buffer(
                dstPtr, dstSize, srcPtr, deflateData.count, nil, COMPRESSION_ZLIB
            )
            guard written > 0 else {
                throw PQLoadError.invalidFormat("Zlib decompression failed")
            }
            return Data(bytes: dstPtr, count: written)
        }
    }

    // MARK: - Binary DFM parser

    private struct DFMComponent {
        var className: String
        var name: String
        var properties: [String: DFMValue]
    }

    private enum DFMValue {
        case int(Int)
        case string(String)
        case bool(Bool)
        case binary(Data)
        case list([DFMValue])
        case ident(String)
        case set([String])
        case skip
    }

    private struct Reader {
        let data: Data
        var pos: Int = 0

        var remaining: Int { data.count - pos }

        mutating func peekByte() throws -> UInt8 {
            guard pos < data.count else { throw PQLoadError.unexpectedEOF }
            return data[data.startIndex + pos]
        }

        mutating func readByte() throws -> UInt8 {
            guard pos < data.count else { throw PQLoadError.unexpectedEOF }
            let b = data[data.startIndex + pos]
            pos += 1
            return b
        }

        mutating func readBytes(_ n: Int) throws -> Data {
            guard pos + n <= data.count else { throw PQLoadError.unexpectedEOF }
            let slice = data[(data.startIndex + pos)..<(data.startIndex + pos + n)]
            pos += n
            return Data(slice)
        }

        mutating func readUInt16LE() throws -> UInt16 {
            let bytes = try readBytes(2)
            return UInt16(bytes[bytes.startIndex]) | (UInt16(bytes[bytes.startIndex + 1]) << 8)
        }

        mutating func readInt32LE() throws -> Int32 {
            let bytes = try readBytes(4)
            var val: UInt32 = 0
            for i in 0..<4 {
                val |= UInt32(bytes[bytes.startIndex + i]) << (i * 8)
            }
            return Int32(bitPattern: val)
        }

        mutating func readUInt32LE() throws -> UInt32 {
            let bytes = try readBytes(4)
            var val: UInt32 = 0
            for i in 0..<4 {
                val |= UInt32(bytes[bytes.startIndex + i]) << (i * 8)
            }
            return val
        }

        mutating func readShortString() throws -> String {
            let len = Int(try readByte())
            if len == 0 { return "" }
            let bytes = try readBytes(len)
            return String(data: bytes, encoding: .ascii) ?? String(data: bytes, encoding: .utf8) ?? ""
        }

        mutating func readLongString() throws -> String {
            let len = Int(try readUInt32LE())
            if len == 0 { return "" }
            let bytes = try readBytes(len)
            return String(data: bytes, encoding: .utf8) ?? String(data: bytes, encoding: .ascii) ?? ""
        }

        /// Check if the next 4 bytes are "TPF0" without advancing.
        func peekIsTPF0() -> Bool {
            guard pos + 4 <= data.count else { return false }
            let s = data.startIndex + pos
            return data[s] == 0x54 && data[s+1] == 0x50 && data[s+2] == 0x46 && data[s+3] == 0x30
        }
    }

    // MARK: - Component stream parsing

    private static let tpf0: [UInt8] = [0x54, 0x50, 0x46, 0x30] // "TPF0"

    private static func parseComponents(_ data: Data) throws -> [DFMComponent] {
        var reader = Reader(data: data)
        var components: [DFMComponent] = []

        while reader.remaining >= 4 && reader.peekIsTPF0() {
            // Consume "TPF0" signature
            _ = try reader.readBytes(4)

            let comp = try parseOneComponent(&reader)
            components.append(comp)
        }

        guard !components.isEmpty else {
            throw PQLoadError.invalidFormat("No components found")
        }
        return components
    }

    private static func parseOneComponent(_ reader: inout Reader) throws -> DFMComponent {
        // No flag byte — directly class name then component name
        let className = try reader.readShortString()
        let name = try reader.readShortString()
        var props: [String: DFMValue] = [:]

        // Read properties until 0x00
        while true {
            let peek = try reader.readByte()
            if peek == 0x00 { break }
            // peek is the first byte of the property name (length)
            reader.pos -= 1
            let propName = try reader.readShortString()
            let value = try readValue(&reader)
            props[propName] = value
        }

        // End-of-children marker (0x00)
        if reader.remaining > 0 && !reader.peekIsTPF0() {
            let b = try reader.readByte()
            if b != 0x00 {
                reader.pos -= 1
            }
        }

        return DFMComponent(className: className, name: name, properties: props)
    }

    private static func readValue(_ reader: inout Reader) throws -> DFMValue {
        let tag = try reader.readByte()
        switch tag {
        case 0x01: // vaList
            var items: [DFMValue] = []
            while true {
                let peek = try reader.readByte()
                if peek == 0x00 { break }
                reader.pos -= 1
                items.append(try readValue(&reader))
            }
            return .list(items)
        case 0x02: // vaInt8
            return .int(Int(try reader.readByte()))
        case 0x03: // vaInt16
            let val = try reader.readUInt16LE()
            return .int(Int(Int16(bitPattern: val)))
        case 0x04: // vaInt32
            return .int(Int(try reader.readInt32LE()))
        case 0x05: // vaExtended (10 bytes)
            _ = try reader.readBytes(10)
            return .skip
        case 0x06: // vaString (short)
            return .string(try reader.readShortString())
        case 0x07: // vaIdent
            return .ident(try reader.readShortString())
        case 0x08: // vaFalse
            return .bool(false)
        case 0x09: // vaTrue
            return .bool(true)
        case 0x0A: // vaBinary
            let len = Int(try reader.readUInt32LE())
            return .binary(try reader.readBytes(len))
        case 0x0B: // vaSet
            var items: [String] = []
            while true {
                let s = try reader.readShortString()
                if s.isEmpty { break }
                items.append(s)
            }
            return .set(items)
        case 0x0C: // vaLString
            return .string(try reader.readLongString())
        case 0x0D: // vaNil
            return .skip
        case 0x0E: // vaCollection
            while true {
                let marker = try reader.readByte()
                if marker == 0x00 { break }
                // Each collection item has properties terminated by 0x00
                while true {
                    let propPeek = try reader.readByte()
                    if propPeek == 0x00 { break }
                    reader.pos -= 1
                    _ = try reader.readShortString()
                    _ = try readValue(&reader)
                }
            }
            return .skip
        case 0x10: // vaSingle (4 bytes)
            _ = try reader.readBytes(4)
            return .skip
        case 0x11: // vaCurrency (8 bytes)
            _ = try reader.readBytes(8)
            return .skip
        case 0x12: // vaDate (8 bytes)
            _ = try reader.readBytes(8)
            return .skip
        case 0x13: // vaWString
            let charCount = Int(try reader.readUInt32LE())
            _ = try reader.readBytes(charCount * 2)
            return .skip
        case 0x14: // vaInt64
            let lo = try reader.readUInt32LE()
            let hi = try reader.readUInt32LE()
            return .int(Int(Int64(hi) << 32 | Int64(lo)))
        case 0x15: // vaUTF8String
            return .string(try reader.readLongString())
        default:
            throw PQLoadError.invalidFormat("Unknown DFM value tag: 0x\(String(tag, radix: 16)) at offset \(reader.pos - 1)")
        }
    }

    // MARK: - TListView Items.Data parser

    private struct ListViewRow {
        var caption: String
        var subItems: [String]
        var stateIndex: Int
    }

    private static func parseListViewData(_ data: Data) throws -> [ListViewRow] {
        guard data.count >= 8 else { return [] }
        var reader = Reader(data: data)
        _ = try reader.readUInt32LE() // total size
        let count = Int(try reader.readUInt32LE())

        var rows: [ListViewRow] = []
        for _ in 0..<count {
            _ = try reader.readInt32LE()  // ImageIndex
            let stateIdx = Int(try reader.readInt32LE()) // StateIndex
            _ = try reader.readInt32LE()  // GroupID
            let subItemCount = Int(try reader.readInt32LE())
            _ = try reader.readInt32LE()  // flags

            let captionLen = Int(try reader.readByte())
            let captionData = captionLen > 0 ? try reader.readBytes(captionLen) : Data()
            let caption = String(data: captionData, encoding: .utf8) ?? ""

            var subItems: [String] = []
            for _ in 0..<subItemCount {
                let subLen = Int(try reader.readByte())
                let subData = subLen > 0 ? try reader.readBytes(subLen) : Data()
                subItems.append(String(data: subData, encoding: .utf8) ?? "")
            }

            rows.append(ListViewRow(caption: caption, subItems: subItems, stateIndex: stateIdx))
        }
        return rows
    }

    // MARK: - Extract SaveData from parsed components

    private static func extractSaveData(_ components: [DFMComponent]) throws -> SaveData {
        var byName: [String: DFMComponent] = [:]
        for c in components { byName[c.name] = c }

        var sd = SaveData()

        // --- Traits (character name, race, class, level) ---
        if let traits = byName["Traits"] {
            if let rows = try listViewRows(traits, "Items.Data") {
                if rows.count >= 4 {
                    sd.name = rows[0].subItems.first ?? ""
                    sd.race = rows[1].subItems.first ?? ""
                    sd.klass = rows[2].subItems.first ?? ""
                    sd.level = Int(rows[3].subItems.first ?? "1") ?? 1
                }
            }
            sd.passkey = intProp(traits, "Tag")
        }

        // --- Stats ---
        if let stats = byName["Stats"] {
            if let rows = try listViewRows(stats, "Items.Data") {
                let names = ["STR", "CON", "DEX", "INT", "WIS", "CHA", "HP Max", "MP Max"]
                for (i, name) in names.enumerated() where i < rows.count {
                    sd.stats[name] = Int(rows[i].subItems.first ?? "0") ?? 0
                }
            }
            sd.motto = stringProp(stats, "Hint")
        }

        // --- Experience ---
        if let exp = byName["ExpBar"] {
            sd.expPos = intProp(exp, "Position")
            sd.expMax = intProp(exp, "Max", default: 100)
        }

        // --- Spells ---
        if let spells = byName["Spells"] {
            if let rows = try listViewRows(spells, "Items.Data") {
                sd.spells = rows.map { SpellEntry(name: $0.caption, level: $0.subItems.first ?? "I") }
            }
            sd.hostName = stringProp(spells, "Hint")
        }

        // --- Equipment ---
        if let equips = byName["Equips"] {
            if let rows = try listViewRows(equips, "Items.Data") {
                sd.equips = rows.map { EquipEntry(slot: $0.caption, item: $0.subItems.first ?? "") }
            }
            sd.bestEquipIdx = intProp(equips, "Tag")
            sd.hostAddr = stringProp(equips, "Hint")
        }

        // --- Inventory ---
        if let inv = byName["Inventory"] {
            if let rows = try listViewRows(inv, "Items.Data") {
                sd.inventory = rows.map {
                    InventoryEntry(name: $0.caption, qty: Int($0.subItems.first ?? "0") ?? 0)
                }
            }
            sd.login = stringProp(inv, "Hint")
        }

        // --- Quests ---
        if let quests = byName["Quests"] {
            if let rows = try listViewRows(quests, "Items.Data") {
                sd.quests = rows.map { QuestEntry(name: $0.caption, completed: $0.stateIndex == 1) }
            }
        }
        if let questBar = byName["QuestBar"] {
            sd.questPos = intProp(questBar, "Position")
            sd.questMax = intProp(questBar, "Max", default: 100)
        }

        // --- Plots ---
        if let plots = byName["Plots"] {
            if let rows = try listViewRows(plots, "Items.Data") {
                sd.plots = rows.map { PlotEntry(name: $0.caption, completed: $0.stateIndex == 1) }
            }
            sd.password = stringProp(plots, "Hint")
        }
        if let plotBar = byName["PlotBar"] {
            sd.plotPos = intProp(plotBar, "Position")
            sd.plotMax = intProp(plotBar, "Max", default: 26)
        }

        // --- Task state ---
        if let fTask = byName["fTask"] {
            sd.taskCaption = stringProp(fTask, "Caption")
        }
        if let taskBar = byName["TaskBar"] {
            sd.taskPos = intProp(taskBar, "Position")
            sd.taskMax = intProp(taskBar, "Max", default: 1)
        }
        if let kill = byName["Kill"] {
            sd.taskDisplay = stringProp(kill, "SimpleText")
        }

        // --- Quest monster ---
        if let fQuest = byName["fQuest"] {
            sd.questMonster = stringProp(fQuest, "Caption")
            sd.questMonsterTag = intProp(fQuest, "Tag")
        }

        // --- Task queue ---
        if let fQueue = byName["fQueue"] {
            if case .list(let items) = fQueue.properties["Items.Strings"] {
                sd.taskQueue = items.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
            }
        }

        // --- Game style ---
        if let invLabel = byName["InventoryLabelAlsoGameStyle"] {
            sd.gameStyle = intProp(invLabel, "Tag", default: 3)
        }

        // --- Guild ---
        if let label1 = byName["Label1"] {
            sd.guild = stringProp(label1, "Hint")
        }

        return sd
    }

    // MARK: - Helpers

    private static func intProp(_ comp: DFMComponent, _ name: String, default def: Int = 0) -> Int {
        guard let val = comp.properties[name] else { return def }
        if case .int(let n) = val { return n }
        return def
    }

    private static func stringProp(_ comp: DFMComponent, _ name: String) -> String {
        guard let val = comp.properties[name] else { return "" }
        if case .string(let s) = val { return s }
        if case .ident(let s) = val { return s }
        return ""
    }

    private static func listViewRows(_ comp: DFMComponent, _ name: String) throws -> [ListViewRow]? {
        guard let val = comp.properties[name] else { return nil }
        if case .binary(let data) = val {
            return try parseListViewData(data)
        }
        return nil
    }

    enum PQLoadError: Error, LocalizedError {
        case invalidFormat(String)
        case unexpectedEOF

        var errorDescription: String? {
            switch self {
            case .invalidFormat(let msg): return "Invalid .pq file: \(msg)"
            case .unexpectedEOF: return "Unexpected end of .pq file"
            }
        }
    }
}
