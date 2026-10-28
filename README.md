# SSHNote

轻量、中文、开源的 macOS SSH 配置表单编辑器。Swift + SwiftUI，MIT 许可。

## 当前状态

0.2.0 开发预览。最低 macOS 15；首轮验证环境为 macOS 15.7.5 / Apple Silicon。

- 中文表单：别名、地址、用户名、端口、密钥路径、跳板机。
- 原文编辑，复杂配置保留原文；不会执行配置中的命令，也不连接服务器。
- 表单实时预览，点击保存直接写入当前文件；切换服务器保留有效草稿。
- 保存前检查外部改动、创建原文备份、保留文件权限。
- 导出配置备份，可在系统保存对话框选择 iCloud Drive。
- 恢复备份先载入草稿，检查后保存。只迁移配置文本，不迁移私钥。

## 本机运行

需要 macOS 15+、Swift 6.0+（Xcode 或 Apple Command Line Tools），无第三方依赖。

```sh
swift run CoreChecks
./scripts/build-app.sh
open dist/SSHNote.app
```

启动默认读取 `~/.ssh/config`，不会自动写入。菜单可打开其他配置文件。使用 `dist/SSHNote.app/Contents/MacOS/SSHNote --preview` 可启动独立示例预览。
新机器没有配置文件时，可编辑示例后导出，再打开导出的文件。

## 换机器与 iCloud

另一台 Mac 克隆仓库后按上述步骤构建即可。当前构建脚本生成当前机器架构的应用；尚未提供经公证的通用下载包。
导出到 iCloud Drive 后，在另一台机器下载完成再恢复。iCloud 同步由系统负责，本应用不确认上传完成。
恢复不会自动修正用户名或密钥路径，也不会收集 Include 引用文件。请按新机器环境调整。
配置可能含内网地址或自定义敏感指令，分享前请自行检查。

## 签名与发布

本地脚本使用 ad-hoc 签名，不需要购买证书；它不等同于 Developer ID 签名或 Apple 公证。
公开二进制正式发布计划使用 Developer ID Application + 公证，需开发者账户和相应证书。
目前没有申请、导出或上传任何证书，也未关闭 Gatekeeper。
详见 [发布与签名](ai-docs/decisions/001-scope-and-release.md)。

## 当前边界

不提供终端、SFTP、云账号、自动双向同步。Include 文件需分别打开；Match/通配符等复杂规则使用原文编辑。
表单不对整份 SSH 配置进行语义验证；不会执行 `ssh -G`，避免触发 Match exec 等用户命令。
填写后点击“保存修改”；无效字段会阻止保存或切换，避免丢失输入。
备份位于原文件同目录 `.sshnote-backups/`，保留完整原文，可通过“恢复备份”选择。
