import SwiftUI
import AppKit
import SSHNoteCore

private enum Palette {
    static let ink = Color(red: 0.075, green: 0.13, blue: 0.25)
    static let paper = Color(red: 0.98, green: 0.973, blue: 0.95)
    static let sidebar = Color(red: 0.925, green: 0.94, blue: 0.96)
    static let muted = Color(red: 0.43, green: 0.50, blue: 0.62)
    static let line = Color(red: 0.82, green: 0.85, blue: 0.90)
    static let mint = Color(red: 0.28, green: 0.81, blue: 0.66)
}

struct ContentView: View {
    @ObservedObject var editor: Editor
    @State private var raw = false
    @State private var search = ""
    @FocusState private var focusedField: String?
    private var block: Config.Block? { editor.blocks.first { $0.id == editor.selected } }
    private var filtered: [Config.Block] { editor.blocks.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.values["HostName", default: ""].localizedCaseInsensitiveContains(search) } }
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 226)
            Rectangle().fill(Palette.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                header
                if raw {
                    TextEditor(text: Binding(get: { editor.text }, set: { editor.text = $0; editor.refreshFields() }))
                        .font(.system(size: 13, design: .monospaced)).scrollContentBackground(.hidden)
                        .padding(18).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 28).padding(.bottom, 20)
                } else if let block {
                    GeometryReader { geometry in
                        ScrollView {
                            if geometry.size.width >= 760 {
                                HStack(alignment: .top, spacing: 24) {
                                    form(block).frame(maxWidth: .infinity)
                                    Rectangle().fill(Palette.line).frame(width: 1)
                                    preview.frame(width: 268)
                                }.padding(.horizontal, 28).padding(.bottom, 24)
                            } else {
                                VStack(alignment: .leading, spacing: 24) { form(block); preview }.padding(.horizontal, 28).padding(.bottom, 24)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("没有可显示的服务器", systemImage: "server.rack", description: Text("新增配置，或切换到原文查看当前文件。"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                footer
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper)
        }.foregroundStyle(Palette.ink).tint(Palette.ink).preferredColorScheme(.light)
            .frame(minWidth: 1080, minHeight: 700)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                if let u = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: u) {
                    Image(nsImage: icon).resizable().frame(width: 42, height: 42)
                }
                Text("SSHNote").font(.system(size: 23, weight: .semibold))
            }.padding(.top, 14)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField("搜索服务器", text: $search).textFieldStyle(.plain).font(.system(size: 12))
            }.padding(10).background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
            HStack(spacing: 8) { Text("服务器"); Text("\(editor.blocks.count)").foregroundStyle(Palette.muted) }.font(.system(size: 12, weight: .semibold))
            ScrollView {
                VStack(spacing: 7) {
                    ForEach(filtered) { item in
                        Button { if raw { editor.selected = item.id; editor.refreshFields() } else { editor.select(item.id) } } label: {
                            HStack(spacing: 11) {
                                Image(systemName: "server.rack").font(.system(size: 19))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                    Text(item.values["HostName", default: "配置规则"]).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }.padding(.horizontal, 13).padding(.vertical, 13).frame(maxWidth: .infinity, alignment: .leading)
                                .background(editor.selected == item.id ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .leading) { if editor.selected == item.id { RoundedRectangle(cornerRadius: 2).fill(Palette.mint).frame(width: 4).padding(.vertical, 8) } }
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    if filtered.isEmpty { Text(search.isEmpty ? "暂无配置" : "没有匹配的服务器").font(.system(size: 12)).foregroundStyle(Palette.muted).padding(.vertical, 20) }
                }
            }.padding(.horizontal, -6)
            Button { editor.add(); raw = false } label: { Label("新增配置", systemImage: "plus").font(.system(size: 13, weight: .medium)).padding(.vertical, 7) }.buttonStyle(.plain)
            Rectangle().fill(Palette.line).frame(height: 1)
            Label(editor.displayPath, systemImage: "doc").font(.system(size: 11)).lineLimit(2).help(editor.url?.path ?? "未打开文件")
        }.padding(.horizontal, 20).padding(.bottom, 22).background(Palette.sidebar)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(block?.name ?? "SSH 配置").font(.system(size: 27, weight: .semibold)).lineLimit(1)
                    Text(block.map { [$0.values["HostName"], $0.values["User"]].compactMap { $0 }.joined(separator: " · ") } ?? "管理本机 SSH 连接配置")
                        .font(.system(size: 13)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer()
                Menu {
                    Button("打开其他配置…", action: editor.openFile)
                    Button("重新读取当前文件") { if let url = editor.url { editor.load(url) } }
                    Divider()
                    Button("导出备份…", action: editor.export)
                    Button("恢复备份…", action: editor.restore)
                } label: { Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold)).frame(width: 30, height: 28) }.menuStyle(.borderlessButton).fixedSize().help("文件与备份")
            }
            HStack(spacing: 3) {
                modeButton("表单", value: false)
                modeButton("原文", value: true)
            }.padding(3).background(Palette.sidebar, in: RoundedRectangle(cornerRadius: 8)).fixedSize()
        }.padding(28)
    }
    private func modeButton(_ title: String, value: Bool) -> some View {
        Button {
            if value { if editor.applyForm() { raw = true } }
            else { editor.refreshFields(); raw = false }
        } label: { Text(title).font(.system(size: 12, weight: .medium)).frame(width: 82, height: 29).background(raw == value ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 6)) }
            .buttonStyle(.plain).accessibilityAddTraits(raw == value ? .isSelected : [])
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
            Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 6)
            Text("认证与跳转").font(.system(size: 15, weight: .semibold))
            field("SSH 密钥", key: "IdentityFile", placeholder: "使用默认密钥", browse: true)
            field("跳板机（可选）", key: "ProxyJump", placeholder: "未设置")
            Text(block.editable ? "留空时使用 SSH 默认配置。" : "此配置含复杂语法，请切换到原文编辑。")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
    }
    private var preview: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("配置预览").font(.system(size: 15, weight: .semibold))
            ScrollView(.vertical) {
                Text(editor.previewText).font(.system(size: 12, design: .monospaced)).lineSpacing(6).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading).padding(16)
            }.frame(minHeight: 260, idealHeight: 310, maxHeight: 350)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
            Button { editor.copyCommand() } label: { Label("复制 SSH 命令", systemImage: "doc.on.doc").font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 11) }
                .buttonStyle(.plain).background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
                .disabled(!editor.canCopyCommand)
        }
    }
    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.line).frame(height: 1)
            HStack(spacing: 12) {
                Image(systemName: editor.dirty ? "pencil.circle.fill" : "checkmark.circle.fill").font(.system(size: 25))
                VStack(alignment: .leading, spacing: 4) {
                    Text(editor.dirty ? "有未保存的修改" : (editor.url == nil ? "未打开配置" : "已读取本机配置")).font(.system(size: 12, weight: .medium))
                    Text(editor.message).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(2).help(editor.message)
                }
                Spacer(minLength: 12)
                Button(action: editor.save) {
                    HStack(spacing: 16) { Text("保存修改"); Text("⌘ S").opacity(0.65) }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 20).padding(.vertical, 12)
                        .foregroundStyle(.white).background(Palette.ink.opacity(editor.dirty ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).keyboardShortcut("s").disabled(editor.url == nil || !editor.dirty)
            }.padding(.vertical, 17)
        }.padding(.horizontal, 28)
    }
    private func field(_ title: String, key: String, placeholder: String, browse: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .medium))
            HStack(spacing: 0) {
                TextField(placeholder, text: Binding(get: { editor.fields[key, default: ""] }, set: { editor.fields[key] = $0 }))
                    .textFieldStyle(.plain).font(.system(size: 13)).focused($focusedField, equals: key).accessibilityLabel(title)
                    .padding(.horizontal, 11).padding(.vertical, 11)
                if browse { Button(action: editor.chooseKey) { Image(systemName: "folder").foregroundStyle(Palette.muted).padding(.horizontal, 12) }.buttonStyle(.plain).help("选择密钥文件，仅记录路径") }
            }.background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(focusedField == key ? Palette.mint : Palette.line, lineWidth: focusedField == key ? 1.5 : 1))
                .disabled(block?.editable != true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
