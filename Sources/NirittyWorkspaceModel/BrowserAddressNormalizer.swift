import Foundation

public enum BrowserAddressNormalizer {
    public static func normalizedURL(from addressText: String) -> URL? {
        let trimmed = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.lowercased() == "about:blank" {
            return URL(string: "about:blank")
        }

        if trimmed.contains("://") {
            return URL(string: trimmed)
        }

        let scheme = usesLocalHTTPDefault(trimmed) ? "http" : "https"
        return URL(string: "\(scheme)://\(trimmed)")
    }

    private static func usesLocalHTTPDefault(_ addressText: String) -> Bool {
        let host = hostPortion(of: addressText).lowercased()
        return host == "localhost"
            || host.hasSuffix(".localhost")
            || isIPv4Address(host)
            || isBracketedIPv6Address(host)
    }

    private static func hostPortion(of addressText: String) -> String {
        let hostAndPort = addressText.split(
            whereSeparator: { character in
                character == "/" || character == "?" || character == "#"
            }
        ).first.map(String.init) ?? addressText

        if hostAndPort.hasPrefix("["),
           let closingBracketIndex = hostAndPort.firstIndex(of: "]") {
            return String(hostAndPort[...closingBracketIndex])
        }

        return hostAndPort.split(separator: ":", maxSplits: 1).first.map(String.init) ?? hostAndPort
    }

    private static func isIPv4Address(_ host: String) -> Bool {
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else {
            return false
        }

        return octets.allSatisfy { octet in
            guard let value = Int(octet), value >= 0, value <= 255 else {
                return false
            }

            return String(value) == octet || octet == "0"
        }
    }

    private static func isBracketedIPv6Address(_ host: String) -> Bool {
        host.hasPrefix("[") && host.hasSuffix("]") && host.contains(":")
    }
}
