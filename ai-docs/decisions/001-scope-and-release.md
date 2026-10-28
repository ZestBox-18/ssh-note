# 001：首版范围与发布

日期：2026-10-28

采用 Swift + SwiftUI、macOS 15+，提供中文表单和原文编辑。使用 Swift Package Manager，兼容只有 Apple Command Line Tools 的开发环境。无第三方依赖。

Git 使用用户本地身份，默认 main，MIT 开源。应用与仓库名分别为 SSHNote / ssh-note。

配置文件是事实来源。仅改动表单中变更的字段，保留其他文本。复杂语法保留原文；不排序配置，不执行 SSH 命令。

iCloud 使用用户选择的导出目录，由系统同步。比 CloudKit 简单，无服务端；代价是需要手动恢复、另行迁移密钥和检查路径。

本地采用 ad-hoc 签名。正式分发需 Developer ID Application 签名和公证，不能将本地签名描述为受信任的公开发行版。证书与私钥不得提交；后续发布凭据使用受保护的 CI Secrets。

官方参考：
- https://developer.apple.com/developer-id/
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://man.openbsd.org/ssh_config

回滚：保存前自动备份原文；通过恢复备份载入、检查后保存。卸载应用不删除 SSH 配置或备份。无数据库迁移或服务器部署。
