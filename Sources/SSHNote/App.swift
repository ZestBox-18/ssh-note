import SwiftUI
import AppKit
import SSHNoteCore

@MainActor final class Editor: ObservableObject {
    @Published var text = ""
    @Published var url: URL?
    @Published var selected: Int?
    @Published var message = "保存后，下次 SSH 连接生效。"
    @Published var fields: [String: String] = [:]
    var original = Data()
var displayPath: String { url?.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~") ?? "未打开文件" }
var canCopyCommand: Bool { fields["Host", default: ""].range(of: #"^[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil }
func copyCommand() {
    guard canCopyCommand else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString("ssh " + fields["Host", default: ""], forType: .string)
    message = "已复制 SSH 命令。"
}
func chooseKey() {
    let panel = NSOpenPanel(); panel.showsHiddenFiles = true
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
    if panel.runModal() == .OK, let file = panel.url {
        let path = file.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path + "/", with: "~/")
        guard !path.contains(where: { $0.isWhitespace }) else { message = "路径包含空格，请在原文中使用带引号的 IdentityFile。"; return }
        fields["IdentityFile"] = path
    }
}
var previewText: String {
    guard let block = blocks.first(where: { $0.id == selected }) else { return "" }
    var config = Config(text)
    if formDirty {
        do { try config.update(block, values: fields) }
        catch { return "尚不能保存：" + error.localizedDescription }
    }
    let lines = config.text.components(separatedBy: "\n")
    guard let updated = config.blocks.first(where: { $0.id == block.id }) else { return "" }
    return lines[updated.id..<updated.end].joined(separator: "\n").trimmingCharacters(in: .newlines)
}
init() {
    if ProcessInfo.processInfo.arguments.contains("--preview") {
        text = "Host personal-vps\n    HostName example.com\n    User deploy\n    Port 22\n    IdentityFile ~/.ssh/id_ed25519\n\nHost home-lab\n    HostName lab.example.com\n    User admin\n\nHost dev-box\n    HostName dev.example.com\n    User developer\n"
        original = Data(text.utf8); selected = 0; refreshFields(); message = "设计预览 · 示例数据，不会写入本机配置。"; return
    }
        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/config").resolvingSymlinksInPath()
        if FileManager.default.fileExists(atPath: file.path) { load(file) }
        else { message = "未找到 ~/.ssh/config，请打开已有配置文件。" }
    }
    var formDirty: Bool {
        guard let block = blocks.first(where: { $0.id == selected }) else { return false }
        return Config.fields.contains { fields[$0, default: ""] != block.values[$0, default: ""] }
    }
    func refreshFields() { fields = blocks.first(where: { $0.id == selected })?.values ?? [:] }
    @discardableResult func applyForm() -> Bool {
        guard formDirty, let block = blocks.first(where: { $0.id == selected }) else { return true }
        do { var config = Config(text); try config.update(block, values: fields); text = config.text; refreshFields(); message = "保存后，下次 SSH 连接生效。"; return true }
        catch { message = error.localizedDescription; return false }
    }
func select(_ id: Int) {
    guard let index = blocks.firstIndex(where: { $0.id == id }), applyForm() else { return }
    selected = blocks.indices.contains(index) ? blocks[index].id : blocks.first?.id
    refreshFields()
}
    var dirty: Bool { Data(text.utf8) != original || formDirty }
    var blocks: [Config.Block] { Config(text).blocks }
    func discardAllowed() -> Bool {
        guard dirty else { return true }
        let a = NSAlert(); a.messageText = "放弃未保存的修改？"; a.addButton(withTitle: "取消"); a.addButton(withTitle: "放弃")
        return a.runModal() == .alertSecondButtonReturn
    }
    func load(_ target: URL) {
        guard discardAllowed() else { return }
        do { let data = try Data(contentsOf: target)
            guard let content = String(data: data, encoding: .utf8) else { throw ConfigError.message("请选择 UTF-8 文本配置。") }
            original = data; text = content; url = target; selected = blocks.first?.id; refreshFields(); message = "保存后，下次 SSH 连接生效。"
        } catch { message = error.localizedDescription }
    }
    func openFile() { let p = NSOpenPanel(); p.showsHiddenFiles = true; p.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh"); if p.runModal() == .OK, let u = p.url { load(u) } }
    func save() {
        guard applyForm() else { return }
        guard let url else { message = "这是草稿，请先导出，再打开导出的文件。"; return }
        do { try ConfigFile.save(text, to: url, original: original); original = Data(text.utf8); message = "已保存，原文件已备份到同目录 .sshnote-backups。" } catch { message = error.localizedDescription }
    }
    func export() {
        guard applyForm() else { return }
        let p = NSSavePanel(); p.nameFieldStringValue = "sshnote-\(Int(Date().timeIntervalSince1970)).config"; p.title = "导出配置备份（可选择 iCloud Drive）"
        if p.runModal() == .OK, let u = p.url {
            do { try Data(text.utf8).write(to: u, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: u.path); message = "已导出配置文本，不包含密钥文件。" } catch { message = error.localizedDescription }
        }
    }
    func restore() {
        let p = NSOpenPanel(); p.title = "选择配置备份，载入后点击保存才会恢复"; p.showsHiddenFiles = true
        if p.runModal() == .OK, let u = p.url, discardAllowed() {
            do { text = try String(contentsOf: u, encoding: .utf8); selected = blocks.first?.id; refreshFields(); message = "备份已载入草稿，检查后点击保存。" } catch { message = error.localizedDescription }
        }
    }
    func add() {
        guard applyForm() else { return }
        var n = 1; while blocks.contains(where: { $0.name == "server-\(n)" }) { n += 1 }
        // Prepend before any Host * or Match section.
        text = "Host server-\(n)\n    HostName example.com\n    User user\n    Port 22\n\n" + text
        selected = 0; refreshFields()
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var editor: Editor?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { editor?.discardAllowed() == false ? .terminateCancel : .terminateNow }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
@main struct SSHNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var editor = Editor()
    var body: some Scene {
        Window("SSHNote", id: "main") {
            ContentView(editor: editor).onAppear {
                delegate.editor = editor
                // Preview appearance is process-local; never change the user's system settings.
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--preview"), arguments.contains("--dark") {
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
                NSApp.activate(ignoringOtherApps: true)
            }
        }.defaultSize(width: 1150, height: 740)
    }
}
