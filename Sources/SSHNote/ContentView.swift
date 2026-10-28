import SwiftUI
import AppKit
import SSHNoteCore

private enum Palette {
    static let line = Color(nsColor: .separatorColor)
    static let mint = Color(red: 0.28, green: 0.81, blue: 0.66)
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.28, green: 0.81, blue: 0.66, alpha: 1)
            : NSColor(red: 0.075, green: 0.13, blue: 0.25, alpha: 1)
    })
    static let paper = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .windowBackgroundColor
            : NSColor(red: 0.98, green: 0.973, blue: 0.95, alpha: 1)
    })
}

struct ContentView: View {
    @ObservedObject var editor: Editor
    @State private var raw = false
    @State private var search = ""
    private var block: Config.Block? { editor.blocks.first { $0.id == editor.selected } }
    private var filtered: [Config.Block] {
        editor.blocks.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
            || $0.values["HostName", default: ""].localizedCaseInsensitiveContains(search) }
    }
    private var selection: Binding<Int?> {
        Binding(get: { editor.selected }, set: { id in
            guard let id else { return }
            if raw { editor.selected = id; editor.refreshFields() }
            else { editor.select(id) }
        })
    }
    private var editingMode: Binding<Bool> {
        Binding(get: { raw }, set: { value in
            if value { if editor.applyForm() { raw = true } }
            else { editor.refreshFields(); raw = false }
        })
    }
    var body: some View {
        // Let the system own sidebar and toolbar materials. Opaque backgrounds here
        // prevent newer SDKs from adopting Liquid Glass automatically.
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                header
                if raw {
                    TextEditor(text: Binding(get: { editor.text }, set: { editor.text = $0; editor.refreshFields() }))
                        .font(.system(size: 13, design: .monospaced))
                        .padding(12).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 28).padding(.bottom, 20)
                        .accessibilityLabel("SSH 配置原文")
                } else if let block {
                    GeometryReader { geometry in
                        ScrollView {
                            if geometry.size.width >= 760 {
                                HStack(alignment: .top, spacing: 24) {
                                    form(block).frame(maxWidth: .infinity)
                                    Divider()
                                    preview.frame(width: 268)
                                }.padding(.horizontal, 28).padding(.bottom, 24)
                            } else {
                                VStack(alignment: .leading, spacing: 24) { form(block); preview }
                                    .padding(.horizontal, 28).padding(.bottom, 24)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("没有可显示的服务器", systemImage: "server.rack",
                        description: Text("新增配置，或切换到原文查看当前文件。"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                footer
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper)
        }
        .navigationTitle("SSHNote")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("编辑方式", selection: editingMode) {
                    Text("表单").tag(false)
                    Text("原文").tag(true)
                }.pickerStyle(.segmented).frame(width: 150)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: editor.save) { Label("保存修改", systemImage: "square.and.arrow.down") }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.borderedProminent).tint(Palette.accent)
                    .keyboardShortcut("s").disabled(editor.url == nil || !editor.dirty)
                    .help("保存修改（⌘S）")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("打开其他配置…", action: editor.openFile).keyboardShortcut("o")
                    Button("重新读取当前文件") { if let url = editor.url { editor.load(url) } }.disabled(editor.url == nil)
                    Divider()
                    Button("导出备份…", action: editor.export)
                    Button("恢复备份…", action: editor.restore)
                } label: { Label("文件与备份", systemImage: "ellipsis") }
                .help("文件与备份")
            }
        }
        .tint(Palette.accent).frame(minWidth: 960, minHeight: 640)
    }
    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: selection) {
                Section("服务器 · \(editor.blocks.count)") {
                    ForEach(filtered) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "server.rack").font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                Text(item.values["HostName", default: "配置规则"])
                                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if editor.selected == item.id {
                                Circle().fill(Palette.mint).frame(width: 6, height: 6).accessibilityHidden(true)
                            }
                        }.padding(.vertical, 6).tag(item.id)
                    }
                }
                if filtered.isEmpty {
                    Text(search.isEmpty ? "暂无配置" : "没有匹配的服务器").foregroundStyle(.secondary)
                }
            }.listStyle(.sidebar).searchable(text: $search, placement: .sidebar, prompt: "搜索服务器")
            VStack(alignment: .leading, spacing: 14) {
                Button { editor.add(); raw = false } label: { Label("新增配置", systemImage: "plus") }
                    .controlSize(.large).frame(maxWidth: .infinity, alignment: .leading)
                Label(editor.displayPath, systemImage: "doc").font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(2).help(editor.url?.path ?? "未打开文件")
            }.padding(18)
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(block?.name ?? "SSH 配置").font(.system(size: 27, weight: .semibold)).lineLimit(1)
            Text(block.map { [$0.values["HostName"], $0.values["User"]].compactMap { $0 }.joined(separator: " · ") }
                ?? "管理本机 SSH 连接配置")
                .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
        }.padding(28)
    }
    private func form(_ block: Config.Block) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("连接信息").font(.system(size: 15, weight: .semibold))
            HStack(alignment: .top, spacing: 16) {
                field("服务器别名", key: "Host", placeholder: "例如 personal-vps")
                field("用户名", key: "User", placeholder: "系统默认用户")
            }
            HStack(alignment: .top, spacing: 16) {
                field("服务器地址", key: "HostName", placeholder: "域名或 IP 地址")
                field("端口", key: "Port", placeholder: "22").frame(width: 88)
            }
            Divider().padding(.vertical, 6)
            Text("认证与跳转").font(.system(size: 15, weight: .semibold))
            field("SSH 密钥", key: "IdentityFile", placeholder: "使用默认密钥", browse: true)
            field("跳板机（可选）", key: "ProxyJump", placeholder: "未设置")
            Text(block.editable ? "留空时使用 SSH 默认配置。" : "此配置含复杂语法，请切换到原文编辑。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
    private var preview: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("配置预览").font(.system(size: 15, weight: .semibold))
            ScrollView(.vertical) {
                Text(editor.previewText).font(.system(size: 12, design: .monospaced)).lineSpacing(6)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading).padding(16)
            }.frame(minHeight: 260, idealHeight: 310, maxHeight: 350)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 0.5))
            Button { editor.copyCommand() } label: { Label("复制 SSH 命令", systemImage: "doc.on.doc") }
                .controlSize(.large).disabled(!editor.canCopyCommand)
        }
    }
    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Image(systemName: editor.dirty ? "pencil.circle" : "checkmark.circle")
                    .font(.system(size: 20)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(editor.dirty ? "有未保存的修改" : (editor.url == nil ? "未打开配置" : "已读取配置"))
                        .font(.system(size: 12, weight: .medium))
                    Text(editor.message).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2).help(editor.message)
                }
                Spacer(minLength: 0)
            }.padding(.vertical, 16)
        }.padding(.horizontal, 28)
    }
    private func field(_ title: String, key: String, placeholder: String, browse: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .medium))
            HStack(spacing: 8) {
                TextField(placeholder, text: Binding(get: { editor.fields[key, default: ""] }, set: { editor.fields[key] = $0 }))
                    .textFieldStyle(.roundedBorder).controlSize(.large).accessibilityLabel(title)
                if browse {
                    Button(action: editor.chooseKey) { Image(systemName: "folder") }
                        .controlSize(.large).help("选择密钥文件，仅记录路径")
                }
            }.disabled(block?.editable != true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
