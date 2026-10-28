import Foundation

public struct Config {
    public var text: String
    public init(_ text: String) { self.text = text }
    public static let fields = ["Host", "HostName", "User", "Port", "IdentityFile", "ProxyJump"]
    public struct Block: Identifiable {
        public let id: Int
        public let end: Int
        public let name: String
        public let values: [String: String]
        public let editable: Bool
    }
    // Preserve the original document; only patch fields changed by the user.
    public var blocks: [Block] {
        let lines = text.components(separatedBy: "\n")
        let boundaries = lines.indices.filter { ["host", "match"].contains(Self.pair(lines[$0])?.0 ?? "") }
        return boundaries.enumerated().compactMap { n, start in
            guard let (key, name) = Self.pair(lines[start]), key == "host" else { return nil }
            let end = n + 1 < boundaries.count ? boundaries[n + 1] : lines.count
            var values = ["Host": name]
            var safe = name.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
            for i in (start + 1)..<end {
                guard let (k, v) = Self.pair(lines[i]) else { continue }
                if k == "include" { safe = false }
                if let field = Self.fields.first(where: { $0.lowercased() == k }) {
                    if values[field] != nil || v.contains("#") || v.contains("\"") || v.contains("\\") { safe = false }
                    values[field] = v
                }
            }
            if text.contains("\r") { safe = false }
            return Block(id: start, end: end, name: name, values: values, editable: safe)
        }
    }
    static func pair(_ line: String) -> (String, String)? {
        let s = line.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, !s.hasPrefix("#") else { return nil }
        let parts = s.split(maxSplits: 1, whereSeparator: { $0.isWhitespace || $0 == "=" })
        guard parts.count == 2 else { return nil }
        return (parts[0].lowercased(), String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: " \t=")))
    }
    public mutating func update(_ block: Block, values: [String: String]) throws {
        guard block.editable else { throw ConfigError.message("复杂配置请使用原文编辑。") }
        let alias = values["Host", default: ""]
        guard alias.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else { throw ConfigError.message("别名只能包含英文字母、数字、短横线和下划线。") }
        guard !blocks.contains(where: { $0.id != block.id && $0.name == alias }) else { throw ConfigError.message("别名已存在。") }
        let port = values["Port", default: ""]
        if !port.isEmpty && !(Int(port).map { (1...65535).contains($0) } ?? false) { throw ConfigError.message("端口应为 1–65535。") }
        for value in values.values where value.contains(where: { $0.isNewline }) || value.contains("#") { throw ConfigError.message("表单字段不能包含换行或 #。") }
        var lines = text.components(separatedBy: "\n")
        var slice = Array(lines[block.id..<block.end])
        for field in Self.fields where values[field, default: ""] != block.values[field, default: ""] {
            let value = values[field, default: ""]
            if let index = slice.firstIndex(where: { Self.pair($0)?.0 == field.lowercased() }) {
                if value.isEmpty { slice.remove(at: index) }
                else { slice[index] = (field == "Host" ? "" : "    ") + field + " " + value }
            } else if !value.isEmpty { slice.insert("    \(field) \(value)", at: 1) }
        }
        lines.replaceSubrange(block.id..<block.end, with: slice)
        text = lines.joined(separator: "\n")
    }
}
public enum ConfigError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}

public enum ConfigFile {
    public static func save(_ text: String, to url: URL, original: Data) throws {
        let fm = FileManager.default
        let info = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard info.isSymbolicLink != true else { throw ConfigError.message("请直接打开符号链接指向的真实文件。") }
        guard try Data(contentsOf: url) == original else { throw ConfigError.message("文件已被其他程序修改。请先导出当前草稿，再重新打开。") }
        let backup = url.deletingLastPathComponent().appendingPathComponent(".sshnote-backups", isDirectory: true)
        try fm.createDirectory(at: backup, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let snapshot = backup.appendingPathComponent(UUID().uuidString + ".config")
        try original.write(to: snapshot, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: snapshot.path)
        let attrs = try fm.attributesOfItem(atPath: url.path)
        try Data(text.utf8).write(to: url, options: .atomic)
        try fm.setAttributes([.posixPermissions: attrs[.posixPermissions] ?? 0o600], ofItemAtPath: url.path)
    }
}
