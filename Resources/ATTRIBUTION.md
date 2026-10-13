# 素材来源与许可范围

项目根目录的 MIT License 授权源代码及本项目编写的文档，不对下述照片、生成图片或第三方素材另行授予权利。这些素材按各自来源说明处理。

## 产品图片来源

`Sources/Mus/Resources/MXAnywhere3S.png` 为用户于 2026-10-13 在对话中提供并指定使用的 MX Anywhere 3S 图片（600 × 600 像素）。文件未作修改，随应用打包以离线显示，替换此前从官网下载的图片。

- 来源：用户附件 `codex-clipboard-3f05d14b-7962-4476-82c8-b7a756d94291.png`
- 图片作者、原始出处及公开再分发授权：尚未确认。

当前界面使用 `Sources/Mus/Resources/MXAnywhere3S-LineArt.png`，于 2026-10-13 根据上述照片通过内置图像生成工具转换为线稿，原始照片保留。线稿为生成的视觉近似，并非逐像素描摹或工程图；此转换不代表原图的再分发授权已确认。

用户指定使用不等于已核实其公开再分发权。发布公开仓库或安装包前，应确认图片授权，或替换为可合法再分发的素材。图片及 Logitech / Logi 商标归相应权利人所有，不属于本项目的原创代码。本应用与 Logitech 无隶属关系；此来源记录不代表图片获授开源许可。

## Mus 当前应用图标

2026-10-14 用户最终选用透明底剪影图标 `Resources/IconVariants/Mus-Mouse-Template.png`。该图由内置 image_gen 工具从彩色小鼠 logo 转成剪影、去除背景生成；彩色版本参考用户提供的小鼠照片。来源说明及提示词见 `Resources/IconVariants/`。菜单栏、侧栏与应用图标共用此轮廓，前两者使用模板渲染适配系统外观。图标构建脚本 `scripts/build-icon.sh` 从此 PNG 生成各尺寸并输出 `Resources/AppIcon.icns`，应用打包脚本自动调用。此生成图不适用 Lucide 的 ISC 许可。

## 先前的 Lucide 应用图标（当前未采用）

先前图标采用 [Lucide Mouse](https://lucide.dev/icons/mouse)，ISC 许可，允许商业使用、修改与分发，需保留版权及许可声明。已保存官方原始 SVG、完整 LICENSE 和固定版本来源于 `Sources/Mus/Resources/ThirdParty/`，随应用资源打包。

- 上游版本：`dab294f313897bacaa968b725b3259fa37c17bd1`
- 版权：Copyright (c) 2026 Lucide Icons and Contributors
- Mus 修改：白色线条，墨绿色圆角背景；原始鼠标轮廓不变。
- 历史生成脚本：`scripts/make-icon.swift`，不再由默认构建调用。
- 这项替换仅涉及应用图标；上文界面产品图片的来源记录仍适用。
