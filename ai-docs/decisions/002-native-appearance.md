# 002：原生系统外观与 SDK 兼容

日期：2026-10-28

## 原因

0.2.0 使用自绘侧栏、分段按钮、保存按钮与不透明背景，并强制浅色外观。使用 macOS 15.5 SDK 构建的应用即使在新版 macOS 运行，也不会自动获得 Liquid Glass。这与原生 macOS 编辑器的定位不符。

## 决定

- 保持 macOS 15 最低运行要求，改用 NavigationSplitView、sidebar List、ToolbarItem、原生 Picker 和 TextField。
- 不给侧栏或工具栏覆盖自定义背景，也不固定系统按钮的尺寸；让系统负责材质、聚焦反馈与辅助功能。
- 使用系统的明暗外观。浅色正文保留米白，品牌强调色为深蓝，深色模式使用薄荷绿强调与系统底色。
- Liquid Glass 由新版 SDK 的标准组件提供，不在配置表单和代码正文上叠加自制玻璃效果，也不把普通模糊材质称为 Liquid Glass。
- 新系统分发包必须由 Xcode 26+ / macOS SDK 26+ 构建。CI 增加 macOS 26 构建与 SDK 门槛，同时保留 macOS 15 检查。仅有编译通过不能宣称完成视觉验收。

## 影响与回滚

保存移到窗口工具栏，侧栏支持系统折叠和调整宽度。配置格式、保存与备份逻辑不变。旧系统显示兼容原生外观；辅助功能“降低透明度”可能使材质不透明，这是系统预期行为。

本地旧 SDK 构建仍可使用，但不用于证明新版系统的 Liquid Glass 效果。回滚可重新构建上一个版本，或替换为旧版应用，无需迁移配置。

## 参考

- [Apple：Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Apple：Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [GitHub：Runner images](https://github.com/actions/runner-images)
