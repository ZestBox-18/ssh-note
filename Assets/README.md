# SSHNote 应用图标

用户选定方案 01「终端便笺」：深蓝底、米白便笺、薄荷绿折角、终端提示符。

AppIcon.png 为透明底源图，通过内置图像生成工具制作。脚本 scripts/build-icon.sh 使用 macOS sips 生成标准尺寸，再由 iconutil 打包 ICNS；build-app.sh 将其放入应用 Resources 并声明 CFBundleIconFile。

最终编辑提示词：保留选定的深蓝圆角方块、米白折角便笺、深蓝 >_ 和薄荷绿折角；去掉编号和展示背景，外部透明，正视、居中，不增加文字或符号。
