# 首版验证记录

2026-10-28，macOS 15.7.5，Apple Silicon，Swift 6.1.2。

- Release 编译成功；生成 arm64 SSHNote.app，本地 ad-hoc 签名校验通过。
- GUI 启动成功，示例服务器六项中文表单正常显示；修改地址并应用后列表与表单均显示新值。
- 四组核心校验通过：文本无损与局部修改、复杂语法保护、非法输入拒绝、备份/外部冲突/权限/符号链接。
- XCTest 因本机仅有 Command Line Tools 而不可用；改为无外部依赖的 CoreChecks 可执行校验，命令为 swift run CoreChecks。
- 未修改真实 SSH 配置，未连接任何服务器。
- 未验证 iCloud 跨设备同步、Intel 构建、其他 macOS 版本、正式 Developer ID 公证、GitHub Actions 云端执行结果。
- 开发预览仍需真实使用验收；复杂语法通过原文编辑，原文保存不执行 SSH 语义校验。

回滚：恢复配置时先载入自动备份，检查后保存。删除应用不会删除配置；本任务无远程部署或数据库迁移。
