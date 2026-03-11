import Foundation
import SwiftUI
import AppKit

// MARK: - Window configurator

/// NSViewRepresentable that configures the hosting NSWindow on appear.
struct WindowConfigurator: NSViewRepresentable {
    var resizable: Bool
    var size: NSSize?

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if resizable {
                window.styleMask.insert(.resizable)
            } else {
                window.styleMask.remove(.resizable)
                if let size {
                    window.setContentSize(size)
                }
            }
        }
    }
}

// MARK: - Pipe-delimited field access

func splitPipe(_ s: String, _ field: Int) -> String {
    let parts = s.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    return field < parts.count ? parts[field] : (parts.last ?? "")
}

// MARK: - Random helpers

func pick<T>(_ array: [T]) -> T { array[Int.random(in: 0..<array.count)] }

func pickLow<T>(_ array: [T]) -> T {
    array[min(Int.random(in: 0..<array.count), Int.random(in: 0..<array.count))]
}

func randomLow(_ below: Int) -> Int {
    min(Int.random(in: 0..<below), Int.random(in: 0..<below))
}

func odds(_ chance: Int, _ outof: Int) -> Bool {
    Int.random(in: 0..<outof) < chance
}

func randSign() -> Int { Int.random(in: 0...1) * 2 - 1 }

// MARK: - English helpers

func plural(_ s: String) -> String {
    if s.hasSuffix("y") { return String(s.dropLast()) + "ies" }
    if s.hasSuffix("us") { return String(s.dropLast(2)) + "i" }
    if s.hasSuffix("ch") || s.hasSuffix("x") || s.hasSuffix("s") { return s + "es" }
    if s.hasSuffix("f") { return String(s.dropLast()) + "ves" }
    if s.hasSuffix("man") || s.hasSuffix("Man") { return String(s.dropLast(2)) + "en" }
    return s + "s"
}

func indefinite(_ s: String, _ qty: Int) -> String {
    if qty == 1 {
        let first = s.first.map(String.init) ?? ""
        return "AEIOUaeiou".contains(first) ? "an \(s)" : "a \(s)"
    }
    return "\(qty) \(plural(s))"
}

func definite(_ s: String, _ qty: Int) -> String {
    let noun = qty > 1 ? plural(s) : s
    return "the \(noun)"
}

func properCase(_ s: String) -> String {
    guard let first = s.first else { return s }
    return first.uppercased() + s.dropFirst()
}

// MARK: - Monster modifier prefixes

func sickPrefix(_ m: Int, _ s: String) -> String {
    switch abs(m) {
    case 5: return "dead \(s)"
    case 4: return "comatose \(s)"
    case 3: return "crippled \(s)"
    case 2: return "sick \(s)"
    case 1: return "undernourished \(s)"
    default: return "\(m)\(s)"
    }
}

func youngPrefix(_ m: Int, _ s: String) -> String {
    switch abs(m) {
    case 5: return "foetal \(s)"
    case 4: return "baby \(s)"
    case 3: return "preadolescent \(s)"
    case 2: return "teenage \(s)"
    case 1: return "underage \(s)"
    default: return "\(m)\(s)"
    }
}

func bigPrefix(_ m: Int, _ s: String) -> String {
    switch abs(m) {
    case 1: return "greater \(s)"
    case 2: return "massive \(s)"
    case 3: return "enormous \(s)"
    case 4: return "giant \(s)"
    case 5: return "titanic \(s)"
    default: return s
    }
}

func specialPrefix(_ m: Int, _ s: String) -> String {
    switch abs(m) {
    case 1: return s.contains(" ") ? "veteran \(s)" : "Battle-\(s)"
    case 2: return "cursed \(s)"
    case 3: return s.contains(" ") ? "warrior \(s)" : "Were-\(s)"
    case 4: return "undead \(s)"
    case 5: return "demon \(s)"
    default: return s
    }
}

// MARK: - Roman numerals (extended: A=5000, T=10000)

private let romanEncode: [(Int, String)] = [
    (10000,"T"),(9000,"MT"),(5000,"A"),(4000,"MA"),
    (1000,"M"),(900,"CM"),(500,"D"),(400,"CD"),
    (100,"C"),(90,"XC"),(50,"L"),(40,"XL"),
    (10,"X"),(9,"IX"),(5,"V"),(4,"IV"),(1,"I"),
]

private let romanDecode: [(String, Int)] = [
    ("T",10000),("MT",9000),("A",5000),("MA",4000),
    ("M",1000),("CM",900),("D",500),("CD",400),
    ("C",100),("XC",90),("L",50),("XL",40),
    ("X",10),("IX",9),("V",5),("IV",4),("I",1),
]

func intToRoman(_ n: Int) -> String {
    var n = n
    var result = ""
    for (val, sym) in romanEncode {
        while n >= val { result += sym; n -= val }
    }
    return result
}

func romanToInt(_ s: String) -> Int {
    var s = s
    var result = 0
    for (sym, val) in romanDecode {
        while s.hasPrefix(sym) {
            result += val
            s = String(s.dropFirst(sym.count))
        }
    }
    return result
}

// MARK: - Name generation

private let kParts = [
    "br|cr|dr|fr|gr|j|kr|l|m|n|pr||||r|sh|tr|v|wh|x|y|z",
    "a|a|e|e|i|i|o|o|u|u|ae|ie|oo|ou",
    "b|ck|d|g|k|m|n|p|t|v|x|z",
]

func generateName() -> String {
    var result = ""
    for i in 0..<6 {
        let parts = kParts[i % 3].split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        result += parts[Int.random(in: 0..<parts.count)]
    }
    guard !result.isEmpty else { return result }
    return result.prefix(1).uppercased() + result.dropFirst()
}

// MARK: - Level timing

func levelUpTime(_ level: Int) -> Int {
    Int((20.0 + pow(1.15, Double(level))) * 60.0)
}

// MARK: - Level-matched pick

func lpick(_ list: [String], goal: Int) -> String {
    var best = pick(list)
    for _ in 0..<5 {
        let bestLev = Int(splitPipe(best, 1)) ?? 0
        let s = pick(list)
        let sLev = Int(splitPipe(s, 1)) ?? 0
        if abs(goal - bestLev) > abs(goal - sLev) { best = s }
    }
    return best
}

// MARK: - Rough time display

func roughTime(_ seconds: Int) -> String {
    if seconds < 120 { return "\(seconds) seconds" }
    if seconds < 60 * 120 { return "\(seconds / 60) minutes" }
    if seconds < 60 * 60 * 48 { return "\(seconds / 3600) hours" }
    return "\(seconds / (3600 * 24)) days"
}
