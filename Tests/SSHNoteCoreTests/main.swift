import Foundation
import SSHNoteCore
final class ConfigTests {
    func testPatchPreservesOtherText() throws {
        let source = "# header\nHost demo\n\tHostName old\n    User root\n    CustomOption value\n\nHost *\n    ServerAliveInterval 30\n"
        var c = Config(source); let b = c.blocks[0]
        try c.update(b, values: b.values); XCTAssertEqual(c.text, source)
        var values = b.values; values["HostName"] = "example.com"
        try c.update(b, values: values)
        XCTAssertEqual(c.text, source.replacingOccurrences(of: "\tHostName old", with: "    HostName example.com"))
    }
    func testComplexBlocks() {
        for source in ["Host *\n User root\n", "Host demo\n Include other\n", "Host demo\n IdentityFile one\n IdentityFile two\n", "Host demo\n HostName a # comment\n"] {
            XCTAssertFalse(Config(source).blocks[0].editable)
        }
        XCTAssertEqual(Config("Host demo\n HostName a\nMatch all\n User b\n").blocks[0].values["User"], nil)
    }
    func testRejectsBadInput() throws {
        var c = Config("Host demo\n HostName example.com\n")
        let b = c.blocks[0]; var v = b.values; v["Port"] = "70000"
        XCTAssertThrowsError(try c.update(b, values: v))
        v = b.values; v["HostName"] = "a\nHost injected"
        XCTAssertThrowsError(try c.update(b, values: v))
    }
    func testBackupConflictAndPermissions() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("config"), original = Data("Host demo\n".utf8)
        try original.write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        try ConfigFile.save("Host changed\n", to: file, original: original)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "Host changed\n")
        let backups = try FileManager.default.contentsOfDirectory(at: dir.appendingPathComponent(".sshnote-backups"), includingPropertiesForKeys: nil)
        XCTAssertEqual(try Data(contentsOf: backups[0]), original)
        XCTAssertThrowsError(try ConfigFile.save("Host overwrite", to: file, original: original))
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int, 0o600)
        let link = dir.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try ConfigFile.save("bad", to: link, original: Data("Host changed\n".utf8)))
    }
}

func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a == b, "Values differ") }
func XCTAssertFalse(_ value: Bool) { precondition(!value) }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T) {
    do { _ = try expression() } catch { return }
    preconditionFailure("Expected error")
}
let checks = ConfigTests()
try checks.testPatchPreservesOtherText()
checks.testComplexBlocks()
try checks.testRejectsBadInput()
try checks.testBackupConflictAndPermissions()
print("4 core checks passed: text preservation, complex syntax, input validation, backup/conflict/permissions/symlinks")
