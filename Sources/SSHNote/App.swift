import SwiftUI
import AppKit
import SSHNoteCore

@MainActor final class Editor: ObservableObject {
    @Published var text = ""
    @Published var url: URL?
    @Published var selected: Int?
    @Published var message = "打开 SSH 配置文件，或先使用示例体验表单。"
    var original = Data()
    var dirty: Bool { Data(text.utf8) != original }
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
            original = data; text = content; url = target; selected = blocks.first?.id; message = "已打开 \(target.lastPathComponent)"
        } catch { message = error.localizedDescription }
    }
    func openFile() { let p = NSOpenPanel(); p.showsHiddenFiles = true; p.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh"); if p.runModal() == .OK, let u = p.url { load(u) } }
    func save() {
        guard let url else { message = "这是草稿，请先导出，再打开导出的文件。"; return }
        do { try ConfigFile.save(text, to: url, original: original); original = Data(text.utf8); message = "已保存，原文件已备份到同目录 .sshnote-backups。" } catch { message = error.localizedDescription }
    }
    func export() {
        let p = NSSavePanel(); p.nameFieldStringValue = "sshnote-\(Int(Date().timeIntervalSince1970)).config"; p.title = "导出配置备份（可选择 iCloud Drive）"
        if p.runModal() == .OK, let u = p.url {
            do { try Data(text.utf8).write(to: u, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: u.path); message = "已导出配置文本，不包含密钥文件。" } catch { message = error.localizedDescription }
        }
    }
    func restore() {
        let p = NSOpenPanel(); p.title = "选择配置备份，载入后点击保存才会恢复"; p.showsHiddenFiles = true
        if p.runModal() == .OK, let u = p.url, discardAllowed() {
            do { text = try String(contentsOf: u, encoding: .utf8); selected = blocks.first?.id; message = "备份已载入草稿，检查后点击保存。" } catch { message = error.localizedDescription }
        }
    }
    func add() {
        var n = 1; while blocks.contains(where: { $0.name == "server-\(n)" }) { n += 1 }
        // Prepend before any Host * or Match section.
        text = "Host server-\(n)\n    HostName example.com\n    User user\n    Port 22\n\n" + text
        selected = 0
    }
}

struct HostForm: View {
    @ObservedObject var editor: Editor
    let block: Config.Block
    @State private var fields: [String: String]
    init(editor: Editor, block: Config.Block) { self.editor = editor; self.block = block; _fields = State(initialValue: block.values) }
    let labels = ["Host": "服务器别名", "HostName": "服务器地址", "User": "用户名", "Port": "端口", "IdentityFile": "密钥文件路径", "ProxyJump": "跳板机别名"]
    var body: some View {
        Form {
            Section("连接信息") {
                ForEach(Config.fields, id: \.self) { key in
                    TextField(labels[key] ?? key, text: Binding(get: { fields[key, default: ""] }, set: { fields[key] = $0 })).disabled(!block.editable)
                }
            }
            if !block.editable { Text("此配置包含通配符、重复字段或复杂语法，请使用原文编辑。").foregroundStyle(.orange) }
            Button("应用表单到草稿") {
                do { var config = Config(editor.text); try config.update(block, values: fields); editor.text = config.text; editor.message = "表单已应用到草稿，点击保存写入文件。" } catch { editor.message = error.localizedDescription }
            }.disabled(!block.editable)
            Text("密钥路径只记录位置，不读取或上传私钥。空白字段表示不显式设置。").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
}

struct ContentView: View {
    @ObservedObject var editor: Editor
    @State private var raw = false
    var body: some View {
        NavigationSplitView {
            List(selection: $editor.selected) {
                ForEach(editor.blocks) { block in
                    VStack(alignment: .leading) { Text(block.name); Text(block.values["HostName", default: "配置规则"]).font(.caption).foregroundStyle(.secondary) }.tag(block.id)
                }
            }.navigationTitle("SSHNote").frame(minWidth: 180)
            Button("新增服务器", action: editor.add).padding()
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                HStack { Text(editor.url?.path ?? "未打开文件").font(.caption).textSelection(.enabled); Spacer(); if editor.dirty { Text("未保存").foregroundStyle(.orange) }; Toggle("原文编辑", isOn: $raw).toggleStyle(.switch) }.padding()
                Divider()
                if raw { TextEditor(text: $editor.text).font(.system(.body, design: .monospaced)).padding() }
                else if let block = editor.blocks.first(where: { $0.id == editor.selected }) { HostForm(editor: editor, block: block).id(editor.text + String(block.id)) }
                else { ContentUnavailableView("管理你的 SSH 配置", systemImage: "server.rack", description: Text("打开配置文件，选择服务器后填写表单。")) }
                Divider(); Text(editor.message).font(.caption).foregroundStyle(.secondary).padding().frame(maxWidth: .infinity, alignment: .leading)
            }
        }.toolbar {
            Button("打开", action: editor.openFile)
            Button("保存", action: editor.save).keyboardShortcut("s").disabled(editor.url == nil || !editor.dirty)
            Button("导出备份", action: editor.export)
            Button("恢复备份", action: editor.restore)
            Button("示例") { if editor.discardAllowed() { editor.url = nil; editor.original = Data(); editor.text = "# SSHNote 示例\nHost demo\n    HostName example.com\n    User user\n    Port 22\n"; editor.selected = 1 } }
        }.frame(minWidth: 820, minHeight: 560)
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
    var body: some Scene { Window("SSHNote", id: "main") { ContentView(editor: editor).onAppear { delegate.editor = editor; NSApp.activate(ignoringOtherApps: true) } } }
}
