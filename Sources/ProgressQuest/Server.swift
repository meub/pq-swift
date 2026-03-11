import Foundation

/// Server communication protocol for Progress Quest online play.
enum PQServer {
    static let revString = "&rev=8"
    static let defaultHost = "http://www.progressquest.com/knoram.php?"

    // MARK: - LFSR authentication hash

    /// Compute the LFSR hash matching the Delphi implementation exactly.
    /// This is the authentication hash the PQ server uses to verify requests.
    static func lfsr(_ pt: String, salt: Int) -> Int {
        var r = UInt32(truncatingIfNeeded: salt)
        for ch in pt.utf8 {
            let feedback: UInt32 = 1 & ((r >> 31) ^ (r >> 5))
            r = UInt32(ch) ^ (r &<< 1) ^ feedback
        }
        for _ in 0..<10 {
            let feedback: UInt32 = 1 & ((r >> 31) ^ (r >> 5))
            r = (r &<< 1) ^ feedback
        }
        return Int(Int32(bitPattern: r))
    }

    // MARK: - URL encoding

    static func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? s
    }

    // MARK: - HTTP

    static func downloadString(_ urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("PQ6.4", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Realm list

    struct Realm {
        var name: String
        var opts: Int
        var host: String
        var desc: String
    }

    static func fetchRealmList(path: String = "") async throws -> (realms: [Realm], defaultRealm: String) {
        let url = "http://www.progressquest.com/list.php?" + revString + "&p=" + path
        let body = try await downloadString(url)
        var parts = body.components(separatedBy: "|")
        guard parts.first?.lowercased().trimmingCharacters(in: .whitespaces) == "ok" else {
            throw PQError.serverError(body)
        }
        parts.removeFirst()
        let def = parts.isEmpty ? "" : parts.removeFirst().trimmingCharacters(in: .whitespaces)
        var realms: [Realm] = []
        while parts.count >= 4 {
            realms.append(Realm(
                name: parts.removeFirst().trimmingCharacters(in: .whitespaces),
                opts: Int(parts.removeFirst().trimmingCharacters(in: .whitespaces)) ?? 0,
                host: parts.removeFirst().trimmingCharacters(in: .whitespaces),
                desc: parts.removeFirst().trimmingCharacters(in: .whitespaces)
            ))
        }
        return (realms, def)
    }

    // MARK: - Character creation

    static func createCharacter(hostAddr: String, name: String, realm: String,
                                opts: Int = 0) async throws -> Int {
        let baseURL = (opts & 16 != 0)
            ? "http://www.progressquest.com/create.php?"
            : hostAddr
        let args = "cmd=create&name=\(urlEncode(name))&realm=\(urlEncode(realm))\(revString)"
        let body = try await downloadString(baseURL + args)
        let parts = body.components(separatedBy: "|")
        guard parts.first?.lowercased().trimmingCharacters(in: .whitespaces) == "ok",
              parts.count > 1,
              let key = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
            throw PQError.serverError(body)
        }
        return key
    }

    // MARK: - Brag (status report)

    static func brag(trigger: String, traits: [(String, String)], expPos: Int,
                     bestEquip: String, bestSpell: String,
                     bestStatName: String, bestStatVal: Int,
                     currentAct: String, hostName: String,
                     hostAddr: String, passkey: Int,
                     motto: String = "") async {
        guard passkey != 0 else { return }
        let addr = hostAddr.isEmpty ? defaultHost : hostAddr

        var url = "cmd=b&t=\(trigger)"
        for (k, v) in traits {
            url += "&\(k)=\(urlEncode(v))"
        }
        url += "&x=\(expPos)"
        url += "&i=\(urlEncode(bestEquip))"
        url += "&z=\(urlEncode(bestSpell))"
        url += "&k=\(bestStatName)+\(bestStatVal)"
        url += "&a=\(urlEncode(currentAct))"
        url += "&h=\(urlEncode(hostName))"
        url += revString

        // LFSR hash covers everything up to here
        url += "&p=\(lfsr(url, salt: passkey))"
        url += "&m=\(urlEncode(motto))"

        _ = try? await downloadString(addr + url)
    }

    // MARK: - Guild

    static func guildify(traits: [(String, String)], hostName: String,
                         hostAddr: String, passkey: Int,
                         guild: String) async -> String? {
        guard passkey != 0 else { return nil }
        let addr = hostAddr.isEmpty ? defaultHost : hostAddr

        var url = "cmd=guild"
        for (k, v) in traits { url += "&\(k)=\(urlEncode(v))" }
        url += "&h=\(urlEncode(hostName))"
        url += revString
        url += "&guild=\(urlEncode(guild))"
        url += "&p=\(lfsr(url, salt: passkey))"

        guard let body = try? await downloadString(addr + url) else { return nil }
        let parts = body.components(separatedBy: "|")
        return parts.first?.trimmingCharacters(in: .whitespaces)
    }

    enum PQError: Error, LocalizedError {
        case serverError(String)
        var errorDescription: String? {
            switch self {
            case .serverError(let msg): return msg
            }
        }
    }
}

// Extend CharacterSet for URL query value encoding
private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._~")
        return cs
    }()
}
